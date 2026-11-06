#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QList>
#include <QString>
#include <QtQml/qqmlregistration.h>

class BendProgram;

// Program deposu: büküm programlarını bir klasörde, her birini ayrı bir .json
// dosyası olarak saklar. Dosyanın adı programın adıdır
// (ör. "Örnek U Parça.json"). Dosyalar kopyalanabilir, USB ile başka
// makineye taşınabilir, yedeklenebilir.
//
// Depo, ekrandaki tek programla (açık program) çalışır: onu dosyadan açar ve
// dosyaya kaydeder. Klasördeki programların listesi QML'e model olarak verilir.
class ProgramStore : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Program deposu C++ tarafında oluşturulur.")

    Q_PROPERTY(QString folder READ displayFolder CONSTANT)
    Q_PROPERTY(int maxNameLength READ maxNameLength CONSTANT)
    Q_PROPERTY(QString currentName READ currentName NOTIFY currentNameChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    // Listedeki her satırın QML'e verdiği bilgiler.
    enum Role {
        NameRole = Qt::UserRole + 1, // "name": program adı (dosya adı, uzantısız)
        StepCountRole,               // "stepCount": adım sayısı (okunamıyorsa -1)
        SavedAtRole,                 // "savedAt": son kayıt zamanı
        ReadableRole,                // "readable": dosya açılabilir mi?
        CurrentRole                  // "current": ekranda açık olan program bu mu?
    };

    // Program adı en fazla bu kadar karakter olabilir.
    static constexpr int MaxNameLength = 60;

    ProgramStore(const QString &folder, BendProgram *program, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString folder() const { return m_folder; }
    QString displayFolder() const; // ekranda gösterilecek yazılış (Windows'ta ters bölü)
    int maxNameLength() const { return MaxNameLength; }
    QString currentName() const { return m_currentName; } // boşsa program hiç kaydedilmedi
    int count() const { return int(m_entries.size()); }
    QString lastError() const { return m_lastError; } // son başarısız işlemin nedeni

    // Klasörü yeniden tara (liste açılırken ve her işlemden sonra).
    Q_INVOKABLE void refresh();

    // Ad kullanılabilir mi? Boş yazı: evet; değilse nedeni.
    Q_INVOKABLE QString nameError(const QString &name) const;

    // Bu adla kaydetmek başka bir programın üzerine yazmak olur mu?
    // Windows'ta büyük/küçük harf ayrımı yoktur: "abc" ile "ABC" aynı dosyadır.
    Q_INVOKABLE bool wouldOverwrite(const QString &name) const;

    Q_INVOKABLE bool open(const QString &name);   // dosyadaki programı ekrana aç
    Q_INVOKABLE bool save();                      // açık programı kendi dosyasına kaydet
    Q_INVOKABLE bool saveAs(const QString &name); // açık programı yeni adla kaydet
    Q_INVOKABLE bool remove(const QString &name); // dosyayı sil
    Q_INVOKABLE void newProgram();                // boş yeni program (henüz dosyası yok)

    // Açılışta: listedeki ilk okunabilir programı aç.
    bool openFirst();

signals:
    void currentNameChanged();
    void countChanged();
    void lastErrorChanged();

private:
    struct Entry
    {
        QString name;
        int stepCount = -1;
        QDateTime savedAt;
        bool readable = false;
    };

    QString filePath(const QString &name) const;
    QString existingName(const QString &name) const; // aynı adlı dosyanın klasördeki yazılışı
    bool write(const QString &path, QString &error) const;
    void setCurrentName(const QString &name);
    void setLastError(const QString &error);

    QString m_folder;
    BendProgram *const m_program;
    QList<Entry> m_entries;
    QString m_currentName;
    QString m_lastError;
};
