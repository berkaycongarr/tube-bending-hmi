#pragma once

#include <QElapsedTimer>
#include <QList>
#include <QTimer>

#include "IMachine.h"

// Demo için sanal makine.
//
// Gerçek makinede eksenleri PLC hareket ettirir. SimMachine bir "sanal PLC"
// gibi davranır: PLC'lerin tarama döngüsü (scan cycle) gibi sabit aralıklarla
// dönen bir döngüde eksenleri hareket ettirir ve durumu günceller.
class SimMachine : public IMachine
{
    Q_OBJECT

public:
    explicit SimMachine(QObject *parent = nullptr);

    bool isSimulation() const override { return true; }
    void startHoming() override;
    void stop() override;

private:
    void tick();                  // döngünün bir turu
    void updateHoming(double dt); // referans aramayı dt saniye ilerlet

    QTimer m_timer;               // döngüyü tetikleyen saat
    QElapsedTimer m_clock;        // iki tur arasında geçen gerçek süre
    QList<Axis *> m_homingOrder;  // referans arama sırası
    int m_homingIndex = -1;       // şu an referans arayan eksenin sırası (-1: yok)
    double m_latchTime = 0.0;     // referans noktasında geçen bekleme süresi (sn)
};
