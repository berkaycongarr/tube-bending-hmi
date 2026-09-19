#include "SimMachine.h"

#include <cmath>

SimMachine::SimMachine(QObject *parent)
    : IMachine(parent)
{
    m_axes = { SimAxis { axisX(), SimParameters::X },
               SimAxis { axisB(), SimParameters::B },
               SimAxis { axisA(), SimParameters::A } };

    // Limitleri ve açılış konumlarını eksenlere yaz. Açılış konumu, makine
    // kapatılmadan önce eksenin kaldığı yer gibi düşünülebilir; referans
    // aranana kadar bu değere güvenilmez.
    for (SimAxis &sim : m_axes) {
        sim.axis->setLimits(sim.params.minPosition, sim.params.maxPosition);
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

    haltAllJogs();

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
    haltAllJogs();

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
    if (SimAxis *sim = simAxis(axis))
        haltJog(*sim);
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
        updateJogs(dt);
}

void SimMachine::updateHoming(double dt)
{
    SimAxis &sim = *m_homingOrder[m_homingIndex];
    Axis *axis = sim.axis;
    const double position = axis->position();
    const double distance = std::abs(position);

    // 1) Referans noktasına (0) doğru ilerle: uzaktaysa hızlı, yakınsa yavaş.
    if (distance > 0.0) {
        const double speed = distance > sim.params.homingSlowZone ? sim.params.homingFast
                                                                  : sim.params.homingSlow;
        const double step = qMin(speed * dt, distance);
        axis->setPosition(position > 0 ? position - step : position + step);
        axis->setMoving(true);
        return;
    }

    // 2) Referans noktasına varıldı: kısa bir süre bekle.
    axis->setMoving(false);
    m_latchTime += dt;
    if (m_latchTime < SimParameters::LatchSeconds)
        return;

    // 3) Referans bulundu: eksen referanslı olur.
    m_latchTime = 0.0;
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

void SimMachine::updateJogs(double dt)
{
    for (SimAxis &sim : m_axes) {
        if (sim.jogDirection == 0)
            continue;

        // Bekçi: ekran belirli bir süre "hâlâ basılı" demediyse dur.
        if (sim.jogDeadline.hasExpired()) {
            haltJog(sim);
            continue;
        }

        const double speed = sim.jogFast ? sim.params.jogFast : sim.params.jogSlow;
        double position = sim.axis->position() + sim.jogDirection * speed * dt;

        // Yazılım limitleri yalnızca referanslı eksende geçerli.
        bool reachedLimit = false;
        if (sim.axis->isHomed()) {
            if (position >= sim.params.maxPosition) {
                position = sim.params.maxPosition;
                reachedLimit = true;
            } else if (position <= sim.params.minPosition) {
                position = sim.params.minPosition;
                reachedLimit = true;
            }
        }

        sim.axis->setPosition(position);
        sim.axis->setMoving(true);
        updateLimitState(sim);

        if (reachedLimit)
            haltJog(sim);
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

void SimMachine::haltJog(SimAxis &sim)
{
    sim.jogDirection = 0;
    sim.axis->setMoving(false);
}

void SimMachine::haltAllJogs()
{
    for (SimAxis &sim : m_axes)
        haltJog(sim);
}

void SimMachine::updateLimitState(SimAxis &sim)
{
    // Limit bilgisi yalnızca referanslı eksen için anlamlıdır.
    const bool homed = sim.axis->isHomed();
    const double position = sim.axis->position();
    sim.axis->setLimitState(homed && position <= sim.params.minPosition,
                            homed && position >= sim.params.maxPosition);
}
