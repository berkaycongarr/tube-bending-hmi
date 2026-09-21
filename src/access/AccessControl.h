#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class QSettings;

// Ayarcı şifresi: makinenin ayarlarını (ZAMANLAR, ileride AYARLAR) değiştirmek için.
//
// Değerleri herkes görür; değiştirmek için ayarcı şifresi girilir. Sanayi ekranlarında
// bu yetki seviyesidir: operatör üretir, ayarcı makineyi ayarlar. Böylece operatör
// yanlışlıkla makinenin ayarını bozamaz.
//
// Kilit açıldıktan sonra bir süre (varsayılan 10 dakika) açık kalır; her değişiklikte
// süre baştan başlar, süre dolunca kendiliğinden kilitlenir. KİLİTLE ile hemen kapanır.
// Uygulama her açıldığında kilitli başlar.
//
// Şifrenin kendisi saklanmaz, yalnızca özeti (SHA-256) ayarlar dosyasında durur.
// Dosyada özet yoksa varsayılan şifre geçerlidir (README'de yazılı). Şifre, kilit
// açıkken AYARLAR sayfasından değiştirilir.
class AccessControl : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Erişim denetimi C++ tarafında oluşturulur.")

    Q_PROPERTY(bool unlocked READ isUnlocked NOTIFY unlockedChanged)
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY remainingSecondsChanged)
    Q_PROPERTY(int minimumPinLength READ minimumPinLength CONSTANT)
    Q_PROPERTY(int maximumPinLength READ maximumPinLength CONSTANT)
    Q_PROPERTY(bool defaultPin READ isDefaultPin NOTIFY pinChanged)

public:
    static constexpr int DefaultAutoLockSeconds = 600; // 10 dakika
    static constexpr int MinimumPinLength = 4;
    static constexpr int MaximumPinLength = 8;

    // settings: şifre özetinin saklandığı ayarlar dosyası (ayarlar.ini)
    explicit AccessControl(QSettings *settings, QObject *parent = nullptr);

    bool isUnlocked() const { return m_unlocked; }
    int remainingSeconds() const { return m_remaining; } // kilitlenmeye kalan süre
    int minimumPinLength() const { return MinimumPinLength; }
    int maximumPinLength() const { return MaximumPinLength; }
    bool isDefaultPin() const; // varsayılan şifre mi kullanılıyor? (değiştirilmesi önerilir)

    // Şifre doğruysa kilidi açar (true); yanlışsa kilitli kalır (false).
    Q_INVOKABLE bool unlock(const QString &pin);
    Q_INVOKABLE void lock();
    // Kilit açıkken bir değişiklik yapıldı: kilitlenme süresi baştan başlar.
    Q_INVOKABLE void keepAlive();

    // Yeni şifre: yalnızca kilit açıkken; 4-8 rakam. Özeti hemen dosyaya yazılır.
    Q_INVOKABLE bool changePin(const QString &pin);

    // Kendiliğinden kilitlenme süresi (testler kısaltır).
    void setAutoLockSeconds(int seconds);
    int autoLockSeconds() const { return m_autoLockSeconds; }

signals:
    void unlockedChanged();
    void remainingSecondsChanged();
    void pinChanged();

private:
    static QString digest(const QString &pin); // şifrenin özeti
    static bool validPin(const QString &pin);  // 4-8 rakam mı?
    QString storedDigest() const;              // dosyadaki özet ya da varsayılanınki
    void setRemaining(int seconds);
    void countDown();

    QSettings *m_settings = nullptr;
    bool m_unlocked = false;
    int m_remaining = 0;
    int m_autoLockSeconds = DefaultAutoLockSeconds;
    QTimer m_ticker; // kilit açıkken saniyede bir
};
