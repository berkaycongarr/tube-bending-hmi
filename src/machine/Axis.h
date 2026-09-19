#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// Makinenin bir ekseni. Bu makinede üç eksen var:
//   X: ilerletme  - boruyu ileri sürer (mm)
//   B: büküm      - büküm kolunu çevirir (derece)
//   A: rotasyon   - boruyu kendi ekseni etrafında döndürür (derece)
//
// Axis yalnızca durumu ve parametreleri tutar: konum, hareket ediyor mu,
// referans durumu, limitler, hızlar. Ekseni hareket ettiren ve bu değerleri
// güncelleyen makinedir (demoda SimMachine, gerçekte PLC).
class Axis : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Eksenler C++ tarafında oluşturulur.")

    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(bool rotary READ isRotary CONSTANT)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(bool moving READ isMoving NOTIFY movingChanged)
    Q_PROPERTY(bool homing READ isHoming NOTIFY homingChanged)
    Q_PROPERTY(bool homed READ isHomed NOTIFY homedChanged)
    Q_PROPERTY(double minPosition READ minPosition NOTIFY parametersChanged)
    Q_PROPERTY(double maxPosition READ maxPosition NOTIFY parametersChanged)
    Q_PROPERTY(double homePosition READ homePosition NOTIFY parametersChanged)
    Q_PROPERTY(double jogSpeedSlow READ jogSpeedSlow NOTIFY parametersChanged)
    Q_PROPERTY(double jogSpeedFast READ jogSpeedFast NOTIFY parametersChanged)
    Q_PROPERTY(bool atMinLimit READ atMinLimit NOTIFY limitStateChanged)
    Q_PROPERTY(bool atMaxLimit READ atMaxLimit NOTIFY limitStateChanged)

public:
    Axis(const QString &name, bool rotary, QObject *parent = nullptr)
        : QObject(parent)
        , m_name(name)
        , m_rotary(rotary)
    {
    }

    QString name() const { return m_name; }
    bool isRotary() const { return m_rotary; }          // true: derece, false: mm
    double position() const { return m_position; }      // anlık konum
    bool isMoving() const { return m_moving; }          // şu an hareket ediyor mu?
    bool isHoming() const { return m_homing; }          // şu an referans arıyor mu?
    bool isHomed() const { return m_homed; }            // referansı bulundu mu?
    double minPosition() const { return m_minPosition; }   // yazılım limiti, alt
    double maxPosition() const { return m_maxPosition; }   // yazılım limiti, üst
    double homePosition() const { return m_homePosition; } // referansta yazılan değer
    double jogSpeedSlow() const { return m_jogSpeedSlow; } // jog hızı, yavaş (birim/sn)
    double jogSpeedFast() const { return m_jogSpeedFast; } // jog hızı, hızlı (birim/sn)
    bool atMinLimit() const { return m_atMinLimit; }       // alt limite dayandı mı?
    bool atMaxLimit() const { return m_atMaxLimit; }       // üst limite dayandı mı?

    // Aşağıdaki fonksiyonlar QML'den çağrılamaz; yalnızca makine sınıfları kullanır.
    // Değer gerçekten değiştiyse sinyal yayılır; ekran da sadece o zaman güncellenir.
    void setPosition(double position)
    {
        if (m_position == position)
            return;
        m_position = position;
        emit positionChanged();
    }

    void setMoving(bool moving)
    {
        if (m_moving == moving)
            return;
        m_moving = moving;
        emit movingChanged();
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

    void setLimits(double minPosition, double maxPosition)
    {
        if (m_minPosition == minPosition && m_maxPosition == maxPosition)
            return;
        m_minPosition = minPosition;
        m_maxPosition = maxPosition;
        emit parametersChanged();
    }

    void setHomePosition(double homePosition)
    {
        if (m_homePosition == homePosition)
            return;
        m_homePosition = homePosition;
        emit parametersChanged();
    }

    void setJogSpeeds(double slow, double fast)
    {
        if (m_jogSpeedSlow == slow && m_jogSpeedFast == fast)
            return;
        m_jogSpeedSlow = slow;
        m_jogSpeedFast = fast;
        emit parametersChanged();
    }

    void setLimitState(bool atMinLimit, bool atMaxLimit)
    {
        if (m_atMinLimit == atMinLimit && m_atMaxLimit == atMaxLimit)
            return;
        m_atMinLimit = atMinLimit;
        m_atMaxLimit = atMaxLimit;
        emit limitStateChanged();
    }

signals:
    void positionChanged();
    void movingChanged();
    void homingChanged();
    void homedChanged();
    void parametersChanged();
    void limitStateChanged();

private:
    const QString m_name;
    const bool m_rotary;
    double m_position = 0.0;
    bool m_moving = false;
    bool m_homing = false;
    bool m_homed = false;
    double m_minPosition = 0.0;
    double m_maxPosition = 0.0;
    double m_homePosition = 0.0;
    double m_jogSpeedSlow = 0.0;
    double m_jogSpeedFast = 0.0;
    bool m_atMinLimit = false;
    bool m_atMaxLimit = false;
};
