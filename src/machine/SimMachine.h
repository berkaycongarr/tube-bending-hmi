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

    void tick();                        // döngünün bir turu
    void updatePump(double dt);         // basıncı dt saniye ilerlet
    void updateActuators(double dt);    // silindirleri dt saniye ilerlet
    void updateInterlocks();            // kilit kurallarını uygula
    void updateHoming(double dt);       // referans aramayı dt saniye ilerlet
    void updateManualMotion(double dt); // jog ve konuma gitmeyi dt saniye ilerlet

    SimAxis *simAxis(Axis *axis);       // bir Axis'e ait kaydı bul
    SimActuator *simActuator(Actuator *actuator);
    void haltMotion(SimAxis &sim);      // eksenin elle hareketini (jog, konumlama) durdur
    void haltAllMotion();
    void updateLimitState(SimAxis &sim);

    QTimer m_timer;                            // döngüyü tetikleyen saat
    QElapsedTimer m_clock;                     // iki tur arasında geçen gerçek süre
    std::array<SimAxis, 3> m_axes;             // X, B, A
    std::array<SimAxis *, 3> m_homingOrder {}; // referans arama sırası
    int m_homingIndex = -1;                    // şu an referans arayan eksenin sırası (-1: yok)
    double m_latchTime = 0.0;                  // referans noktasında geçen bekleme süresi (sn)
    bool m_pumpCommand = false;                // mühürlü pompa komutu: START ile açılır, STOP ile kapanır
    std::array<SimActuator, 3> m_actuators;    // mengene, malafa, pens
};
