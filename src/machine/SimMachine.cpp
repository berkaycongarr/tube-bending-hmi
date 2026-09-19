#include "SimMachine.h"

#include <cmath>
#include <utility>

namespace {

// Döngü aralığı: 20 ms, yani saniyede 50 tur.
constexpr int TickIntervalMs = 20;

// Referans noktasına varan eksen bu kadar bekler (sn). Gerçek makinede bu
// sırada referans işareti (şalter, enkoder sıfır sinyali) kesinleştirilir.
constexpr double LatchSeconds = 0.5;

// Referans arama hızları. Eksen önce hızlı gider, referans noktasına
// yaklaşınca yavaşlar (gerçek makinede şaltere hassas yaklaşmak için).
struct HomingProfile
{
    double fastSpeed; // birim/sn (mm/sn ya da derece/sn)
    double slowSpeed; // birim/sn
    double slowZone;  // referansa bu kadar yaklaşınca yavaşla
};

HomingProfile homingProfileFor(const Axis *axis)
{
    if (axis->isRotary())
        return { 90.0, 12.0, 12.0 }; // derece
    return { 400.0, 40.0, 40.0 };    // mm
}

} // namespace

SimMachine::SimMachine(QObject *parent)
    : IMachine(parent)
{
    // Açılışta eksenler, makine kapatılmadan önce kaldıkları yerde duruyor gibi.
    // Referans aranana kadar bu değerlere güvenilmez.
    axisX()->setPosition(1693.35);
    axisB()->setPosition(37.5);
    axisA()->setPosition(90.0);

    // Referans sırası: önce büküm kolu (B) geri çekilir ki boruya çarpmasın,
    // sonra rotasyon (A), en son ilerletme arabası (X).
    m_homingOrder = { axisB(), axisA(), axisX() };

    connect(&m_timer, &QTimer::timeout, this, &SimMachine::tick);
    m_timer.start(TickIntervalMs);
    m_clock.start();
}

void SimMachine::startHoming()
{
    if (state() == Homing)
        return;

    // Referans baştan aranır: tüm eksenlerin eski referansı geçersiz sayılır.
    for (Axis *axis : std::as_const(m_homingOrder)) {
        axis->setHomed(false);
        axis->setHoming(false);
    }

    m_homingIndex = 0;
    m_latchTime = 0.0;
    m_homingOrder.at(m_homingIndex)->setHoming(true);
    setState(Homing);
}

void SimMachine::stop()
{
    if (state() != Homing)
        return;

    // Referans arama yarıda kesildi: makine referanssız sayılır.
    m_homingOrder.at(m_homingIndex)->setHoming(false);
    m_homingIndex = -1;
    m_latchTime = 0.0;
    setState(NotHomed);
}

void SimMachine::tick()
{
    // Önceki turdan bu yana geçen gerçek süre (saniye). Program bir an
    // takılırsa eksen ileri zıplamasın diye en fazla 0.1 sn alıyoruz.
    const double dt = qMin(m_clock.restart() / 1000.0, 0.1);

    if (state() == Homing)
        updateHoming(dt);
}

void SimMachine::updateHoming(double dt)
{
    Axis *axis = m_homingOrder.at(m_homingIndex);
    const double position = axis->position();
    const double distance = std::abs(position);

    // 1) Referans noktasına (0) doğru ilerle: uzaktaysa hızlı, yakınsa yavaş.
    if (distance > 0.0) {
        const HomingProfile profile = homingProfileFor(axis);
        const double speed = distance > profile.slowZone ? profile.fastSpeed
                                                         : profile.slowSpeed;
        const double step = qMin(speed * dt, distance);
        axis->setPosition(position > 0 ? position - step : position + step);
        return;
    }

    // 2) Referans noktasına varıldı: kısa bir süre bekle.
    m_latchTime += dt;
    if (m_latchTime < LatchSeconds)
        return;

    // 3) Referans bulundu: eksen referanslı olur.
    m_latchTime = 0.0;
    axis->setHoming(false);
    axis->setHomed(true);

    // Sıradaki eksene geç; eksen kalmadıysa makine hazır.
    ++m_homingIndex;
    if (m_homingIndex < m_homingOrder.size()) {
        m_homingOrder.at(m_homingIndex)->setHoming(true);
    } else {
        m_homingIndex = -1;
        setState(Ready);
    }
}
