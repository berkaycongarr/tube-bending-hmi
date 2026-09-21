#pragma once

#include <QAbstractListModel>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Kalıp kütüphanesi: makinede kullanılabilen büküm kalıpları ve şu an takılı olanı.
//
// Kalıp makinenin donanımıdır: bir parçanın hangi yarıçapla büküleceğini takılı
// kalıp belirler. Müşterinin ekranında "AKTİF KALIP" olarak görünen bilgiler
// (açıklama, kalıp yarıçapı, malafalı büküm, bükümde ilerle) burada tutulur.
//
// Kalıplar tek bir dosyada (kaliplar.json) saklanır: sayıları azdır ve hepsi birlikte
// makinenin donanım listesidir. Hangi kalıbın takılı olduğu ise bu makinenin
// durumudur; onu main.cpp ayar dosyasında hatırlar (liste başka makineye
// kopyalanırsa "takılı" bilgisi taşınmasın diye).
//
// Kütüphane ekranın verisidir (program gibi): makineye geçişte değişmez.
class DieLibrary : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Kalıp kütüphanesi C++ tarafında oluşturulur.")

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString file READ displayFile CONSTANT)
    Q_PROPERTY(int maxNameLength READ maxNameLength CONSTANT)
    Q_PROPERTY(double minRadius READ minRadius CONSTANT)
    Q_PROPERTY(double maxRadius READ maxRadius CONSTANT)
    Q_PROPERTY(double minDiameter READ minDiameter CONSTANT)
    Q_PROPERTY(double maxDiameter READ maxDiameter CONSTANT)
    Q_PROPERTY(QString loadWarning READ loadWarning CONSTANT)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(bool hasActive READ hasActive NOTIFY activeChanged)
    Q_PROPERTY(QString activeName READ activeName NOTIFY activeChanged)
    Q_PROPERTY(double activeRadius READ activeRadius NOTIFY activeChanged)
    Q_PROPERTY(double activeTubeDiameter READ activeTubeDiameter NOTIFY activeChanged)
    Q_PROPERTY(bool activeMandrel READ activeMandrel NOTIFY activeChanged)
    Q_PROPERTY(bool activeFeedDuringBend READ activeFeedDuringBend NOTIFY activeChanged)

public:
    // Listedeki her satırın QML'e verdiği bilgiler.
    enum Role {
        NameRole = Qt::UserRole + 1, // "name": açıklama (ör. 25X50XR116), kalıbın kimliği
        RadiusRole,                  // "dieRadius": kalıp yarıçapı, boru ekseninde (mm);
                                     // "radius" değil: QML'de Rectangle'ın köşe yarıçapıyla karışır
        TubeDiameterRole,            // "tubeDiameter": kalıbın aldığı boru çapı (mm)
        MandrelRole,                 // "mandrel": malafalı büküm
        FeedDuringBendRole,          // "feedDuringBend": bükümde ilerle
        ActiveRole                   // "active": makineye takılı kalıp bu mu?
    };

    struct Die
    {
        QString name;
        double radius = 0.0;
        double tubeDiameter = 0.0;
        bool mandrel = false;
        bool feedDuringBend = false;
    };

    // Sınırlar TASARIM sayfasındaki boru ve kalıp alanlarıyla aynı.
    static constexpr int MaxNameLength = 40;
    static constexpr double MinRadius = 5.0;
    static constexpr double MaxRadius = 500.0;
    static constexpr double MinDiameter = 4.0;
    static constexpr double MaxDiameter = 120.0;

    // Dosya yoksa örnek kalıpla oluşturulur; bozuksa yedeklenir ve liste boş başlar.
    explicit DieLibrary(const QString &filePath, QObject *parent = nullptr);

    // QAbstractListModel
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_dies.size()); }
    QString filePath() const { return m_path; }
    QString displayFile() const; // ekranda gösterilecek yazılış (Windows'ta ters bölü)
    int maxNameLength() const { return MaxNameLength; }
    double minRadius() const { return MinRadius; }
    double maxRadius() const { return MaxRadius; }
    double minDiameter() const { return MinDiameter; }
    double maxDiameter() const { return MaxDiameter; }
    QString loadWarning() const { return m_loadWarning; } // açılışta dosyada sorun varsa
    QString lastError() const { return m_lastError; }     // son başarısız işlemin nedeni

    // Takılı kalıp (yoksa hasActive false, değerler 0)
    bool hasActive() const { return activeRow() >= 0; }
    QString activeName() const { return m_activeName; }
    double activeRadius() const;
    double activeTubeDiameter() const;
    bool activeMandrel() const;
    bool activeFeedDuringBend() const;

    Die die(int row) const { return m_dies.at(row); }

    // Ad kullanılabilir mi? Boş yazı: evet; değilse nedeni. ignoreRow: düzenlenen kalıbın
    // kendi satırı (kendi adıyla çakışmış sayılmaz).
    Q_INVOKABLE QString nameError(const QString &name, int ignoreRow = -1) const;
    Q_INVOKABLE int indexOf(const QString &name) const; // yoksa -1
    Q_INVOKABLE QVariantMap get(int row) const;         // düzenleme penceresi için

    // Değişiklikler hemen dosyaya yazılır. Dosyaya yazılamazsa liste de değişmez
    // (false döner, lastError nedenini söyler).
    Q_INVOKABLE bool add(const QString &name, double radius, double tubeDiameter, bool mandrel,
                         bool feedDuringBend);
    Q_INVOKABLE bool update(int row, const QString &name, double radius, double tubeDiameter,
                            bool mandrel, bool feedDuringBend);
    Q_INVOKABLE bool remove(int row); // takılı kalıp silinemez

    // Makineye takılı kalıbı işaretle (dosyaya yazılmaz; main.cpp ayarlarda hatırlar).
    Q_INVOKABLE bool setActive(int row);
    bool setActiveName(const QString &name); // açılışta: ayarlardaki ad

    // Dosya biçimi (JSON). Okurken her şey denetlenir; sorun varsa false ve nedeni.
    static QJsonObject toJson(const QList<Die> &dies);
    static bool fromJson(const QJsonObject &json, QList<Die> &dies, QString &error);

signals:
    void countChanged();
    void activeChanged(); // takılı kalıp değişti ya da takılı kalıbın bilgileri düzeltildi
    void lastErrorChanged();

private:
    int activeRow() const;
    QString valueError(double radius, double tubeDiameter) const;
    bool apply(QList<Die> dies, const QString &activeName, const QString &failMessage);
    bool write(const QList<Die> &dies, QString &error) const;
    void load();
    void setLastError(const QString &error);

    QString m_path;
    QList<Die> m_dies;
    QString m_activeName;
    QString m_loadWarning;
    QString m_lastError;
};
