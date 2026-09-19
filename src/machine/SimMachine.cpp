#include "SimMachine.h"

#include <cmath>

SimMachine::SimMachine(QObject *parent)
    : IMachine(parent)
{
    m_axes = { SimAxis { axisX(), SimParameters::X },
               SimAxis { axisB(), SimParameters::B },
               SimAxis { axisA(), SimParameters::A } };

    // Parametreleri ve açılış konumlarını eksenlere yaz. Açılış konumu, makine
    // kapatılmadan önce eksenin kaldığı yer gibi düşünülebilir; referans
    // aranana kadar bu değere güvenilmez.
    for (SimAxis &sim : m_axes) {
        sim.axis->setLimits(sim.params.minPosition, sim.params.maxPosition);
        sim.axis->setHomePosition(sim.params.homePosition);
        sim.axis->setJogSpeeds(sim.params.jogSlow, sim.params.jogFast);
        sim.axis->setPosition(sim.params.startPosition);
    }

    // Referans sırası: önce büküm kolu (B) geri çekilir ki boruya çarpmasın,
    // sonra rotasyon (A), en son ilerletme arabası (X).
    m_homingOrder = { &m_axes[1], &m_axes[2], &m_axes[0] };

    connect(&m_timer, &QTimer::timeout, this, &SimMachine::tick);
    m_timer.start(SimParameters::TickIntervalMs);
    m_clock.start();
}

// ---------------------------------------------------------------------------
// Komutlar
// ---------------------------------------------------------------------------

void SimMachine::startHoming()
{
    if (state() == Homing)
        return;

    haltAllMotion();

    // Referans baştan aranır: tüm eksenlerin eski referansı geçersiz sayılır.
    for (SimAxis &sim : m_axes) {
        sim.axis->setHomed(false);
        sim.axis->setHoming(false);
        updateLimitState(sim);
    }

    m_homingIndex = 0;
    m_latchTime = 0.0;
    m_homingOrder[0]->axis->setHoming(true);
    setState(Homing);
}

void SimMachine::stop()
{
    // STOP her hareketi keser.
    haltAllMotion();

    if (state() != Homing)
        return;

    // Referans arama yarıda kesildi: makine referanssız sayılır.
    Axis *axis = m_homingOrder[m_homingIndex]->axis;
    axis->setHoming(false);
    axis->setMoving(false);
    m_homingIndex = -1;
    m_latchTime = 0.0;
    setState(NotHomed);
}

void SimMachine::startJog(Axis *axis, int direction, bool fast)
{
    SimAxis *sim = simAxis(axis);
    if (!sim || direction == 0 || state() == Homing)
        return;

    // Eksen o yöndeki limite dayanmışsa o yöne gidemez.
    const int dir = direction > 0 ? 1 : -1;
    if ((dir > 0 && axis->atMaxLimit()) || (dir < 0 && axis->atMinLimit()))
        return;

    // Yeni komut eskisinin yerini alır: süren bir "konuma git" varsa iptal olur.
    sim->positioning = false;
    sim->jogDirection = dir;
    // Referanssız eksenin konumu bilinmez; güvenlik için yalnızca yavaş hız.
    sim->jogFast = fast && axis->isHomed();
    sim->jogDeadline.setRemainingTime(SimParameters::JogWatchdogMs);
}

void SimMachine::keepJogAlive(Axis *axis)
{
    // Yalnızca süren bir jog uzatılır. Jog durduysa (STOP, limit, bekçi),
    // yeniden başlamak için butonun bırakılıp tekrar basılması gerekir.
    SimAxis *sim = simAxis(axis);
    if (sim && sim->jogDirection != 0)
        sim->jogDeadline.setRemainingTime(SimParameters::JogWatchdogMs);
}

void SimMachine::stopJog(Axis *axis)
{
    SimAxis *sim = simAxis(axis);
    if (sim && sim->jogDirection != 0)
        haltMotion(*sim);
}

void SimMachine::moveTo(Axis *axis, double target)
{
    SimAxis *sim = simAxis(axis);

    // Konuma gitmek için 0'ın nerede olduğunu bilmek gerekir: makine HAZIR olmalı.
    if (!sim || state() != Ready || !axis->isHomed())
        return;

    // Ekran aralık dışı değeri zaten kabul etmez; makine yine de kendisi kontrol
    // eder. Gerçek PLC de ekrandan gelen değere körü körüne güvenmez.
    if (!std::isfinite(target) || target < sim->params.minPosition || target > sim->params.maxPosition)
        return;

    // Yeni komut eskisinin yerini alır: süren bir jog varsa iptal olur.
    sim->jogDirection = 0;
    sim->moveTarget = target;
    sim->positioning = true;
}

// ---------------------------------------------------------------------------
// Döngü
// ---------------------------------------------------------------------------

void SimMachine::tick()
{
    // Önceki turdan bu yana geçen gerçek süre (saniye). Program bir an
    // takılırsa eksen ileri zıplamasın diye en fazla 0.1 sn alıyoruz.
    const double dt = qMin(m_clock.restart() / 1000.0, 0.1);

    if (state() == Homing)
        updateHoming(dt);
    else
        updateManualMotion(dt);
}

void SimMachine::updateHoming(double dt)
{
    SimAxis &sim = *m_homingOrder[m_homingIndex];
    Axis *axis = sim.axis;
    const double position = axis->position();
    const double home = sim.params.homePosition;
    const double distance = std::abs(home - position);

    // 1) Referans noktasına doğru ilerle: uzaktaysa hızlı, yakınsa yavaş.
    if (distance > 0.0) {
        const double speed = distance > sim.params.homingSlowZone ? sim.params.homingFast
                                                                  : sim.params.homingSlow;
        const double step = speed * dt;
        // Son adımda tam hedefe otur: ondalıklı hesap küçük bir kalıntı bırakmasın.
        if (step >= distance)
            axis->setPosition(home);
        else
            axis->setPosition(position < home ? position + step : position - step);
        axis->setMoving(true);
        return;
    }

    // 2) Referans noktasına varıldı: kısa bir süre bekle.
    axis->setMoving(false);
    m_latchTime += dt;
    if (m_latchTime < SimParameters::LatchSeconds)
        return;

    // 3) Referans bulundu: eksene referans değeri yazılır, eksen referanslı olur.
    m_latchTime = 0.0;
    axis->setPosition(home);
    axis->setHoming(false);
    axis->setHomed(true);
    updateLimitState(sim);

    // Sıradaki eksene geç; eksen kalmadıysa makine hazır.
    ++m_homingIndex;
    if (m_homingIndex < int(m_homingOrder.size())) {
        m_homingOrder[m_homingIndex]->axis->setHoming(true);
    } else {
        m_homingIndex = -1;
        setState(Ready);
    }
}

void SimMachine::updateManualMotion(double dt)
{
    for (SimAxis &sim : m_axes) {
        Axis *axis = sim.axis;

        // Konuma git: hedefe sabit hızla ilerle, varınca tam hedefte dur.
        if (sim.positioning) {
            const double remaining = sim.moveTarget - axis->position();
            const double step = sim.params.moveSpeed * dt;
            if (std::abs(remaining) <= step) {
                axis->setPosition(sim.moveTarget);
                haltMotion(sim);
            } else {
                axis->setPosition(axis->position() + (remaining > 0 ? step : -step));
                axis->setMoving(true);
            }
            updateLimitState(sim);
            continue;
        }

        if (sim.jogDirection == 0)
            continue;

        // Bekçi: ekran belirli bir süre "hâlâ basılı" demediyse dur.
        if (sim.jogDeadline.hasExpired()) {
            haltMotion(sim);
            continue;
        }

        const double speed = sim.jogFast ? sim.params.jogFast : sim.params.jogSlow;
        double position = axis->position() + sim.jogDirection * speed * dt;

        // Yazılım limitleri yalnızca referanslı eksende geçerli.
        bool reachedLimit = false;
        if (axis->isHomed()) {
            if (position >= sim.params.maxPosition) {
                position = sim.params.maxPosition;
                reachedLimit = true;
            } else if (position <= sim.params.minPosition) {
                position = sim.params.minPosition;
                reachedLimit = true;
            }
        }

        axis->setPosition(position);
        axis->setMoving(true);
        updateLimitState(sim);

        if (reachedLimit)
            haltMotion(sim);
    }
}

// ---------------------------------------------------------------------------
// Yardımcılar
// ---------------------------------------------------------------------------

SimMachine::SimAxis *SimMachine::simAxis(Axis *axis)
{
    for (SimAxis &sim : m_axes) {
        if (sim.axis == axis)
            return &sim;
    }
    return nullptr;
}

void SimMachine::haltMotion(SimAxis &sim)
{
    sim.jogDirection = 0;
    sim.positioning = false;
    sim.axis->setMoving(false);
}

void SimMachine::haltAllMotion()
{
    for (SimAxis &sim : m_axes)
        haltMotion(sim);
}

void SimMachine::updateLimitState(SimAxis &sim)
{
    // Limit bilgisi yalnızca referanslı eksen için anlamlıdır.
    const bool homed = sim.axis->isHomed();
    const double position = sim.axis->position();
    sim.axis->setLimitState(homed && position <= sim.params.minPosition,
                            homed && position >= sim.params.maxPosition);
}
