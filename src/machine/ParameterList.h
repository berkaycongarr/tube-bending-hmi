#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Makinenin ayarlanabilir değerleri: süreler (ZAMANLAR), konumlar, limitler ve hızlar
// (AYARLAR). Gerçek makinede bu değerler PLC'nin belleğinde durur; ekran okur ve
// yazar. Her değerin bir anahtarı, başlığı, açıklaması, birimi, varsayılanı ve
// alabileceği aralık vardır.
//
// Liste, QML'de doğrudan bir ListView'e verilebilir. Değer değişince ListView ve
// valueChanged sinyali bunu hemen öğrenir; makine de bu sinyalle değeri kullanır
// ya da belleğine yazar. Liste dışında (ör. tablo hücresinde) gösterilen değerler
// revision'a bağlanır: herhangi bir değer ya da aralık değişince artar.
//
// Makine listeyi kilitleyebilir (ör. döngü sürerken eksen limitleri değişmesin):
// kilitliyken setValue reddedilir, lockReason nedenini söyler.
class ParameterList : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Parametreler makine tarafında oluşturulur.")

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
    Q_PROPERTY(bool locked READ isLocked NOTIFY lockedChanged)
    Q_PROPERTY(QString lockReason READ lockReason NOTIFY lockedChanged)

public:
    // ListView'deki her satırın QML'e verdiği bilgiler.
    enum Role {
        KeyRole = Qt::UserRole + 1, // "key": kısa, değişmez ad (dosyada da bu adla saklanır)
        TitleRole,                  // "title": ekranda görünen ad
        NoteRole,                   // "note": ne işe yaradığı
        UnitRole,                   // "unit": birim (ör. "s", "mm")
        ValueRole,                  // "value"
        DefaultValueRole,           // "defaultValue"
        MinimumRole,                // "minimum"
        MaximumRole,                // "maximum"
        DecimalsRole,               // "decimals": gösterilen ondalık basamak
        ModifiedRole                // "modified": varsayılandan farklı mı?
    };

    struct Parameter
    {
        QString key;
        QString title;
        QString note;
        QString unit;
        double defaultValue = 0.0;
        double minimum = 0.0;
        double maximum = 0.0;
        int decimals = 2;
        double value = 0.0; // add() varsayılanla başlatır
    };

    explicit ParameterList(QObject *parent = nullptr);

    // QAbstractListModel
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_parameters.size()); }
    int revision() const { return m_revision; }
    bool isLocked() const { return m_locked; }
    QString lockReason() const { return m_lockReason; }

    // Yeni değer tanımı (makine kurulurken). Değer varsayılanla başlar.
    void add(const Parameter &parameter);

    Q_INVOKABLE int indexOf(const QString &key) const;
    Q_INVOKABLE double value(const QString &key) const; // bilinmeyen anahtar: 0
    Q_INVOKABLE QVariantMap get(int row) const;         // satırın bütün bilgileri

    // Değeri değiştir. Sayı değilse, aralık dışındaysa ya da liste kilitliyse
    // reddedilir (false). Değer, gösterilen ondalık basamağa yuvarlanır.
    Q_INVOKABLE bool setValue(const QString &key, double value);
    Q_INVOKABLE bool reset(const QString &key); // varsayılana dön
    Q_INVOKABLE bool resetAll();                // hepsi varsayılana (kilitliyse false)

    // Makinenin kullandığı ayarlar: bir değerin alabileceği aralık başka değerlere bağlı
    // olabilir (ör. alt limit üst limitten küçük olmalı); makine aralığı günceller.
    void setRange(const QString &key, double minimum, double maximum);
    void setLocked(bool locked, const QString &reason = QString());

signals:
    void countChanged();
    void revisionChanged();
    void lockedChanged();
    void valueChanged(const QString &key, double value);

private:
    void bumpRevision();

    QList<Parameter> m_parameters;
    int m_revision = 0;
    bool m_locked = false;
    QString m_lockReason;
};
