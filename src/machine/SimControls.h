#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class SimMachine;

// Sanal makinenin arıza denemesi kumandası: YALNIZCA DEMO İÇİNDİR.
//
// Gerçek makinede arızayı makinenin kendisi üretir; orada bu sınıfın karşılığı yoktur:
// main.cpp ekrana boş (null) verir, ekran da "sanal makine" panelini hiç göstermez.
// Makine sözleşmesi (IMachine) bu yüzden temiz kalır: ekran, makineden arıza uydurmasını
// isteyemez; yalnızca sanal makinenin kendi kumandası bunu yapar.
//
// Demoda üç deneme var: acil stop, hat kaçağı (basınç kaybı) ve sensör arızası. Böylece
// arıza yönetimi (alarm şeridi, RESET, arıza geçmişi, IO TEST'te teşhis) canlı gösterilir.
class SimControls : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Sanal makine kumandası C++ tarafında oluşturulur.")

    Q_PROPERTY(bool emergencyStop READ isEmergencyStop NOTIFY changed)
    Q_PROPERTY(bool pressureLoss READ isPressureLoss NOTIFY changed)
    Q_PROPERTY(bool sensorFault READ hasSensorFault NOTIFY changed)
    Q_PROPERTY(QString sensorLabel READ sensorLabel CONSTANT)

public:
    explicit SimControls(SimMachine *machine, QObject *parent = nullptr);

    bool isEmergencyStop() const;
    bool isPressureLoss() const;
    bool hasSensorFault() const;
    QString sensorLabel() const; // bozulacak sensörün adı (ör. "I0.2 MENGENE KAPALI")

    Q_INVOKABLE void pressEmergencyStop(bool pressed);
    Q_INVOKABLE void setPressureLoss(bool active);
    Q_INVOKABLE void setSensorFault(bool faulty);

signals:
    void changed();

private:
    SimMachine *const m_machine;
};
