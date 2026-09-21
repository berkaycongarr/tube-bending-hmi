#include "AccessControl.h"

#include <QCryptographicHash>
#include <QSettings>

namespace {

// Ayarlar dosyasındaki anahtar: şifrenin özeti (şifrenin kendisi değil).
const QString DigestKey = QStringLiteral("ayarciSifreOzeti");

// Dosyada özet yoksa geçerli olan şifre (README'de yazılı; müşteri değiştirir).
const QString DefaultPin = QStringLiteral("1234");

} // namespace

AccessControl::AccessControl(QSettings *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
{
    m_ticker.setInterval(1000);
    connect(&m_ticker, &QTimer::timeout, this, &AccessControl::countDown);
}

QString AccessControl::digest(const QString &pin)
{
    // Özet, programa özgü bir önekle alınır: başka bir yerde aynı şifrenin özetiyle
    // karşılaştırılamasın.
    const QByteArray bytes = QByteArrayLiteral("BoruBukme|") + pin.toUtf8();
    return QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex());
}

QString AccessControl::storedDigest() const
{
    const QString saved = m_settings ? m_settings->value(DigestKey).toString() : QString();
    return saved.isEmpty() ? digest(DefaultPin) : saved;
}

bool AccessControl::unlock(const QString &pin)
{
    if (pin.size() < MinimumPinLength || pin.size() > MaximumPinLength || digest(pin) != storedDigest())
        return false;

    if (!m_unlocked) {
        m_unlocked = true;
        emit unlockedChanged();
    }
    setRemaining(m_autoLockSeconds);
    m_ticker.start();
    return true;
}

void AccessControl::lock()
{
    m_ticker.stop();
    setRemaining(0);
    if (m_unlocked) {
        m_unlocked = false;
        emit unlockedChanged();
    }
}

void AccessControl::keepAlive()
{
    if (m_unlocked)
        setRemaining(m_autoLockSeconds);
}

void AccessControl::setAutoLockSeconds(int seconds)
{
    m_autoLockSeconds = qMax(1, seconds);
    if (m_unlocked && m_remaining > m_autoLockSeconds)
        setRemaining(m_autoLockSeconds);
}

void AccessControl::setRemaining(int seconds)
{
    if (m_remaining == seconds)
        return;
    m_remaining = seconds;
    emit remainingSecondsChanged();
}

void AccessControl::countDown()
{
    if (m_remaining <= 1)
        lock();
    else
        setRemaining(m_remaining - 1);
}
