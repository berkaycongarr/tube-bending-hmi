#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

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

public:
    enum State {
        NotHomed, // Referanssız: eksenlerin gerçek konumu henüz bilinmiyor
        Homing,   // Referans aranıyor
        Ready     // Hazır: tüm eksenler referanslı
    };
    Q_ENUM(State)

    explicit IMachine(QObject *parent = nullptr)
        : QObject(parent)
        , m_axisX(new Axis(QStringLiteral("X"), false, this))
        , m_axisB(new Axis(QStringLiteral("B"), true, this))
        , m_axisA(new Axis(QStringLiteral("A"), true, this))
    {
    }

    State state() const { return m_state; }
    Axis *axisX() const { return m_axisX; }
    Axis *axisB() const { return m_axisB; }
    Axis *axisA() const { return m_axisA; }

    // Sanal makine mi? Ekranda "SİMÜLASYON" etiketi göstermek için.
    virtual bool isSimulation() const = 0;

    // Komutlar: ekrandaki butonlar bunları çağırır.
    Q_INVOKABLE virtual void startHoming() = 0; // Referans ara (HOME)
    Q_INVOKABLE virtual void stop() = 0;        // Tüm hareketleri durdur (STOP)

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

signals:
    void stateChanged();

protected:
    // Durumu yalnızca alt sınıflar değiştirebilir.
    void setState(State state)
    {
        if (m_state == state)
            return;
        m_state = state;
        emit stateChanged();
    }

private:
    State m_state = NotHomed;
    Axis *const m_axisX;
    Axis *const m_axisB;
    Axis *const m_axisA;
};
