#include "SimMachine.h"

#include <QSettings>
#include <QtMath>

#include <cmath>

namespace {

// Tarifteki komut numaraları. Makine, programın sınıfını (BendProgram) tanımaz:
// ekran adımları sayı olarak gönderir, sözleşme IMachine.h'de yazılıdır.
constexpr int FeedCommand = 0;   // İLERLE (göreli, mm)
constexpr int BendCommand = 1;   // BÜK (mutlak açı, derece)
constexpr int RotateCommand = 2; // ROTASYON (mutlak açı, derece)

// Program ile takılı kalıbın yarıçapı ve boru çapı bu kadar farklıysa "aynı" sayılır
// (ondalıklı sayılar dosyadan okunurken en küçük basamakta sapabilir).
constexpr double ToolingTolerance = 0.005; // mm

// ZAMANLAR: sürelerin anahtarları. Makinenin belleğinde (makine.ini) de bu adlarla durur.
const QString ClampDwellKey = QStringLiteral("mengeneBekleme");
const QString BendDwellKey = QStringLiteral("bukumBekleme");
const QString StepPauseKey = QStringLiteral("adimArasiBekleme");
const QString MoveTimeoutKey = QStringLiteral("eksenZamanAsimi");
const QString ActuatorTimeoutKey = QStringLiteral("silindirZamanAsimi");
const QString TimersGroup = QStringLiteral("Zamanlar"); // makine.ini'deki bölüm

// AYARLAR: boru alma konumu ve her eksen için limitler ve hızlar. Eksen anahtarları
// eksenin harfiyle başlar: "xAltLimit", "bJogHizli", "aKonumlama" gibi.
const QString LoadPositionKey = QStringLiteral("boruAlmaKonumu");
const QString SettingsGroup = QStringLiteral("Ayarlar");
const char *const AxisKeys[4] = { "x", "b", "a", "y" }; // m_axes sırası: X, B, A, Y

QString settingKey(int axis, const char *name)
{
    return QLatin1String(AxisKeys[axis]) + QLatin1String(name);
}

// IO TEST: girişlerin ve çıkışların adresleri. Adresler Siemens biçiminde örnektir (I giriş,
// Q çıkış, "bayt.bit"): gerçek makinenin adresleri elektrik şemasından alınacak.
const QString PressureSwitchInput = QStringLiteral("I0.0");
const QString ClampOpenInput = QStringLiteral("I0.1");
const QString ClampClosedInput = QStringLiteral("I0.2");
const QString MandrelBackInput = QStringLiteral("I0.3");
const QString MandrelForwardInput = QStringLiteral("I0.4");
const QString ColletOpenInput = QStringLiteral("I0.5");
const QString ColletClosedInput = QStringLiteral("I0.6");
const char *const HomeSensorInputs[4] = { "I1.0", "I1.1", "I1.2", "I1.3" }; // m_axes sırası: X, B, A, Y
const QString PumpOutput = QStringLiteral("Q0.0");
const QString ClampOutput = QStringLiteral("Q0.1");
const QString MandrelOutput = QStringLiteral("Q0.2");
const QString ColletOutput = QStringLiteral("Q0.3");

// Eksenin yolu ve en yüksek hızı: ayarlar bunun dışına çıkamaz (SimParameters).
const AxisParameters &physical(int axis)
{
    static const AxisParameters axes[4] = { SimParameters::X, SimParameters::B, SimParameters::A,
                                            SimParameters::Y };
    return axes[axis];
}

} // namespace

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

    defineTimers();
    connect(timers(), &ParameterList::valueChanged, this, [this](const QString &key, double value) {
        remember(TimersGroup, key, value);
    });

    defineSettings();
    applySettings();
    updateSettingRanges();
    connect(settings(), &ParameterList::valueChanged, this, [this](const QString &key, double value) {
        applySettings();
        updateSettingRanges();
        remember(SettingsGroup, key, value);
    });

    defineIo();
    updateInterlocks();
    updateIo();

    connect(&m_timer, &QTimer::timeout, this, &SimMachine::tick);
    m_timer.start(SimParameters::TickIntervalMs);
    m_clock.start();
}

// ---------------------------------------------------------------------------
// Makinenin süreleri ve belleği
// ---------------------------------------------------------------------------

void SimMachine::defineTimers()
{
    // Değerler ve aralıklar varsayım: gerçek makinenin süreleri demoda sorulacak.
    // Süreler döngü sürerken de değiştirilebilir: yeni değer, sıradaki aşamada geçerli olur.
    ParameterList *list = timers();
    list->add({ ClampDwellKey, tr("MENGENE KAPANINCA BEKLEME"),
                tr("Mengene kapandıktan sonra büküme başlamadan önce beklenir: basınç otursun, "
                   "boru kaymasın."),
                QStringLiteral("s"), SimParameters::ClampDwellSeconds, 0.0, 5.0, 2 });
    list->add({ BendDwellKey, tr("BÜKÜMDE BEKLEME"),
                tr("Büküm kolu açıya varınca mengene açılmadan önce beklenir: boru biçimini alır, "
                   "geri esnemesi azalır."),
                QStringLiteral("s"), SimParameters::BendDwellSeconds, 0.0, 5.0, 2 });
    list->add({ StepPauseKey, tr("ADIM ARASI BEKLEME"),
                tr("Otomatik çalışmada bir adım bitince sıradakine geçmeden önce beklenir."),
                QStringLiteral("s"), SimParameters::StepPauseSeconds, 0.0, 5.0, 2 });
    list->add({ MoveTimeoutKey, tr("EKSEN ZAMAN AŞIMI"),
                tr("Bir eksen hareketi bu sürede bitmezse döngü arızayla durur."),
                QStringLiteral("s"), SimParameters::MoveTimeoutSeconds, 5.0, 300.0, 2 });
    list->add({ ActuatorTimeoutKey, tr("SİLİNDİR ZAMAN AŞIMI"),
                tr("Mengene, malafa ya da pens bu sürede yerine gitmezse döngü arızayla durur."),
                QStringLiteral("s"), SimParameters::ActuatorTimeoutSeconds, 1.0, 60.0, 2 });
}

double SimMachine::timer(const QString &key) const
{
    return timers()->value(key);
}

void SimMachine::defineSettings()
{
    ParameterList *list = settings();
    list->add({ LoadPositionKey, tr("BORU ALMA KONUMU X"),
                tr("Her parça buradan başlar: araba bu konumda bekler, boru burada takılır."),
                QStringLiteral("mm"), SimParameters::LoadPositionX, SimParameters::X.minPosition,
                SimParameters::X.maxPosition, 2 });

    const QString names[4] = { tr("X İLERLETME"), tr("B BÜKÜM"), tr("A ROTASYON"), tr("Y ÖTELEME") };
    for (int i = 0; i < 4; ++i) {
        const AxisParameters &p = physical(i);
        const bool rotary = i == 1 || i == 2;
        const QString unit = rotary ? QStringLiteral("°") : QStringLiteral("mm");
        const QString speed = rotary ? QStringLiteral("°/s") : QStringLiteral("mm/s");
        list->add({ settingKey(i, "AltLimit"), names[i] + tr(" · ALT LİMİT"),
                    tr("Eksen referanslıyken bunun altına gidemez."), unit, p.minPosition, p.minPosition,
                    p.maxPosition, 2 });
        list->add({ settingKey(i, "UstLimit"), names[i] + tr(" · ÜST LİMİT"),
                    tr("Eksen referanslıyken bunun üstüne gidemez."), unit, p.maxPosition, p.minPosition,
                    p.maxPosition, 2 });
        list->add({ settingKey(i, "JogYavas"), names[i] + tr(" · JOG YAVAŞ"),
                    tr("Jog butonuna basılı tutunca eksenin hızı."), speed, p.jogSlow, 0.1, p.maxSpeed, 2 });
        list->add({ settingKey(i, "JogHizli"), names[i] + tr(" · JOG HIZLI"),
                    tr("HIZLI seçiliyken jog hızı."), speed, p.jogFast, 0.1, p.maxSpeed, 2 });
        list->add({ settingKey(i, "Konumlama"), names[i] + tr(" · KONUMLAMA HIZI"),
                    tr("Konuma gitme ve üretim döngüsündeki hareket hızı."), speed, p.moveSpeed, 1.0,
                    p.maxSpeed, 2 });
    }
}

void SimMachine::applySettings()
{
    const ParameterList *list = settings();
    for (int i = 0; i < 4; ++i) {
        SimAxis &sim = m_axes[i];
        sim.params.minPosition = list->value(settingKey(i, "AltLimit"));
        sim.params.maxPosition = list->value(settingKey(i, "UstLimit"));
        sim.params.jogSlow = list->value(settingKey(i, "JogYavas"));
        sim.params.jogFast = list->value(settingKey(i, "JogHizli"));
        sim.params.moveSpeed = list->value(settingKey(i, "Konumlama"));
        sim.axis->setLimits(sim.params.minPosition, sim.params.maxPosition);
        sim.axis->setJogSpeeds(sim.params.jogSlow, sim.params.jogFast);
        updateLimitState(sim);
    }
    setLoadPosition(list->value(LoadPositionKey));
}

void SimMachine::updateSettingRanges()
{
    // Birbirine bağlı değerler: alt limit üst limitin altında kalır (aralarında en az
    // MinimumLimitSpan), jog yavaş hızlıyı geçmez. Döngü B ve A'yı 0'a döndürür, arabayı
    // boru alma konumuna götürür: limitler bu noktaları dışarıda bırakamaz.
    ParameterList *list = settings();
    const double load = list->value(LoadPositionKey);
    for (int i = 0; i < 4; ++i) {
        const AxisParameters &p = physical(i);
        const double low = list->value(settingKey(i, "AltLimit"));
        const double high = list->value(settingKey(i, "UstLimit"));
        double lowMax = high - SimParameters::MinimumLimitSpan;
        double highMin = low + SimParameters::MinimumLimitSpan;
        if (i == 0) { // X: boru alma konumu içeride kalmalı
            lowMax = std::min(lowMax, load);
            highMin = std::max(highMin, load);
        } else if (i == 1 || i == 2) { // B ve A: 0 içeride kalmalı
            lowMax = std::min(lowMax, 0.0);
            highMin = std::max(highMin, 0.0);
        }
        list->setRange(settingKey(i, "AltLimit"), p.minPosition, lowMax);
        list->setRange(settingKey(i, "UstLimit"), highMin, p.maxPosition);

        const double slow = list->value(settingKey(i, "JogYavas"));
        const double fast = list->value(settingKey(i, "JogHizli"));
        list->setRange(settingKey(i, "JogYavas"), 0.1, fast);
        list->setRange(settingKey(i, "JogHizli"), slow, p.maxSpeed);
    }
    list->setRange(LoadPositionKey, list->value(settingKey(0, "AltLimit")),
                   list->value(settingKey(0, "UstLimit")));
}

void SimMachine::updateSettingsLock()
{
    // Döngü sürerken (operatörü beklerken de) ya da referans aranırken eksenlerin limitleri
    // ve hızları değişmez: makine o değerlerle çalışıyor.
    if (cycleState() != CycleStopped)
        settings()->setLocked(true, tr("Döngü sürerken makinenin ayarları değiştirilemez (önce STOP)."));
    else if (state() == Homing)
        settings()->setLocked(true, tr("Referans aranırken makinenin ayarları değiştirilemez."));
    else
        settings()->setLocked(false);
}

void SimMachine::setMemoryFile(const QString &path)
{
    m_memoryFile = path;
    m_loadingMemory = true;
    loadMemory(timers(), TimersGroup);
    // Ayarlar birbirine bağlı (ör. alt limit üst limitten küçük): bir değerin aralığı
    // öbürü okununca genişleyebilir. İki tur okumak her sırayı kabul etmeye yeter.
    loadMemory(settings(), SettingsGroup);
    loadMemory(settings(), SettingsGroup);
    m_loadingMemory = false;
}

void SimMachine::loadMemory(ParameterList *list, const QString &group)
{
    // Bellekte geçerli bir değer varsa o kullanılır. Sayı olmayan ya da aralık dışındaki
    // değer (ör. dosya elle bozulmuşsa) yok sayılır: varsayılan kalır.
    QSettings memory(m_memoryFile, QSettings::IniFormat);
    memory.beginGroup(group);
    for (int row = 0; row < list->count(); ++row) {
        const QString key = list->get(row).value(QStringLiteral("key")).toString();
        bool ok = false;
        const double value = memory.value(key).toDouble(&ok);
        if (memory.contains(key) && ok)
            list->setValue(key, value);
    }
}

void SimMachine::remember(const QString &group, const QString &key, double value)
{
    if (m_memoryFile.isEmpty() || m_loadingMemory)
        return;

    // Hemen diske yazılır (sync): elektrik kesilse de ayar kaybolmasın.
    QSettings memory(m_memoryFile, QSettings::IniFormat);
    memory.setValue(group + QLatin1Char('/') + key, value);
    memory.sync();
}

// ---------------------------------------------------------------------------
// Girişler ve çıkışlar (IO TEST)
// ---------------------------------------------------------------------------

void SimMachine::defineIo()
{
    // Silindirlerin iki ucunda birer sensör var: biri bekleme konumunu (açık / geride),
    // öbürü iş konumunu (kapalı / ileride) görür. Silindir yoldayken ikisi de 0'dır.
    IoList *in = inputs();
    in->add(PressureSwitchInput, tr("BASINÇ ŞALTERİ"));
    in->add(ClampOpenInput, tr("MENGENE AÇIK"));
    in->add(ClampClosedInput, tr("MENGENE KAPALI"));
    in->add(MandrelBackInput, tr("MALAFA GERİDE"));
    in->add(MandrelForwardInput, tr("MALAFA İLERİDE"));
    in->add(ColletOpenInput, tr("PENS AÇIK"));
    in->add(ColletClosedInput, tr("PENS KAPALI"));
    const QString homeNames[4] = { tr("X REFERANS SENSÖRÜ"), tr("B REFERANS SENSÖRÜ"),
                                   tr("A REFERANS SENSÖRÜ"), tr("Y REFERANS SENSÖRÜ") };
    for (int i = 0; i < 4; ++i)
        in->add(QLatin1String(HomeSensorInputs[i]), homeNames[i]);

    // Valfler tek bobinli varsayıldı (müşteriye sorulacak): bobine enerji verilince (1)
    // silindir iş konumuna gider, enerji kesilince (0) geri döner. Çift bobinli valfte
    // her yön ayrı bir çıkıştır.
    IoList *out = outputs();
    out->add(PumpOutput, tr("POMPA MOTORU"), tr("1: pompa çalışır, basınç oluşur"));
    out->add(ClampOutput, tr("MENGENE KAPAT VALFİ"), tr("1: mengene kapanır · 0: açılır"));
    out->add(MandrelOutput, tr("MALAFA İLERİ VALFİ"), tr("1: malafa ileri · 0: geri"));
    out->add(ColletOutput, tr("PENS KAPAT VALFİ"), tr("1: pens kapanır · 0: açılır"));
}

void SimMachine::updateIo()
{
    // Girişler: sensörlerin gördüğü. Basınç şalteri, basınç çalışma basıncına ulaşınca 1 olur
    // (makine silindirleri de ancak o zaman sürer).
    IoList *in = inputs();
    in->setActive(PressureSwitchInput, pumpState() == PumpRunning);
    in->setActive(ClampOpenInput, actuatorAt(clamp(), false));
    in->setActive(ClampClosedInput, actuatorAt(clamp(), true));
    in->setActive(MandrelBackInput, actuatorAt(mandrel(), false));
    in->setActive(MandrelForwardInput, actuatorAt(mandrel(), true));
    in->setActive(ColletOpenInput, actuatorAt(collet(), false));
    in->setActive(ColletClosedInput, actuatorAt(collet(), true));
    for (int i = 0; i < 4; ++i) {
        const SimAxis &sim = m_axes[i];
        const double distance = std::abs(sim.axis->position() - sim.params.homePosition);
        in->setActive(QLatin1String(HomeSensorInputs[i]), distance <= SimParameters::HomeSensorWindow);
    }

    // Çıkışlar: makinenin verdiği komutlar.
    IoList *out = outputs();
    out->setActive(PumpOutput, m_pumpCommand);
    out->setActive(ClampOutput, clamp()->command());
    out->setActive(MandrelOutput, mandrel()->command());
    out->setActive(ColletOutput, collet()->command());

    // Çıkış testinin kilitleri: çıkış şu an elle sürülebilir mi?
    out->setLock(PumpOutput, outputLock(nullptr)); // pompanın silindiri yok
    out->setLock(ClampOutput, outputLock(clamp()));
    out->setLock(MandrelOutput, outputLock(mandrel()));
    out->setLock(ColletOutput, outputLock(collet()));
}

QString SimMachine::outputLock(const Actuator *valve) const
{
    // Döngü sürerken (operatörü beklerken de) çıkışları makine sürer.
    if (cycleState() != CycleStopped)
        return tr("Döngü sürüyor (önce STOP)");
    if (!valve)
        return {};

    // Döngü dururken de makinenin kilitleri geçerlidir: valf, silindirin elle kumandasıyla
    // aynı kilitlere uyar (updateInterlocks). IO TEST kuralları atlatmanın yolu değildir:
    // basınç yokken verilen bir valf komutu, pompa çalışınca silindiri beklenmedik bir anda
    // hareket ettirirdi.
    switch (valve->interlock()) {
    case Actuator::PumpOff:
        return tr("Basınç yok");
    case Actuator::AxesMoving:
        return tr("Eksenler hareketli");
    case Actuator::CycleRunning: // döngü yukarıda
    case Actuator::NoInterlock:
        break;
    }
    return {};
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
    // STOP her eksen hareketini keser ve üretim döngüsünü iptal eder. Pompanın
    // kendi START/STOP'u vardır; bu STOP pompayı ve silindirleri etkilemez.
    if (cycleState() != CycleStopped)
        abortCycle(NoFault); // operatörün kararı: arıza sayılmaz

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

    // Kilitli eksen hareket edemez (mengene boruyu tutuyor ya da döngü çalışıyor).
    updateInterlocks();
    if (axis->interlock() != Axis::NoInterlock)
        return;

    // Ekran aralık dışı değeri zaten kabul etmez; makine yine de kendisi kontrol
    // eder. Gerçek PLC de ekrandan gelen değere körü körüne güvenmez.
    // Yeni komut eskisinin yerini alır: süren bir jog varsa iptal olur.
    startMove(*sim, target);
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

bool SimMachine::setOutput(const QString &address, bool on)
{
    // Makinenin kendi denetimi: ekranın butonu kapatmış olmasına güvenilmez.
    updateInterlocks();
    updateIo();
    if (outputs()->indexOf(address) < 0 || !outputs()->lock(address).isEmpty())
        return false;

    // Çıkışı sürmek, makinenin o çıkışa bağlı komutunu vermektir (HAREKET'teki butonlarla
    // aynı komut): pompada START ya da STOP, valfte silindirin komutu.
    if (address == PumpOutput) {
        if (on)
            startPump();
        else
            stopPump();
    } else if (address == ClampOutput) {
        setActuator(clamp(), on);
    } else if (address == MandrelOutput) {
        setActuator(mandrel(), on);
    } else if (address == ColletOutput) {
        setActuator(collet(), on);
    }

    updateInterlocks();
    updateIo();
    return outputs()->isActive(address) == on;
}

void SimMachine::startCycle(const QVariantList &recipe, double dieRadius, double tubeDiameter)
{
    // Makinenin kendi denetimi: ekran engellemiş olsa da makine yine bakar.
    updateInterlocks();
    if (startBlock() != StartReady)
        return;

    // Bekleyen bir döngü varsa START "devam et" demektir.
    if (cycleState() == CycleWaiting) {
        if (waitReason() == WaitTube) {
            // Boru takıldı, pens kapandı: kaldığı aşamadan devam.
            setCycle(CycleRunning, NotWaiting, -1, stepCount());
            beginPhase(m_resumePhase);
            return;
        }
        if (waitReason() == WaitStep) {
            // Yarı otomatik: sıradaki adım.
            setCycle(CycleRunning, NotWaiting, m_stepIndex, stepCount());
            beginStep();
            return;
        }
        // WaitPart: parça bitmişti, yenisi baştan başlar (tarif yeniden okunur).
    }

    // Program, takılı kalıp için mi yazılmış? Başka yarıçapta bükülen parçanın
    // ölçüleri tutmaz; başka çaptaki boru kalıbın oluğuna oturmaz.
    if (std::abs(dieRadius - toolingRadius()) > ToolingTolerance
        || std::abs(tubeDiameter - toolingDiameter()) > ToolingTolerance) {
        m_recipe.clear();
        abortCycle(FaultTooling);
        return;
    }

    // Tarifi makineye yaz. Gerçek makinede bu, adımların PLC'ye aktarılmasıdır.
    m_recipe.clear();
    for (const QVariant &item : recipe) {
        const QVariantMap map = item.toMap();
        RecipeStep step;
        step.command = map.value(QStringLiteral("command")).toInt();
        step.value = map.value(QStringLiteral("value")).toDouble();

        // Ekrandan gelen her şey denetlenir: tanınmayan komut ya da sayı olmayan
        // değer makineyi çalıştırmaz.
        if (step.command < FeedCommand || step.command > RotateCommand
            || !std::isfinite(step.value)) {
            m_recipe.clear();
            abortCycle(FaultRecipe);
            return;
        }
        m_recipe.append(step);
    }

    if (m_recipe.isEmpty()) {
        abortCycle(FaultRecipe);
        return;
    }

    // Yay boyunu takılı kalıp belirler (programınki de aynı olduğu yukarıda denetlendi).
    m_dieRadius = toolingRadius();

    // Araba, boru alma konumundan açınım boyu kadar daha ilerleyecek: yol yetiyor mu?
    // (Gerçek makinede de tarif, eksen limitlerine sığmalıdır.)
    if (loadPosition() + recipeTravel() > m_axes[0].params.maxPosition) {
        m_recipe.clear();
        abortCycle(FaultLimit);
        return;
    }

    m_stepIndex = 0;
    m_resumePhase = Phase::None;
    setCycleFault(NoFault);
    setCycle(CycleRunning, NotWaiting, -1, int(m_recipe.size()));
    beginPhase(Phase::ToLoadPosition);
}

void SimMachine::resetPartCount()
{
    clearPartCount();
}

bool SimMachine::setTooling(double dieRadius, double tubeDiameter, bool mandrel, bool feedDuringBend)
{
    const bool ok = IMachine::setTooling(dieRadius, tubeDiameter, mandrel, feedDuringBend);
    updateInterlocks(); // BAŞLAT durumu hemen güncellensin
    return ok;
}

bool SimMachine::clearTooling()
{
    const bool ok = IMachine::clearTooling();
    updateInterlocks();
    return ok;
}

// ---------------------------------------------------------------------------
// Döngü
// ---------------------------------------------------------------------------

void SimMachine::tick()
{
    // Önceki turdan bu yana geçen gerçek süre (saniye). Program bir an
    // takılırsa her şey ileri zıplamasın diye en fazla 0.1 sn alıyoruz.
    const double dt = qMin(m_clock.restart() / 1000.0, 0.1);

    // PLC gibi: önce girişleri ve hidroliği güncelle, kilitleri hesapla, sonra
    // eksenleri hareket ettir. Üretim döngüsü en son bakar: o turda eksenler
    // nereye geldiyse ona göre bir sonraki adıma geçer.
    updatePump(dt);
    updateActuators(dt);
    updateInterlocks();

    if (state() == Homing)
        updateHoming(dt);
    else
        updateMotion(dt);

    updateCycle(dt);
    updateInterlocks();
    updateIo(); // IO TEST: turun sonunda girişlerin ve çıkışların görüntüsü
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

    // Kural 0: üretim döngüsü sürerken eksenleri makine sürer; elle kumanda
    // kilitlidir. Eksenler döngü beklerken de kilitli kalır: operatör boruyu
    // takarken arabayı oynatırsa döngü kaldığı yerden yanlış devam eder.
    // Silindirler yalnızca adım işlenirken kilitlenir; boru beklenirken pens
    // elle kumanda edilebilmelidir.
    const bool cycleActive = cycleState() != CycleStopped;
    const bool cycleRunning = cycleState() == CycleRunning;

    // Kural 1: mengene boruyu tutarken X (ilerletme) ve A (rotasyon) hareket edemez;
    // boru kıskaçtayken çekilir ya da burulur. Y (öteleme) de kilitlenir: sıkılı boruyu
    // yana kaydırmak boruyu zorlar (güvenli taraftaki varsayım). B (büküm) serbesttir.
    const Axis::Interlock axisLock = cycleActive ? Axis::CycleActive
                                     : clampHolding ? Axis::ClampClosed
                                                    : Axis::NoInterlock;
    axisX()->setInterlock(axisLock);
    axisA()->setInterlock(axisLock);
    axisY()->setInterlock(axisLock);
    axisB()->setInterlock(cycleActive ? Axis::CycleActive : Axis::NoInterlock);

    // Kural 2: basınç yoksa hiçbir silindir kumanda edilemez.
    // Kural 3: X, A ya da Y hareket ederken mengene kumanda edilemez.
    const Actuator::Interlock actuatorLock = cycleRunning ? Actuator::CycleRunning
                                             : pumpOk     ? Actuator::NoInterlock
                                                          : Actuator::PumpOff;
    clamp()->setInterlock(cycleRunning ? Actuator::CycleRunning
                          : !pumpOk    ? Actuator::PumpOff
                          : axesBusy   ? Actuator::AxesMoving
                                       : Actuator::NoInterlock);
    mandrel()->setInterlock(actuatorLock);
    collet()->setInterlock(actuatorLock);

    updateSettingsLock();
    updateStartBlock();
}

// Döngü başlatılabilir mi? Ekranın START butonu bunu gösterir; makine yine de
// startCycle içinde kendisi bakar (ekrana körü körüne güvenilmez).
void SimMachine::updateStartBlock()
{
    StartBlock block = StartReady;

    if (cycleState() == CycleRunning)
        block = BlockRunning;
    else if (state() != Ready)
        block = BlockNotHomed; // referanssız makinede konumlar bilinmez
    else if (pumpState() != PumpRunning)
        block = BlockPumpOff; // mengene, malafa ve pens basınçsız çalışmaz
    else if (!hasTooling())
        block = BlockNoTooling; // hangi kalıbın takılı olduğu bilinmeden bükülmez
    else if (cycleState() == CycleWaiting && waitReason() == WaitTube && !actuatorAt(collet(), true))
        block = BlockColletOpen; // boru bekleniyor: önce pens kapatılmalı
    else if (clamp()->command() || clamp()->state() != Actuator::Off)
        block = BlockClampClosed; // mengene kapalıyken araba boru alma konumuna gidemez

    setStartBlock(block);
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

void SimMachine::updateMotion(double dt)
{
    for (SimAxis &sim : m_axes) {
        Axis *axis = sim.axis;

        // Güvenlik: kilitlenmiş eksen hareket ediyorsa hemen durdur. Kilit elle
        // kumanda kuralıdır; hareketi döngü başlattıysa makine kendi işini yapar.
        if (!sim.cycleMove && axis->interlock() != Axis::NoInterlock
            && (sim.positioning || sim.jogDirection != 0)) {
            haltMotion(sim);
            continue;
        }

        // Konuma git: hedefe sabit hızla ilerle, varınca tam hedefte dur.
        if (sim.positioning) {
            const double remaining = sim.moveTarget - axis->position();
            const double speed = sim.moveSpeed > 0.0 ? sim.moveSpeed : sim.params.moveSpeed;
            const double step = speed * dt;
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
        const double current = axis->position();
        double position = current + sim.jogDirection * speed * dt;

        // Yazılım limitleri yalnızca referanslı eksende geçerli. Yalnızca gidilen yöndeki
        // limite bakılır: limitler AYARLAR'dan daraltıldıysa dışarıda kalan eksen içeri
        // doğru gidebilir, dışarı doğru gidemez.
        bool reachedLimit = false;
        if (axis->isHomed()) {
            if (sim.jogDirection > 0 && position >= sim.params.maxPosition) {
                position = std::max(current, sim.params.maxPosition);
                reachedLimit = true;
            } else if (sim.jogDirection < 0 && position <= sim.params.minPosition) {
                position = std::min(current, sim.params.minPosition);
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
// Üretim döngüsü
//
// Döngüyü makine yürütür; ekran yalnızca tarifi gönderir, START/STOP der ve
// durumu gösterir. Gerçek makinede bu sıra PLC'nin içindedir: ekran donsa ya da
// kapansa bile makine parçayı bitirir. Aşağıdaki iki fonksiyon bir PLC adım
// zincirinin (step chain) karşılığıdır:
//   beginPhase  aşamaya girerken komutları verir (hedefi, valfi)
//   updateCycle her turda "bu aşama bitti mi?" diye bakar, bittiyse ilerler
// ---------------------------------------------------------------------------

void SimMachine::updateCycle(double dt)
{
    if (cycleState() != CycleRunning)
        return;

    // Basınç kesilirse ne mengene ne malafa çalışır: döngü sürdürülemez.
    if (pumpState() != PumpRunning) {
        abortCycle(FaultPressure);
        return;
    }

    // Her aşamanın bir üst süresi var: beklenen olay gelmezse döngü arızayla
    // durur. Sensörü bozuk bir makinenin sonsuza kadar beklemesi tehlikelidir.
    m_phaseTime += dt;
    if (m_phaseTimeout > 0.0 && m_phaseTime > m_phaseTimeout) {
        abortCycle(FaultTimeout);
        return;
    }

    const SimAxis &feed = m_axes[0];
    const SimAxis &bend = m_axes[1];
    const SimAxis &rotate = m_axes[2];

    switch (m_phase) {
    case Phase::None:
        break;

    case Phase::ToLoadPosition:
        if (!axisIdle(feed) || !axisIdle(bend) || !axisIdle(rotate) || !actuatorAt(mandrel(), false))
            break;
        // Boru takılı mı? Pens açıksa operatör beklenir.
        if (!actuatorAt(collet(), true)) {
            m_resumePhase = Phase::MandrelOut;
            waitForOperator(WaitTube);
            break;
        }
        beginPhase(Phase::MandrelOut);
        break;

    case Phase::MandrelOut:
        if (!toolingMandrel() || actuatorAt(mandrel(), true))
            beginStep();
        break;

    case Phase::Feed:
        if (axisIdle(feed))
            stepFinished();
        break;

    case Phase::ClampClose:
        if (actuatorAt(clamp(), true))
            beginPhase(Phase::ClampDwell);
        break;

    case Phase::ClampDwell:
        if (m_phaseTime >= timer(ClampDwellKey))
            beginPhase(Phase::Bend);
        break;

    case Phase::Bend:
        followBend();
        if (axisIdle(bend))
            beginPhase(Phase::BendDwell);
        break;

    case Phase::BendDwell:
        if (m_phaseTime >= timer(BendDwellKey))
            beginPhase(Phase::ClampOpen);
        break;

    case Phase::ClampOpen:
        if (actuatorAt(clamp(), false))
            beginPhase(Phase::BendHome);
        break;

    case Phase::BendHome:
        if (axisIdle(bend))
            stepFinished();
        break;

    case Phase::Rotate:
        if (axisIdle(rotate))
            stepFinished();
        break;

    case Phase::StepPause:
        if (m_phaseTime >= timer(StepPauseKey))
            beginStep();
        break;

    case Phase::MandrelBack:
        if (actuatorAt(mandrel(), false))
            beginPhase(Phase::ColletOpen);
        break;

    case Phase::ColletOpen:
        if (!actuatorAt(collet(), false))
            break;
        // Parça bitti: sayaçlar artar, operatör parçayı alıp START'a basar.
        countPart();
        waitForOperator(WaitPart);
        break;
    }
}

void SimMachine::beginPhase(Phase phase)
{
    m_phase = phase;
    m_phaseTime = 0.0;
    m_phaseTimeout = 0.0;

    SimAxis &feed = m_axes[0];
    SimAxis &bend = m_axes[1];
    SimAxis &rotate = m_axes[2];

    // İşlenen adımın değeri (aşama bir adıma ait değilse kullanılmaz).
    const RecipeStep step = m_stepIndex >= 0 && m_stepIndex < m_recipe.size()
                                ? m_recipe.at(m_stepIndex)
                                : RecipeStep {};

    switch (phase) {
    case Phase::None:
        break;

    case Phase::ToLoadPosition:
        // Parçanın başı: malafa geri çekilir, büküm kolu ve rotasyon başa döner,
        // araba boru alma konumuna gider. Böylece her parça aynı yerden başlar.
        // ROTASYON değerleri mutlak olduğu için borunun başlangıç açısı bilinmeli:
        // her parça A = 0'da başlar (SİMÜLASYON'daki şekil de bunu varsayar).
        mandrel()->setCommand(false);
        m_phaseTimeout = timer(MoveTimeoutKey);
        if (!startMove(feed, loadPosition()) || !startMove(bend, 0.0)
            || !startMove(rotate, 0.0))
            abortCycle(FaultLimit);
        break;

    case Phase::MandrelOut:
        // Malafalı büküm takılı kalıbın ayarıdır (müşterinin ekranında MALAFALI BÜK).
        if (toolingMandrel())
            mandrel()->setCommand(true);
        m_phaseTimeout = timer(ActuatorTimeoutKey);
        break;

    case Phase::Feed:
        // İLERLE göreli: araba bulunduğu yerden bu kadar daha ilerler.
        m_phaseTimeout = timer(MoveTimeoutKey);
        if (!startMove(feed, feed.axis->position() + step.value))
            abortCycle(FaultLimit);
        break;

    case Phase::ClampClose:
        clamp()->setCommand(true);
        m_phaseTimeout = timer(ActuatorTimeoutKey);
        break;

    case Phase::ClampDwell:
    case Phase::BendDwell:
        break; // yalnızca süre bekler (süre ZAMANLAR'dan)

    case Phase::Bend:
        // Büküm sırasında araba yayı takip edecek: başlangıç noktaları saklanır.
        m_bendStartX = feed.axis->position();
        m_bendStartAngle = bend.axis->position();
        m_phaseTimeout = timer(MoveTimeoutKey);
        if (!startMove(bend, step.value))
            abortCycle(FaultLimit);
        break;

    case Phase::ClampOpen:
        clamp()->setCommand(false);
        m_phaseTimeout = timer(ActuatorTimeoutKey);
        break;

    case Phase::BendHome:
        // Kol başa döner; boru olduğu yerde kalır (araba geri gelmez).
        m_phaseTimeout = timer(MoveTimeoutKey);
        if (!startMove(bend, 0.0))
            abortCycle(FaultLimit);
        break;

    case Phase::Rotate:
        m_phaseTimeout = timer(MoveTimeoutKey);
        if (!startMove(rotate, step.value))
            abortCycle(FaultLimit);
        break;

    case Phase::StepPause:
        break; // yalnızca süre bekler

    case Phase::MandrelBack:
        mandrel()->setCommand(false);
        m_phaseTimeout = timer(ActuatorTimeoutKey);
        break;

    case Phase::ColletOpen:
        collet()->setCommand(false);
        m_phaseTimeout = timer(ActuatorTimeoutKey);
        break;
    }
}

void SimMachine::beginStep()
{
    // Adım kalmadıysa parça biter.
    if (m_stepIndex < 0 || m_stepIndex >= m_recipe.size()) {
        beginPhase(Phase::MandrelBack);
        return;
    }

    setCycle(CycleRunning, NotWaiting, m_stepIndex, int(m_recipe.size()));

    switch (m_recipe.at(m_stepIndex).command) {
    case BendCommand:
        beginPhase(Phase::ClampClose); // büküm: mengene → bük → mengene aç → kol başa
        break;
    case RotateCommand:
        beginPhase(Phase::Rotate);
        break;
    default:
        beginPhase(Phase::Feed);
        break;
    }
}

void SimMachine::stepFinished()
{
    ++m_stepIndex;

    if (m_stepIndex >= m_recipe.size()) {
        beginPhase(Phase::MandrelBack); // son adım bitti: parça tamamlanıyor
        return;
    }

    // Yarı otomatikte her adımdan sonra operatör beklenir: program denenirken
    // adımlar tek tek görülür. Otomatikte kısa bir duraklamayla devam edilir.
    if (cycleMode() == SemiAutomaticCycle)
        waitForOperator(WaitStep);
    else
        beginPhase(Phase::StepPause);
}

void SimMachine::waitForOperator(WaitReason reason)
{
    m_phase = Phase::None;
    m_phaseTime = 0.0;
    m_phaseTimeout = 0.0;

    // Adım beklenirken sıradaki adım gösterilir; boru ve parça beklenirken adım yok.
    const int step = reason == WaitStep ? m_stepIndex : -1;
    setCycle(CycleWaiting, reason, step, int(m_recipe.size()));
}

void SimMachine::abortCycle(CycleFault fault)
{
    // Hareket kesilir; silindirler olduğu gibi kalır. Yarıda kalan bir parçada
    // mengenenin kendiliğinden açılması tehlikelidir: kararı operatör verir.
    haltAllMotion();
    m_phase = Phase::None;
    m_resumePhase = Phase::None;
    m_phaseTime = 0.0;
    m_phaseTimeout = 0.0;
    setCycle(CycleStopped, NotWaiting, -1, int(m_recipe.size()));
    setCycleFault(fault);
}

void SimMachine::followBend()
{
    // Boru kalıba sarıldıkça arkadan boru "yutulur": pens boruyu tuttuğu için araba,
    // yayın harcadığı boy kadar ilerlemek zorundadır (yay boyu = kalıp yarıçapı × açı).
    // BÜKÜMDE İLERLE açıksa araba motorla itilir (destek), kapalıysa boru onu
    // sürükler; iki durumda da konum aynı yere varır, simülasyonda fark görünmez.
    // Bu, makinenin kendi hareketidir; mengene kilidi elle kumanda içindir.
    SimAxis &feed = m_axes[0];
    const SimAxis &bend = m_axes[1];
    const double arc = m_dieRadius
                       * qDegreesToRadians(bend.axis->position() - m_bendStartAngle);
    feed.axis->setPosition(
        qBound(feed.params.minPosition, m_bendStartX + arc, feed.params.maxPosition));
    feed.axis->setMoving(!axisIdle(bend));
    updateLimitState(feed);
}

double SimMachine::recipeTravel() const
{
    // Arabanın parça boyunca gideceği toplam yol: düz parçalar + yay boyları.
    // Programın açınım boyunun karşılığıdır.
    double travel = 0.0;
    for (const RecipeStep &step : m_recipe) {
        if (step.command == FeedCommand)
            travel += step.value;
        else if (step.command == BendCommand)
            travel += m_dieRadius * qDegreesToRadians(step.value);
    }
    return travel;
}

// ---------------------------------------------------------------------------
// Yardımcılar
// ---------------------------------------------------------------------------

bool SimMachine::startMove(SimAxis &sim, double target, double speed)
{
    // Limit dışındaki hedef reddedilir: hareket hiç başlamaz.
    if (!std::isfinite(target) || target < sim.params.minPosition
        || target > sim.params.maxPosition)
        return false;

    sim.jogDirection = 0;
    sim.moveTarget = target;
    sim.moveSpeed = speed;
    // Hareketi döngü mü başlattı? (Döngü çalışırken elle komut zaten kabul edilmez.)
    sim.cycleMove = cycleState() == CycleRunning;
    sim.positioning = true;
    return true;
}

bool SimMachine::axisIdle(const SimAxis &sim) const
{
    return !sim.positioning && sim.jogDirection == 0;
}

bool SimMachine::actuatorAt(const Actuator *actuator, bool on) const
{
    // Sensör ne diyor? Komut değil, silindirin gerçekten yerine gitmesi beklenir.
    return actuator->state() == (on ? Actuator::On : Actuator::Off);
}

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
    sim.moveSpeed = 0.0;
    sim.cycleMove = false;
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
