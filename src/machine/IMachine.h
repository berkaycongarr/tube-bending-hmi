#pragma once

#include <QObject>
#include <QVariant>

#include <cmath>
#include <QtQml/qqmlregistration.h>

#include "Actuator.h"
#include "AlarmList.h"
#include "Axis.h"
#include "IoList.h"
#include "ParameterList.h"

// Makineyle konuşma sözleşmesi.
//
// Ekran (QML) yalnızca bu sınıfı tanır. Arkasında demo için sanal makine
// (SimMachine) ya da gerçek iş için PLC bağlantısı (ileride SiemensMachine)
// durabilir. Ortak durum burada tutulur; komutları alt sınıflar uygular.
//
// QML tarafında bu sınıfın adı "Machine"dır.
class IMachine : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Machine)
    QML_UNCREATABLE("Makine nesnesi C++ tarafında oluşturulur.")

    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool simulation READ isSimulation CONSTANT)
    Q_PROPERTY(Axis *axisX READ axisX CONSTANT)
    Q_PROPERTY(Axis *axisB READ axisB CONSTANT)
    Q_PROPERTY(Axis *axisA READ axisA CONSTANT)
    Q_PROPERTY(Axis *axisY READ axisY CONSTANT)
    Q_PROPERTY(PumpState pumpState READ pumpState NOTIFY pumpStateChanged)
    Q_PROPERTY(double pressure READ pressure NOTIFY pressureChanged)
    Q_PROPERTY(Actuator *clamp READ clamp CONSTANT)
    Q_PROPERTY(Actuator *mandrel READ mandrel CONSTANT)
    Q_PROPERTY(Actuator *collet READ collet CONSTANT)
    Q_PROPERTY(CycleState cycleState READ cycleState NOTIFY cycleChanged)
    Q_PROPERTY(WaitReason waitReason READ waitReason NOTIFY cycleChanged)
    Q_PROPERTY(CycleFault cycleFault READ cycleFault NOTIFY cycleChanged)
    Q_PROPERTY(int currentStep READ currentStep NOTIFY cycleChanged)
    Q_PROPERTY(int stepCount READ stepCount NOTIFY cycleChanged)
    Q_PROPERTY(StartBlock startBlock READ startBlock NOTIFY startBlockChanged)
    Q_PROPERTY(CycleMode cycleMode READ cycleMode WRITE setCycleMode NOTIFY cycleModeChanged)
    Q_PROPERTY(int partCount READ partCount NOTIFY countersChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY countersChanged)
    Q_PROPERTY(double loadPosition READ loadPosition NOTIFY loadPositionChanged)
    Q_PROPERTY(bool hasTooling READ hasTooling NOTIFY toolingChanged)
    Q_PROPERTY(double toolingRadius READ toolingRadius NOTIFY toolingChanged)
    Q_PROPERTY(double toolingDiameter READ toolingDiameter NOTIFY toolingChanged)
    Q_PROPERTY(bool toolingMandrel READ toolingMandrel NOTIFY toolingChanged)
    Q_PROPERTY(bool toolingFeedDuringBend READ toolingFeedDuringBend NOTIFY toolingChanged)
    Q_PROPERTY(ParameterList *timers READ timers CONSTANT)
    Q_PROPERTY(ParameterList *settings READ settings CONSTANT)
    Q_PROPERTY(IoList *inputs READ inputs CONSTANT)
    Q_PROPERTY(IoList *outputs READ outputs CONSTANT)
    Q_PROPERTY(AlarmList *alarms READ alarms CONSTANT)
    Q_PROPERTY(bool hasAlarm READ hasAlarm NOTIFY alarmsChanged)
    Q_PROPERTY(QString alarmTitle READ alarmTitle NOTIFY alarmsChanged)
    Q_PROPERTY(QString alarmDetail READ alarmDetail NOTIFY alarmsChanged)
    Q_PROPERTY(int alarmCount READ alarmCount NOTIFY alarmsChanged)
    Q_PROPERTY(bool canResetAlarms READ canResetAlarms NOTIFY alarmsChanged)

public:
    enum State {
        NotHomed, // Referanssız: eksenlerin gerçek konumu henüz bilinmiyor
        Homing,   // Referans aranıyor
        Ready     // Hazır: tüm eksenler referanslı
    };
    Q_ENUM(State)

    enum PumpState {
        PumpStopped,  // durdu, basınç yok
        PumpStarting, // çalışmaya başladı, basınç yükseliyor
        PumpRunning,  // çalışıyor, basınç tam
        PumpStopping  // durduruldu, basınç düşüyor
    };
    Q_ENUM(PumpState)

    // Üretim döngüsü. Adımları makine yürütür (gerçek makinede PLC); ekran
    // yalnızca tarifi gönderir, START/STOP der ve durumu gösterir.
    enum CycleState {
        CycleStopped, // döngü yok
        CycleRunning, // çalışıyor
        CycleWaiting  // operatörü bekliyor (START)
    };
    Q_ENUM(CycleState)

    enum WaitReason {
        NotWaiting,
        WaitTube, // boru takılıp pens kapatılmalı
        WaitStep, // yarı otomatik: adım bitti, sıradaki için START
        WaitPart  // parça bitti, yenisi için START
    };
    Q_ENUM(WaitReason)

    // Döngü neden başlatılamıyor? (makinenin kendi denetimi)
    enum StartBlock {
        StartReady,       // başlatılabilir
        BlockRunning,     // zaten çalışıyor
        BlockNotHomed,    // referans yok
        BlockPumpOff,     // hidrolik pompa çalışmıyor
        BlockClampClosed, // mengene kapalı: önce açılmalı
        BlockColletOpen,  // boru beklenirken pens hâlâ açık
        BlockNoTooling,   // makineye takılı kalıp bildirilmemiş
        BlockAlarm        // silinmemiş arıza var: önce RESET
    };
    Q_ENUM(StartBlock)

    enum CycleFault {
        NoFault,
        FaultTimeout, // adım beklenen sürede bitmedi
        FaultLimit,   // tarif eksen limitlerine sığmıyor
        FaultRecipe,   // tarif boş ya da hatalı
        FaultPressure, // döngü sırasında hidrolik basınç kesildi
        FaultTooling   // program takılı kalıba uymuyor (yarıçap ya da boru çapı farklı)
    };
    Q_ENUM(CycleFault)

    enum CycleMode {
        AutomaticCycle,    // START: parçanın bütün adımları
        SemiAutomaticCycle // START: tek adım (program denerken)
    };
    Q_ENUM(CycleMode)

    explicit IMachine(QObject *parent = nullptr)
        : QObject(parent)
        , m_axisX(new Axis(QStringLiteral("X"), false, this))
        , m_axisB(new Axis(QStringLiteral("B"), true, this))
        , m_axisA(new Axis(QStringLiteral("A"), true, this))
        , m_axisY(new Axis(QStringLiteral("Y"), false, this))
        , m_clamp(new Actuator(this))
        , m_mandrel(new Actuator(this))
        , m_collet(new Actuator(this))
        , m_timers(new ParameterList(this))
        , m_settings(new ParameterList(this))
        , m_inputs(new IoList(this))
        , m_outputs(new IoList(this))
        , m_alarms(new AlarmList(this))
    {
        // Arıza listesi değişince ekranın bağlamaları yenilensin.
        connect(m_alarms, &AlarmList::changed, this, &IMachine::alarmsChanged);
    }

    State state() const { return m_state; }
    Axis *axisX() const { return m_axisX; } // ilerletme: araba boruyu iter (mm)
    Axis *axisB() const { return m_axisB; } // büküm kolu (derece)
    Axis *axisA() const { return m_axisA; } // rotasyon: boru kendi ekseninde döner (derece)
    Axis *axisY() const { return m_axisY; } // öteleme (mm); görevi müşteriye sorulacak

    PumpState pumpState() const { return m_pumpState; }
    double pressure() const { return m_pressure; } // hidrolik basınç (bar)
    Actuator *clamp() const { return m_clamp; }     // mengene: boruyu büküm kalıbına sıkar
    Actuator *mandrel() const { return m_mandrel; } // malafa: bükülen yerde borunun içine girer
    Actuator *collet() const { return m_collet; }   // pens: arabada borunun ucunu tutar

    // Makinenin süreleri (ZAMANLAR sayfası): bekleme süreleri ve zaman aşımları.
    // Değerler makinenin belleğinde durur (gerçek makinede PLC); ekran okur ve yazar.
    // Hangi sürelerin olduğunu makine belirler (anahtarlar SimMachine.cpp'de).
    ParameterList *timers() const { return m_timers; }

    // Makinenin ayarları (AYARLAR sayfası): boru alma konumu, eksenlerin yazılım limitleri
    // ve hızları. Döngü sürerken ya da referans aranırken makine bu listeyi kilitler.
    ParameterList *settings() const { return m_settings; }

    // Makinenin girişleri (sensörler, şalterler) ve çıkışları (pompa, valfler): IO TEST
    // sayfası bunları canlı gösterir. Hangi noktaların olduğunu ve adreslerini makine
    // belirler (demoda SimMachine.cpp'de; gerçek makinede elektrik şemasından).
    IoList *inputs() const { return m_inputs; }
    IoList *outputs() const { return m_outputs; }

    // Makinenin arızaları: duranlar ve geçmiş (üst şeritteki alarm ve ARIZA GEÇMİŞİ).
    AlarmList *alarms() const { return m_alarms; }

    bool hasAlarm() const { return m_alarms->hasUnresolved(); } // silinmemiş arıza var mı?
    int alarmCount() const { return m_alarms->unresolved(); }
    bool canResetAlarms() const { return m_alarms->canReset(); } // RESET bir şey siler mi?

    // Silinmemiş arızaların en yenisi: üst şeritte bu yazar.
    QString alarmTitle() const
    {
        const AlarmList::Alarm *alarm = m_alarms->newest();
        return alarm ? alarm->title : QString();
    }

    QString alarmDetail() const
    {
        const AlarmList::Alarm *alarm = m_alarms->newest();
        return alarm ? alarm->detail : QString();
    }

    // RESET: sebebi geçmiş arızaları siler. Hiçbir şeyi hareket ettirmez, hiçbir şey
    // başlatmaz; yalnızca yeniden başlatmaya izin verir (ISO 13850'nin acil stop için
    // koyduğu kural burada bütün arızalar için uygulanır). Sebebi süren arıza silinmez.
    Q_INVOKABLE virtual bool resetAlarms() { return m_alarms->reset() > 0; }

    // Sanal makine mi? Ekranda "SANAL MAKİNE" etiketi göstermek için.
    virtual bool isSimulation() const = 0;

    // Komutlar: ekrandaki butonlar bunları çağırır.
    Q_INVOKABLE virtual void startHoming() = 0; // Referans ara (HOME)
    Q_INVOKABLE virtual void stop() = 0;        // Tüm eksen hareketlerini durdur (STOP)

    // Elle sürme (jog), push buton mantığıyla:
    //   startJog      butona basıldı: ekseni verilen yönde (-1 / +1) sürmeye başla
    //   keepJogAlive  buton hâlâ basılı: ekran bunu 100 ms'de bir çağırır
    //   stopJog       buton bırakıldı: dur
    // Makine bir süre "hâlâ basılı" haberi alamazsa ekseni kendisi durdurur
    // (bekçi zamanlayıcı). Böylece ekran donsa bile eksen kaçmaz.
    Q_INVOKABLE virtual void startJog(Axis *axis, int direction, bool fast) = 0;
    Q_INVOKABLE virtual void keepJogAlive(Axis *axis) = 0;
    Q_INVOKABLE virtual void stopJog(Axis *axis) = 0;

    // Konuma git ("değer gir"): ekseni verilen mutlak konuma götürür.
    // Yalnızca makine HAZIR iken çalışır; limit dışındaki hedefi makine reddeder.
    Q_INVOKABLE virtual void moveTo(Axis *axis, double target) = 0;

    // Hidrolik pompa, "normal start/stop" mantığıyla: START ve STOP ayrı
    // butonlardır, pompanın çalıştığını makine hatırlar (mühürleme).
    Q_INVOKABLE virtual void startPump() = 0;
    Q_INVOKABLE virtual void stopPump() = 0;

    // Silindir, "kalıcı buton" mantığıyla: bir basış iş konumuna gönderir
    // (on = true), ikinci basış geri alır. Komutu makine hatırlar.
    Q_INVOKABLE virtual void setActuator(Actuator *actuator, bool on) = 0;

    // Çıkış testi (IO TEST): bir çıkışı adresiyle elle sür (on = 1 ya da 0). Çıkışı sürmek,
    // makinenin o çıkışa bağlı komutunu vermektir (pompa START/STOP, silindir valfi):
    // makinenin kilitleri burada da geçerlidir. Makine kabul etmezse false döner: adres
    // bilinmiyor ya da çıkışın kilidi var (outputs listesindeki "lock", ör. döngü sürüyor).
    Q_INVOKABLE virtual bool setOutput(const QString &address, bool on) = 0;

    // Takılı kalıp -----------------------------------------------------------
    // Makineye hangi kalıbın takılı olduğunu ekran bildirir: kalıp yarıçapı (yay
    // boyu bununla hesaplanır), aldığı boru çapı, malafalı büküm ve bükümde ilerle.
    // Gerçek makinede bu değerler kalıp değiştirilince PLC'ye kalıp ayarı olarak
    // yazılır. Döngü sürerken (beklerken de) kalıp değişmez: false döner.
    Q_INVOKABLE virtual bool setTooling(double dieRadius, double tubeDiameter, bool mandrel,
                                        bool feedDuringBend)
    {
        if (m_cycleState != CycleStopped || !std::isfinite(dieRadius) || !(dieRadius > 0.0)
            || !std::isfinite(tubeDiameter) || !(tubeDiameter > 0.0))
            return false;
        m_hasTooling = true;
        m_toolingRadius = dieRadius;
        m_toolingDiameter = tubeDiameter;
        m_toolingMandrel = mandrel;
        m_toolingFeedDuringBend = feedDuringBend;
        emit toolingChanged();
        return true;
    }

    // Takılı kalıp bilinmiyor (ör. kalıp listesinde işaretli kalıp yok).
    Q_INVOKABLE virtual bool clearTooling()
    {
        if (m_cycleState != CycleStopped)
            return false;
        if (m_hasTooling) {
            m_hasTooling = false;
            emit toolingChanged();
        }
        return true;
    }

    bool hasTooling() const { return m_hasTooling; }
    double toolingRadius() const { return m_hasTooling ? m_toolingRadius : 0.0; }
    double toolingDiameter() const { return m_hasTooling ? m_toolingDiameter : 0.0; }
    bool toolingMandrel() const { return m_hasTooling && m_toolingMandrel; }
    bool toolingFeedDuringBend() const { return m_hasTooling && m_toolingFeedDuringBend; }

    // Üretim döngüsü -------------------------------------------------------
    // START: tarifi (program adımlarını) makineye gönderir ve döngüyü başlatır
    // ya da bekleyen döngüye devam eder. Gerçek makinede tarif PLC'ye yazılır.
    // Her adım { "command": 0/1/2, "value": sayı }:
    //   0 İLERLE   : boruyu bu kadar mm ilerlet (göreli)
    //   1 BÜK      : büküm kolunu bu açıya çevir (mutlak, 0'dan başlar)
    //   2 ROTASYON : boruyu bu açıya döndür (mutlak; müşteriye sorulacak varsayım)
    // dieRadius ve tubeDiameter, programın yazıldığı kalıbın değerleridir: makine
    // bunları takılı kalıpla karşılaştırır, uymuyorsa parça başlamaz.
    Q_INVOKABLE virtual void startCycle(const QVariantList &recipe, double dieRadius,
                                        double tubeDiameter) = 0;
    Q_INVOKABLE virtual void resetPartCount() = 0; // üretilen adet sayacını sıfırla

    // Döngü durumu
    CycleState cycleState() const { return m_cycleState; }
    WaitReason waitReason() const { return m_waitReason; }
    CycleFault cycleFault() const { return m_cycleFault; }
    int currentStep() const { return m_currentStep; } // çalışan adım (-1: yok)
    int stepCount() const { return m_stepCount; }     // tarifteki adım sayısı
    StartBlock startBlock() const { return m_startBlock; }
    int partCount() const { return m_partCount; }   // bu programda üretilen adet
    int totalCount() const { return m_totalCount; } // makinenin toplam adedi

    // Boru alma konumu: her parça buradan başlar, boru burada takılır (mm).
    // Müşterinin ekranında "BORU ALMA KONUM X" olarak görünüyor; AYARLAR'dan değişir.
    double loadPosition() const { return m_loadPosition; }

    CycleMode cycleMode() const { return m_cycleMode; }

    // Mod yalnızca döngü çalışmıyorken değişir: yarısında değiştirmek operatör
    // için de makine için de karışıklık yaratır.
    void setCycleMode(CycleMode mode)
    {
        if (m_cycleMode == mode || m_cycleState == CycleRunning)
            return;
        m_cycleMode = mode;
        emit cycleModeChanged();
    }

    // Toplam adet makine kapanınca kaybolmaz: açılışta geri yüklenir.
    void setTotalCount(int count)
    {
        if (m_totalCount == count)
            return;
        m_totalCount = count;
        emit countersChanged();
    }

signals:
    void stateChanged();
    void pumpStateChanged();
    void pressureChanged();
    void cycleChanged();      // döngü durumu, adım ya da arıza değişti
    void cycleModeChanged();
    void startBlockChanged();
    void countersChanged();
    void toolingChanged();
    void loadPositionChanged();
    void alarmsChanged(); // arıza oluştu, sebebi değişti ya da silindi

protected:
    // Arıza bildir (alt sınıflar kullanır). persistent: sebebi sürüyor demektir; böyle bir
    // arıza, sebebi geçtiği makine tarafından bildirilene kadar RESET ile silinemez.
    void raiseAlarm(const QString &code, const QString &title, const QString &detail,
                    bool persistent = false)
    {
        m_alarms->raise(code, title, detail, persistent);
    }

    // Süren bir arızanın sebebi geçti (ya da yeniden oluştu).
    void setAlarmCondition(const QString &code, bool present)
    {
        m_alarms->setCondition(code, present);
    }

    // Boru alma konumu makinenin ayarıdır: alt sınıf yazar (açılışta ve ayar değişince).
    void setLoadPosition(double position)
    {
        if (m_loadPosition == position)
            return;
        m_loadPosition = position;
        emit loadPositionChanged();
    }

    // Bu değerleri yalnızca alt sınıflar değiştirebilir.
    void setState(State state)
    {
        if (m_state == state)
            return;
        m_state = state;
        emit stateChanged();
    }

    void setPumpState(PumpState pumpState)
    {
        if (m_pumpState == pumpState)
            return;
        m_pumpState = pumpState;
        emit pumpStateChanged();
    }

    void setPressure(double pressure)
    {
        if (m_pressure == pressure)
            return;
        m_pressure = pressure;
        emit pressureChanged();
    }

    void setCycle(CycleState state, WaitReason reason, int step, int stepCount)
    {
        if (m_cycleState == state && m_waitReason == reason && m_currentStep == step
            && m_stepCount == stepCount)
            return;
        m_cycleState = state;
        m_waitReason = reason;
        m_currentStep = step;
        m_stepCount = stepCount;
        emit cycleChanged();
    }

    void setCycleFault(CycleFault fault)
    {
        if (m_cycleFault == fault)
            return;
        m_cycleFault = fault;
        emit cycleChanged();
    }

    void setStartBlock(StartBlock block)
    {
        if (m_startBlock == block)
            return;
        m_startBlock = block;
        emit startBlockChanged();
    }

    // Bir parça bitti: iki sayaç da artar.
    void countPart()
    {
        ++m_partCount;
        ++m_totalCount;
        emit countersChanged();
    }

    void clearPartCount()
    {
        if (m_partCount == 0)
            return;
        m_partCount = 0;
        emit countersChanged();
    }

private:
    State m_state = NotHomed;
    PumpState m_pumpState = PumpStopped;
    double m_pressure = 0.0;
    CycleState m_cycleState = CycleStopped;
    WaitReason m_waitReason = NotWaiting;
    CycleFault m_cycleFault = NoFault;
    CycleMode m_cycleMode = AutomaticCycle;
    StartBlock m_startBlock = BlockNotHomed;
    int m_currentStep = -1;
    int m_stepCount = 0;
    int m_partCount = 0;
    int m_totalCount = 0;
    double m_loadPosition = 0.0;
    bool m_hasTooling = false;
    double m_toolingRadius = 0.0;
    double m_toolingDiameter = 0.0;
    bool m_toolingMandrel = false;
    bool m_toolingFeedDuringBend = false;
    Axis *const m_axisX;
    Axis *const m_axisB;
    Axis *const m_axisA;
    Axis *const m_axisY;
    Actuator *const m_clamp;
    Actuator *const m_mandrel;
    Actuator *const m_collet;
    ParameterList *const m_timers;
    ParameterList *const m_settings;
    IoList *const m_inputs;
    IoList *const m_outputs;
    AlarmList *const m_alarms;
};
