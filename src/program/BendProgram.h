#pragma once

#include <QAbstractListModel>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

#include <array>

// Büküm programı (reçete): bir parçanın nasıl büküleceğini tarif eden komut listesi.
//
// Program ekranın verisidir, makinenin değil: ekran programı saklar, düzenler ve
// doğrular; üretimde adımları sırayla makineye gönderir. Bu yüzden IMachine'den
// ayrı duruyor ve gerçek makineye geçişte değişmeyecek.
//
// Biçim, müşterinin mevcut ekranındaki gibi komut listesidir: her satırda tek
// komut (İLERLE, BÜK ya da ROTASYON) ve onun değeri bulunur.
//
// QAbstractListModel'den türediği için QML'de doğrudan bir ListView'e verilebilir:
// liste değiştiğinde ekran kendiliğinden güncellenir.
class BendProgram : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Program C++ tarafında oluşturulur.")

    Q_PROPERTY(QString name READ name NOTIFY nameChanged)
    Q_PROPERTY(double tubeLength READ tubeLength WRITE setTubeLength NOTIFY tubeChanged)
    Q_PROPERTY(double tubeDiameter READ tubeDiameter WRITE setTubeDiameter NOTIFY tubeChanged)
    Q_PROPERTY(double dieRadius READ dieRadius WRITE setDieRadius NOTIFY tubeChanged)
    Q_PROPERTY(int count READ count NOTIFY summaryChanged)
    Q_PROPERTY(double developedLength READ developedLength NOTIFY summaryChanged)
    Q_PROPERTY(double remainingLength READ remainingLength NOTIFY summaryChanged)
    Q_PROPERTY(int invalidStepCount READ invalidStepCount NOTIFY summaryChanged)
    Q_PROPERTY(bool valid READ isValid NOTIFY summaryChanged)
    Q_PROPERTY(bool modified READ isModified NOTIFY modifiedChanged)

public:
    enum Command {
        Feed,  // İLERLE: boruyu ilerlet (mm)
        Bend,  // BÜK: büküm kolunu verilen açıya çevir (derece)
        Rotate // ROTASYON: boruyu kendi ekseninde döndür (derece)
    };
    Q_ENUM(Command)

    // ListView'deki her satırın QML'e verdiği bilgiler.
    enum Role {
        CommandRole = Qt::UserRole + 1, // "command"
        ValueRole,                      // "value"
        ValidRole                       // "valid": değer sınırlar içinde mi?
    };

    struct Step
    {
        Command command = Feed;
        double value = 0.0;
    };

    // Programın tüm içeriği: dosyadan okunan ya da dosyaya yazılan bilgi.
    struct Data
    {
        QString name;
        double tubeLength = 0.0;
        double tubeDiameter = 0.0;
        double dieRadius = 0.0;
        QList<Step> steps;
    };

    explicit BendProgram(QObject *parent = nullptr);

    // QAbstractListModel: ListView bu üç fonksiyonla satırları okur.
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString name() const { return m_name; }
    void setName(const QString &name);

    double tubeLength() const { return m_tubeLength; }     // boru boyu (mm)
    double tubeDiameter() const { return m_tubeDiameter; } // boru çapı (mm)
    double dieRadius() const { return m_dieRadius; }       // kalıp yarıçapı, boru ekseninde (mm)
    void setTubeLength(double length);
    void setTubeDiameter(double diameter);
    void setDieRadius(double radius);

    int count() const { return int(m_steps.size()); }
    Step step(int row) const { return m_steps.at(row); }

    // Açınım boyu: programın ihtiyaç duyduğu boru boyu.
    // Düz parçaların (İLERLE) toplamı + büküm yaylarının toplamı (kalıp yarıçapı × açı).
    double developedLength() const;
    double remainingLength() const { return m_tubeLength - developedLength(); } // < 0 ise boru kısa
    int invalidStepCount() const;
    bool isValid() const;

    // Üretimde makineye gönderilen tarif: her adım { "command": 0/1/2, "value": sayı }.
    // Makine BendProgram'ı tanımaz; ekranın verisi burada makinenin anlayacağı
    // sade bir listeye çevrilir. Gerçek makinede bu liste PLC'ye yazılacak.
    Q_INVOKABLE QVariantList recipe() const;

    // Program son kayıttan (ya da açılıştan) beri değişti mi? Kaydedilince sıfırlanır.
    bool isModified() const { return m_modified; }
    void setModified(bool modified);

    // Bir komutun alabileceği değer aralığı. Makinenin eksen limitlerinden gelir
    // (main.cpp bağlar); böylece program, makinenin yapamayacağı bir adım içeremez.
    void setStepLimits(Command command, double minimum, double maximum);
    Q_INVOKABLE double minimumValue(Command command) const;
    Q_INVOKABLE double maximumValue(Command command) const;

    // Düzenleme komutları. Sınır dışı değer ya da geçersiz satır reddedilir (false).
    Q_INVOKABLE bool insertStep(int row, Command command, double value);
    Q_INVOKABLE bool setValue(int row, double value);
    Q_INVOKABLE bool removeStep(int row);
    Q_INVOKABLE bool moveStep(int from, int to);

    // Dosya biçimi (JSON). Okurken her şey denetlenir; bir sorun varsa false döner,
    // error nedenini söyler. Makine limitini aşan değerler kabul edilir: program
    // sessizce değiştirilmez, ekranda kırmızı görünür.
    QJsonObject toJson() const;
    static bool fromJson(const QJsonObject &json, Data &data, QString &error);

    // Programın tüm içeriğini değiştir (dosyadan açınca). Değişti bayrağı sıfırlanır.
    void setData(const Data &data);

    // Boş yeni program. Boru ve kalıp bilgileri kalır: takılı kalıp aynıdır.
    void clear(const QString &name);

    // Örnek program: müşterinin ekranındaki "Ortaokul Oturak (2026)".
    void loadExample();

signals:
    void nameChanged();
    void tubeChanged();
    void summaryChanged(); // adım sayısı, açınım boyu, artan boy, geçerlilik
    void modifiedChanged();

private:
    bool inRange(Command command, double value) const;

    QString m_name;
    double m_tubeLength = 0.0;
    double m_tubeDiameter = 0.0;
    double m_dieRadius = 0.0;
    QList<Step> m_steps;
    bool m_modified = false;
    std::array<double, 3> m_minimum { 0.0, 0.0, 0.0 }; // komut başına alt sınır
    std::array<double, 3> m_maximum { 0.0, 0.0, 0.0 }; // komut başına üst sınır
};
