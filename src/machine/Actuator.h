#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

// Bir hidrolik silindir: mengene, malafa ya da pens.
//
// Gerçek makinede silindiri bir valf sürer (komut); silindirin iki uç konumunu
// iki sensör bildirir (geri bildirim). Ekran komutu değil, sensörlerin söylediğini
// gösterir: "kapat" komutu verildiğinde silindir yolunu bitirene kadar durum
// "hareket ediyor"dur.
//
// Actuator yalnızca durumu tutar; silindiri hareket ettiren ve bu değerleri
// güncelleyen makinedir (demoda SimMachine, gerçekte PLC).
class Actuator : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Silindirler C++ tarafında oluşturulur.")

    Q_PROPERTY(bool command READ command NOTIFY commandChanged)
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(Interlock interlock READ interlock NOTIFY interlockChanged)

public:
    // Sensörlerin bildirdiği durum. "On", silindirin iş konumudur:
    // mengene ve pens için kapalı, malafa için ileride.
    enum State {
        Off,       // bekleme konumunda (açık / geride)
        TurningOn, // iş konumuna gidiyor
        On,        // iş konumunda (kapalı / ileride)
        TurningOff // bekleme konumuna dönüyor
    };
    Q_ENUM(State)

    // Kumanda neden kilitli?
    enum Interlock {
        NoInterlock, // kilit yok, kumanda edilebilir
        PumpOff,     // pompa çalışmıyor: basınç yok
        AxesMoving,  // eksenler hareket ediyor (yalnızca mengene için)
        CycleRunning // üretim döngüsü çalışıyor: silindirleri makine sürüyor
    };
    Q_ENUM(Interlock)

    explicit Actuator(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    bool command() const { return m_command; }          // valf komutu: true = iş konumuna git
    State state() const { return m_state; }             // sensörlere göre durum
    Interlock interlock() const { return m_interlock; } // kilit nedeni

    // Aşağıdaki fonksiyonlar QML'den çağrılamaz; yalnızca makine sınıfları kullanır.
    void setCommand(bool command)
    {
        if (m_command == command)
            return;
        m_command = command;
        emit commandChanged();
    }

    void setState(State state)
    {
        if (m_state == state)
            return;
        m_state = state;
        emit stateChanged();
    }

    void setInterlock(Interlock interlock)
    {
        if (m_interlock == interlock)
            return;
        m_interlock = interlock;
        emit interlockChanged();
    }

signals:
    void commandChanged();
    void stateChanged();
    void interlockChanged();

private:
    bool m_command = false;
    State m_state = Off;
    Interlock m_interlock = NoInterlock;
};
