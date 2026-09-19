#include "SimMachine.h"

#include <cmath>

SimMachine::SimMachine(QObject *parent)
    : IMachine(parent)
{
    m_axes = { SimAxis { axisX(), SimParameters::X },
               SimAxis { axisB(), SimParameters::B },
               SimAxis { axisA(), SimParameters::A },
               SimAxis { axisY(), SimParameters::Y } };

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
    // sonra öteleme (Y) ve rotasyon (A), en son ilerletme arabası (X).
    // Y'nin sıradaki yeri varsayım: demoda müşteriye sorulacak.
    m_homingOrder = { &m_axes[1], &m_axes[3], &m_axes[2], &m_axes[0] };

    // Silindirler açılışta bekleme konumunda (açık / geride).
    m_actuators = { SimActuator { clamp(), SimParameters::ClampTravelSeconds },
                    SimActuator { mandrel(), SimParameters::MandrelTravelSeconds },
                    SimActuator { collet(), SimParameters::ColletTravelSeconds } };

    updateInterlocks();

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

    // Kilitli bir eksen varsa (ör. mengene boruyu tutarken X, A, Y) referans aranamaz.
    updateInterlocks();
    for (const SimAxis &sim : m_axes) {
        if (sim.axis->interlock() != Axis::NoInterlock)
            return;
    }

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
    updateInterlocks();
}

void SimMachine::stop()
{
    // STOP her eksen hareketini keser. Pompanın kendi START/STOP'u vardır;
    // bu STOP pompayı ve silindirleri etkilemez.
    haltAllMotion();

    if (state() == Homing) {
        // Referans arama yarıda kesildi: makine referanssız sayılır.
        Axis *axis = m_homingOrder[m_homingIndex]->axis;
        axis->setHoming(false);
        axis->setMoving(false);
        m_homingIndex = -1;
        m_latchTime = 0.0;
        setState(NotHomed);
    }
    updateInterlocks();
}

void SimMachine::startJog(Axis *axis, int direction, bool fast)
{
    SimAxis *sim = simAxis(axis);
    if (!sim || direction == 0 || state() == Homing)
        return;

    // Kilitli eksen (ör. mengene boruyu tutarken X, A ya da Y) hareket edemez.
    updateInterlocks();
    if (axis->interlock() != Axis::NoInterlock)
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

    // Kilitli eksen hareket edemez.
    updateInterlocks();
    if (axis->interlock() != Axis::NoInterlock)
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

void SimMachine::startPump()
{
    // START mühürlenir: buton bırakılsa da pompa çalışmaya devam eder.
    m_pumpCommand = true;
    updatePump(0.0);
}

void SimMachine::stopPump()
{
    // STOP mühürü çözer: pompa durur, basınç düşer.
    m_pumpCommand = false;
    updatePump(0.0);
}

void SimMachine::setActuator(Actuator *actuator, bool on)
{
    // Kilitliyse (basınç yok ya da eksenler hareket ediyor) komut reddedilir.
    updateInterlocks();
    if (!simActuator(actuator) || actuator->interlock() != Actuator::NoInterlock)
        return;

    // Komut makinede kalır (kalıcı buton); silindir yolunu döngü içinde alır.
    actuator->setCommand(on);
    updateInterlocks();
}

// ---------------------------------------------------------------------------
// Döngü
// ---------------------------------------------------------------------------

void SimMachine::tick()
{
    // Önceki turdan bu yana geçen gerçek süre (saniye). Program bir an
    // takılırsa her şey ileri zıplamasın diye en fazla 0.1 sn alıyoruz.
    const double dt = qMin(m_clock.restart() / 1000.0, 0.1);

    // PLC gibi: önce girişleri ve hidroliği güncelle, kilitleri hesapla,
    // sonra eksenleri hareket ettir ve kilitleri yeniden hesapla.
    updatePump(dt);
    updateActuators(dt);
    updateInterlocks();

    if (state() == Homing)
        updateHoming(dt);
    else
        updateManualMotion(dt);

    updateInterlocks();
}

void SimMachine::updatePump(double dt)
{
    // Basınç, pompa çalışınca yükselir, durunca düşer.
    const double nominal = SimParameters::NominalPressure;
    double p = pressure();

    if (m_pumpCommand) {
        p = qMin(nominal, p + nominal / SimParameters::PumpStartSeconds * dt);
        setPumpState(p >= nominal ? PumpRunning : PumpStarting);
    } else {
        p = qMax(0.0, p - nominal / SimParameters::PumpStopSeconds * dt);
        setPumpState(p <= 0.0 ? PumpStopped : PumpStopping);
    }
    setPressure(p);
}

void SimMachine::updateActuators(double dt)
{
    // Silindirler yalnızca basınç tamken hareket eder. Pompa yolda durursa
    // silindir olduğu yerde kalır, basınç gelince yoluna devam eder.
    const bool pressureOk = pumpState() == PumpRunning;

    for (SimActuator &sim : m_actuators) {
        Actuator *actuator = sim.actuator;
        const double target = actuator->command() ? 1.0 : 0.0;

        if (pressureOk && sim.progress != target) {
            const double step = dt / sim.travelSeconds;
            sim.progress = target > sim.progress ? qMin(target, sim.progress + step)
                                                 : qMax(target, sim.progress - step);
        }

        // Sensörler yalnızca uç konumları bilir: iki ucun arasındaysa silindir yoldadır.
        if (sim.progress >= 1.0)
            actuator->setState(Actuator::On);
        else if (sim.progress <= 0.0)
            actuator->setState(Actuator::Off);
        else
            actuator->setState(actuator->command() ? Actuator::TurningOn : Actuator::TurningOff);
    }
}

void SimMachine::updateInterlocks()
{
    const bool pumpOk = pumpState() == PumpRunning;

    // Mengene boruyu tutuyor mu? Kapatma komutu verildiği an ya da tam açılana
    // kadar evet sayılır.
    const bool clampHolding = clamp()->command() || clamp()->state() != Actuator::Off;

    // X, A ya da Y hareket ediyor mu (referans arama dahil)?
    const bool axesBusy = state() == Homing || axisX()->isMoving() || axisA()->isMoving()
                          || axisY()->isMoving();

    // Kural 1: mengene boruyu tutarken X (ilerletme) ve A (rotasyon) hareket edemez;
    // boru kıskaçtayken çekilir ya da burulur. Y (öteleme) de kilitlenir: sıkılı boruyu
    // yana kaydırmak boruyu zorlar (güvenli taraftaki varsayım). B (büküm) serbesttir.
    const Axis::Interlock axisLock = clampHolding ? Axis::ClampClosed : Axis::NoInterlock;
    axisX()->setInterlock(axisLock);
    axisA()->setInterlock(axisLock);
    axisY()->setInterlock(axisLock);

    // Kural 2: basınç yoksa hiçbir silindir kumanda edilemez.
    // Kural 3: X, A ya da Y hareket ederken mengene kumanda edilemez.
    clamp()->setInterlock(!pumpOk ? Actuator::PumpOff
                          : axesBusy ? Actuator::AxesMoving
                                     : Actuator::NoInterlock);
    mandrel()->setInterlock(pumpOk ? Actuator::NoInterlock : Actuator::PumpOff);
    collet()->setInterlock(pumpOk ? Actuator::NoInterlock : Actuator::PumpOff);
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

        // Güvenlik: kilitlenmiş eksen hareket ediyorsa hemen durdur.
        if (axis->interlock() != Axis::NoInterlock && (sim.positioning || sim.jogDirection != 0)) {
            haltMotion(sim);
            continue;
        }

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

SimMachine::SimActuator *SimMachine::simActuator(Actuator *actuator)
{
    for (SimActuator &sim : m_actuators) {
        if (sim.actuator == actuator)
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
