#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QList>
#include <QString>
#include <QtQml/qqmlregistration.h>

// Makinenin arızaları: duranlar ve geçmiş, tek listede (en yenisi başta).
//
// Bir arıza oluşunca makine onu listeye koyar. Arıza mühürlenir: sebebi geçse bile
// kendiliğinden silinmez, operatör RESET'e basar. Sebebi süren bir arıza (ör. acil stop
// basılı) silinmez; önce sebep giderilmelidir. Sanayideki kural budur: sebep dururken
// arızayı silmek, sonraki arızaların görülmesini engeller ("arıza maskeleme").
//
// Bir arızanın durumu:
//   Active  sebebi sürüyor, silinemez
//   Latched sebebi geçti, RESET bekliyor
//   Cleared silindi; kaydı geçmişte kalır
//
// RESET hiçbir şeyi hareket ettirmez, hiçbir şey başlatmaz: yalnızca arızayı siler.
// Yeniden başlatmak ayrı ve bilinçli bir komuttur (BAŞLAT).
class AlarmList : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Arıza listesi makine tarafından oluşturulur.")

    Q_PROPERTY(int count READ count NOTIFY changed)
    Q_PROPERTY(int unresolved READ unresolved NOTIFY changed)

public:
    enum State {
        Active,  // sebebi sürüyor
        Latched, // sebebi geçti, RESET bekliyor
        Cleared  // silindi (geçmiş)
    };
    Q_ENUM(State)

    // ListView'deki her satırın QML'e verdiği bilgiler.
    enum Role {
        CodeRole = Qt::UserRole + 1, // "code": kısa, değişmez ad (ör. "basincKesildi")
        TitleRole,                   // "title": ne oldu (ör. "MENGENE KAPANMADI")
        DetailRole,                  // "detail": nedeni ve nereye bakılacağı
        TimeRole,                    // "time": oluştuğu an
        ClearedTimeRole,             // "clearedTime": silindiği an (silinmemişse geçersiz)
        StateRole                    // "alarmState": Active / Latched / Cleared
    };

    struct Alarm
    {
        QString code;
        QString title;
        QString detail;
        QDateTime time;
        QDateTime clearedTime;
        State state = Latched;
    };

    explicit AlarmList(QObject *parent = nullptr);

    // QAbstractListModel
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_alarms.size()); }
    int unresolved() const;                 // silinmemiş (Active + Latched) arıza sayısı
    bool hasUnresolved() const { return unresolved() > 0; }
    bool canReset() const;                  // RESET şu an bir şey siler mi? (Latched var mı)
    const Alarm *newest() const;            // silinmemişlerin en yenisi (yoksa nullptr)

    // Makine tarafı ------------------------------------------------------------
    // Yeni arıza. persistent: sebebi sürüyor (silinmeden önce geçmesi gerekir).
    // Aynı arıza zaten duruyorsa ikinci kez eklenmez.
    void raise(const QString &code, const QString &title, const QString &detail,
               bool persistent = false);

    // Süren bir arızanın sebebi geçti ya da yeniden oluştu.
    void setCondition(const QString &code, bool present);

    // RESET: sebebi geçmiş arızaları siler, kaç tanesini sildiğini döner.
    int reset();

signals:
    void changed();

private:
    int indexOfUnresolved(const QString &code) const;
    void trim(); // geçmişte en çok MaximumAlarms kayıt tutulur

    static constexpr int MaximumAlarms = 200;

    QList<Alarm> m_alarms; // en yenisi başta
};
