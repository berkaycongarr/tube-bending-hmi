#pragma once

#include <QDeadlineTimer>
#include <QElapsedTimer>
#include <QTimer>

#include <array>

#include "IMachine.h"
#include "SimParameters.h"

// Demo için sanal makine.
//
// Gerçek makinede eksenleri ve silindirleri PLC hareket ettirir. SimMachine bir
// "sanal PLC" gibi davranır: PLC'lerin tarama döngüsü (scan cycle) gibi sabit
// aralıklarla dönen bir döngüde her şeyi günceller ve kilit kurallarını uygular.
class SimMachine : public IMachine
{
    Q_OBJECT

public:
    explicit SimMachine(QObject *parent = nullptr);

    // Makinenin belleği: ayarlanabilir değerlerin (ZAMANLAR) saklandığı dosya.
    // Gerçek makinede bu değerler PLC'nin kalıcı belleğinde durur; sanal makine onları
    // bir .ini dosyasına yazar. Dosyada geçerli bir değer varsa açılışta o kullanılır.
    void setMemoryFile(const QString &path);

    bool isSimulation() const override { return true; }
    void startHoming() override;
    void stop() override;
    void startJog(Axis *axis, int direction, bool fast) override;
    void keepJogAlive(Axis *axis) override;
    void stopJog(Axis *axis) override;
    void moveTo(Axis *axis, double target) override;
    void startPump() override;
    void stopPump() override;
    void setActuator(Actuator *actuator, bool on) override;
    void startCycle(const QVariantList &recipe, double dieRadius, double tubeDiameter) override;
    void resetPartCount() override;
    bool setTooling(double dieRadius, double tubeDiameter, bool mandrel, bool feedDuringBend) override;
    bool clearTooling() override;

private:
    // Sanal makinenin her eksen için tuttuğu bilgiler.
    struct SimAxis
    {
        SimAxis() = default;
        SimAxis(Axis *axis, const AxisParameters &params)
            : axis(axis)
            , params(params)
        {
        }

        Axis *axis = nullptr;
        AxisParameters params {};
        int jogDirection = 0;       // -1: geri, +1: ileri, 0: jog yok
        bool jogFast = false;
        QDeadlineTimer jogDeadline; // bekçi: bu süre dolarsa jog durur
        bool positioning = false;   // "konuma git" sürüyor mu?
        double moveTarget = 0.0;    // gidilen hedef konum
        double moveSpeed = 0.0;     // bu hareketin hızı (0: eksenin kendi hızı)
        bool cycleMove = false;     // hareketi döngü mü başlattı? (kilitler elle kumanda içindir)
    };

    // Sanal makinenin her silindir için tuttuğu bilgiler.
    struct SimActuator
    {
        SimActuator() = default;
        SimActuator(Actuator *actuator, double travelSeconds)
            : actuator(actuator)
            , travelSeconds(travelSeconds)
        {
        }

        Actuator *actuator = nullptr;
        double travelSeconds = 1.0; // bir uçtan öbürüne gitme süresi
        double progress = 0.0;      // 0: bekleme konumu, 1: iş konumu
    };

    // Üretim döngüsünün aşamaları. Sıra: araba boru alma konumuna gider (büküm
    // kolu ve rotasyon da başa döner), boru takılır, malafa ileri çıkar, sonra
    // programın adımları işlenir; parça bitince malafa geri alınır ve pens açılır.
    enum class Phase {
        None,
        ToLoadPosition, // araba boru alma konumuna, büküm kolu ve rotasyon 0'a gider
        MandrelOut,     // malafa ileri
        Feed,           // İLERLE: araba boruyu iter
        ClampClose,     // mengene kapanır (büküm öncesi)
        ClampDwell,     // mengene kapalı bekler (ZAMANLAR: mengene kapanınca bekleme)
        Bend,           // büküm kolu açıya döner; araba yayı takip eder
        BendDwell,      // kol açıda bekler (ZAMANLAR: bükümde bekleme)
        ClampOpen,      // mengene açılır
        BendHome,       // büküm kolu 0'a döner
        Rotate,         // boru kendi ekseninde döner
        StepPause,      // adımlar arası kısa duraklama
        MandrelBack,    // malafa geri
        ColletOpen      // pens açılır: parça biter, operatör parçayı alır
    };

    // Makineye gönderilen tarifin bir adımı (BendProgram::Command ile aynı sırada).
    struct RecipeStep
    {
        int command = 0;
        double value = 0.0;
    };

    void defineTimers();                            // ZAMANLAR'daki süreleri tanımla
    double timer(const QString &key) const;         // bir sürenin şu anki değeri (sn)
    void remember(const QString &key, double value); // değişen değeri belleğe yaz

    void tick();                     // döngünün bir turu
    void updatePump(double dt);      // basıncı dt saniye ilerlet
    void updateActuators(double dt); // silindirleri dt saniye ilerlet
    void updateInterlocks();         // kilit kurallarını uygula
    void updateStartBlock();         // döngü başlatılabilir mi?
    void updateHoming(double dt);    // referans aramayı dt saniye ilerlet
    void updateMotion(double dt);    // jog ve konuma gitmeyi dt saniye ilerlet
    void updateCycle(double dt);     // üretim döngüsünü dt saniye ilerlet

    void beginPhase(Phase phase);            // aşamayı başlat (komutları ver)
    void beginStep();                        // sıradaki program adımını başlat
    void stepFinished();                     // adım bitti: devam et ya da bekle
    void waitForOperator(WaitReason reason); // START beklenecek
    void abortCycle(CycleFault fault);       // döngüyü kes
    void followBend();                       // büküm sırasında arabayı yaya göre sür
    bool startMove(SimAxis &sim, double target, double speed = 0.0);
    bool axisIdle(const SimAxis &sim) const;
    bool actuatorAt(const Actuator *actuator, bool on) const;
    double recipeTravel() const; // tarifin gerektirdiği toplam araba yolu (açınım boyu)

    SimAxis *simAxis(Axis *axis);       // bir Axis'e ait kaydı bul
    SimActuator *simActuator(Actuator *actuator);
    void haltMotion(SimAxis &sim);      // eksenin elle hareketini (jog, konumlama) durdur
    void haltAllMotion();
    void updateLimitState(SimAxis &sim);

    QTimer m_timer;                            // döngüyü tetikleyen saat
    QElapsedTimer m_clock;                     // iki tur arasında geçen gerçek süre
    std::array<SimAxis, 4> m_axes;             // X, B, A, Y
    std::array<SimAxis *, 4> m_homingOrder {}; // referans arama sırası
    int m_homingIndex = -1;                    // şu an referans arayan eksenin sırası (-1: yok)
    double m_latchTime = 0.0;                  // referans noktasında geçen bekleme süresi (sn)
    bool m_pumpCommand = false;                // mühürlü pompa komutu: START ile açılır, STOP ile kapanır
    std::array<SimActuator, 3> m_actuators;    // mengene, malafa, pens

    QList<RecipeStep> m_recipe;        // makineye gönderilen program adımları
    double m_dieRadius = 0.0;          // parçanın büküldüğü kalıbın yarıçapı (yay boyu için)
    Phase m_phase = Phase::None;       // döngünün şu anki aşaması
    Phase m_resumePhase = Phase::None; // START'tan sonra devam edilecek aşama
    double m_phaseTime = 0.0;          // aşamada geçen süre (zaman aşımı için)
    double m_phaseTimeout = 0.0;       // bu aşama en çok bu kadar sürebilir (0: sınırsız)
    int m_stepIndex = 0;               // işlenen program adımı
    double m_bendStartX = 0.0;         // büküm başlarken arabanın konumu
    double m_bendStartAngle = 0.0;     // büküm başlarken kolun açısı

    QString m_memoryFile;         // makinenin belleği (boşsa değerler saklanmaz)
    bool m_loadingMemory = false; // bellekten okunurken yeniden yazılmasın
};
