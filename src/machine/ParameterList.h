#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Makinenin ayarlanabilir değerleri: süreler (ZAMANLAR), ileride konumlar ve hızlar
// (AYARLAR). Gerçek makinede bu değerler PLC'nin belleğinde durur; ekran okur ve
// yazar. Her değerin bir anahtarı, başlığı, açıklaması, birimi, varsayılanı ve
// alabileceği aralık vardır.
//
// Liste, QML'de doğrudan bir ListView'e verilebilir. Değer değişince ListView ve
// valueChanged sinyali bunu hemen öğrenir; makine de bu sinyalle değeri kullanır
// ya da belleğine yazar.
class ParameterList : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Parametreler makine tarafında oluşturulur.")

    Q_PROPERTY(int count READ count NOTIFY countChanged)

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

    // Yeni değer tanımı (makine kurulurken). Değer varsayılanla başlar.
    void add(const Parameter &parameter);

    Q_INVOKABLE int indexOf(const QString &key) const;
    Q_INVOKABLE double value(const QString &key) const; // bilinmeyen anahtar: 0
    Q_INVOKABLE QVariantMap get(int row) const;         // satırın bütün bilgileri

    // Değeri değiştir. Sayı değilse ya da aralık dışındaysa reddedilir (false).
    // Değer, gösterilen ondalık basamağa yuvarlanır.
    Q_INVOKABLE bool setValue(const QString &key, double value);
    Q_INVOKABLE bool reset(const QString &key); // varsayılana dön

signals:
    void countChanged();
    void valueChanged(const QString &key, double value);

private:
    QList<Parameter> m_parameters;
};
