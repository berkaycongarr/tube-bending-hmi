#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QtQml/qqmlregistration.h>

// Makinenin girişleri ya da çıkışları (IO TEST sayfası).
//
// Giriş, makineye gelen bir sinyaldir: bir sensör ya da şalter ("mengene kapalı",
// "basınç var"). Çıkış, makinenin verdiği bir komuttur: pompa motoru, valf bobini.
// Her noktanın PLC'deki adresi (ör. I0.2, Q0.1), adı ve o anki durumu (1 ya da 0) vardır.
//
// Çıkışlar için makine bir de kilit nedeni yazar: çıkış şu an elle sürülemiyorsa neden
// sürülemediği (ör. "Basınç yok"); boşsa sürülebilir. Girişlerin kilidi yoktur: girişi
// makine değil, sensör belirler.
//
// Liste QML'de doğrudan bir ListView'e verilir; bir durum değişince yalnızca o satır
// yenilenir. Durumları makine yazar (demoda SimMachine her turda; gerçek makinede PLC'den
// okunarak).
class IoList : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Giriş ve çıkış listeleri makine tarafında oluşturulur.")

    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    // ListView'deki her satırın QML'e verdiği bilgiler.
    enum Role {
        AddressRole = Qt::UserRole + 1, // "address": PLC'deki adresi, ör. "I0.2"
        NameRole,                       // "name": ekranda görünen adı
        NoteRole,                       // "note": 1 ve 0'ın ne demek olduğu (çıkışlarda)
        ActiveRole,                     // "active": sinyal var mı (1)?
        LockRole                        // "lock": çıkış neden sürülemiyor (boş: sürülebilir)
    };

    explicit IoList(QObject *parent = nullptr);

    // QAbstractListModel
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_points.size()); }

    // Yeni nokta (makine kurulurken). Durumu 0, kilidi boş başlar.
    void add(const QString &address, const QString &name, const QString &note = QString());

    Q_INVOKABLE int indexOf(const QString &address) const;    // bilinmeyen adres: -1
    Q_INVOKABLE bool isActive(const QString &address) const; // bilinmeyen adres: false
    Q_INVOKABLE QString lock(const QString &address) const;

    // Makinenin yazdığı değerler (QML'den çağrılamaz). Değişmediyse bir şey olmaz.
    void setActive(const QString &address, bool active);
    void setLock(const QString &address, const QString &lock);

signals:
    void countChanged();

private:
    struct Point
    {
        QString address;
        QString name;
        QString note;
        bool active = false;
        QString lock;
    };

    QList<Point> m_points;
};
