#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// Makinenin bir ekseni. Bu makinede üç eksen var:
//   X: ilerletme  - boruyu ileri sürer (mm)
//   B: büküm      - büküm kolunu çevirir (derece)
//   A: rotasyon   - boruyu kendi ekseni etrafında döndürür (derece)
//
// Axis yalnızca durumu tutar: konum, referans arıyor mu, referansı bulundu mu.
// Ekseni hareket ettiren makinedir (demoda SimMachine, gerçekte PLC).
class Axis : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Eksenler C++ tarafında oluşturulur.")

    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(bool rotary READ isRotary CONSTANT)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(bool homing READ isHoming NOTIFY homingChanged)
    Q_PROPERTY(bool homed READ isHomed NOTIFY homedChanged)

public:
    Axis(const QString &name, bool rotary, QObject *parent = nullptr)
        : QObject(parent)
        , m_name(name)
        , m_rotary(rotary)
    {
    }

    QString name() const { return m_name; }
    bool isRotary() const { return m_rotary; }      // true: derece, false: mm
    double position() const { return m_position; }  // anlık konum
    bool isHoming() const { return m_homing; }      // şu an referans arıyor mu?
    bool isHomed() const { return m_homed; }        // referansı bulundu mu?

    // Aşağıdaki fonksiyonlar QML'den çağrılamaz; yalnızca makine sınıfları kullanır.
    // Değer gerçekten değiştiyse sinyal yayılır; ekran da sadece o zaman güncellenir.
    void setPosition(double position)
    {
        if (m_position == position)
            return;
        m_position = position;
        emit positionChanged();
    }

    void setHoming(bool homing)
    {
        if (m_homing == homing)
            return;
        m_homing = homing;
        emit homingChanged();
    }

    void setHomed(bool homed)
    {
        if (m_homed == homed)
            return;
        m_homed = homed;
        emit homedChanged();
    }

signals:
    void positionChanged();
    void homingChanged();
    void homedChanged();

private:
    const QString m_name;
    const bool m_rotary;
    double m_position = 0.0;
    bool m_homing = false;
    bool m_homed = false;
};
