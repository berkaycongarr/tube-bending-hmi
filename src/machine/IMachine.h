#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

#include "Actuator.h"
#include "Axis.h"

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

    explicit IMachine(QObject *parent = nullptr)
        : QObject(parent)
        , m_axisX(new Axis(QStringLiteral("X"), false, this))
        , m_axisB(new Axis(QStringLiteral("B"), true, this))
        , m_axisA(new Axis(QStringLiteral("A"), true, this))
        , m_axisY(new Axis(QStringLiteral("Y"), false, this))
        , m_clamp(new Actuator(this))
        , m_mandrel(new Actuator(this))
        , m_collet(new Actuator(this))
    {
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

    // Sanal makine mi? Ekranda "SİMÜLASYON" etiketi göstermek için.
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

signals:
    void stateChanged();
    void pumpStateChanged();
    void pressureChanged();

protected:
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

private:
    State m_state = NotHomed;
    PumpState m_pumpState = PumpStopped;
    double m_pressure = 0.0;
    Axis *const m_axisX;
    Axis *const m_axisB;
    Axis *const m_axisA;
    Axis *const m_axisY;
    Actuator *const m_clamp;
    Actuator *const m_mandrel;
    Actuator *const m_collet;
};
