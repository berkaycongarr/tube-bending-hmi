#include "DieLibrary.h"

#include <QCollator>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QLocale>
#include <QSaveFile>

#include <algorithm>
#include <cmath>

namespace {

// Dosya biçiminin adı ve sürümü (program dosyalarındaki gibi). Biçim değişirse
// sürüm artar: eski dosyalar tanınır, yenisi yanlışlıkla açılmaz.
const QString FormatName = QStringLiteral("BoruBukmeKaliplar");
constexpr int FormatVersion = 1;

// Sayı gerçekten bir sayı mı (sonsuz ya da tanımsız değil)?
bool readNumber(const QJsonValue &value, double &number)
{
    if (!value.isDouble() || !std::isfinite(value.toDouble()))
        return false;
    number = value.toDouble();
    return true;
}

// Türkçe alfabe sırası; sayılar sayı gibi sıralanır ("R60", "R116"dan önce gelir).
void sortDies(QList<DieLibrary::Die> &dies)
{
    QCollator collator(QLocale(QLocale::Turkish, QLocale::Turkey));
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    collator.setNumericMode(true);
    std::sort(dies.begin(), dies.end(), [&collator](const DieLibrary::Die &a, const DieLibrary::Die &b) {
        return collator.compare(a.name, b.name) < 0;
    });
}

bool sameDie(const DieLibrary::Die &a, const DieLibrary::Die &b)
{
    return a.name == b.name && a.radius == b.radius && a.tubeDiameter == b.tubeDiameter
           && a.mandrel == b.mandrel && a.feedDuringBend == b.feedDuringBend;
}

// Örnek kalıp: müşterinin ekranındaki "AKTİF KALIP". Fotoğrafta MALAFALI BÜK ve
// BÜKÜMDE İLERLE kutucukları boş; "25X50"nin anlamı müşteriye sorulacak.
DieLibrary::Die exampleDie()
{
    return { QStringLiteral("25X50XR116"), 116.0, 50.0, false, false };
}

} // namespace

DieLibrary::DieLibrary(const QString &filePath, QObject *parent)
    : QAbstractListModel(parent)
    , m_path(QDir::cleanPath(filePath))
{
    load();
}

// ---------------------------------------------------------------------------
// QAbstractListModel
// ---------------------------------------------------------------------------

int DieLibrary::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : count();
}

QVariant DieLibrary::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= count())
        return {};

    const Die &die = m_dies.at(index.row());
    switch (role) {
    case NameRole:
        return die.name;
    case RadiusRole:
        return die.radius;
    case TubeDiameterRole:
        return die.tubeDiameter;
    case MandrelRole:
        return die.mandrel;
    case FeedDuringBendRole:
        return die.feedDuringBend;
    case ActiveRole:
        return index.row() == activeRow();
    default:
        return {};
    }
}

QHash<int, QByteArray> DieLibrary::roleNames() const
{
    return { { NameRole, "name" },
             { RadiusRole, "dieRadius" },
             { TubeDiameterRole, "tubeDiameter" },
             { MandrelRole, "mandrel" },
             { FeedDuringBendRole, "feedDuringBend" },
             { ActiveRole, "active" } };
}

// ---------------------------------------------------------------------------
// Bilgiler
// ---------------------------------------------------------------------------

QString DieLibrary::displayFile() const
{
    return QDir::toNativeSeparators(m_path);
}

double DieLibrary::activeRadius() const
{
    const int row = activeRow();
    return row >= 0 ? m_dies.at(row).radius : 0.0;
}

double DieLibrary::activeTubeDiameter() const
{
    const int row = activeRow();
    return row >= 0 ? m_dies.at(row).tubeDiameter : 0.0;
}

bool DieLibrary::activeMandrel() const
{
    const int row = activeRow();
    return row >= 0 && m_dies.at(row).mandrel;
}

bool DieLibrary::activeFeedDuringBend() const
{
    const int row = activeRow();
    return row >= 0 && m_dies.at(row).feedDuringBend;
}

QString DieLibrary::nameError(const QString &name, int ignoreRow) const
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty())
        return tr("Kalıp adı boş olamaz.");
    if (trimmed.size() > MaxNameLength)
        return tr("Kalıp adı en fazla %1 karakter olabilir.").arg(MaxNameLength);
    for (const QChar c : trimmed) {
        if (c.unicode() < 32)
            return tr("Kalıp adında görünmeyen karakter olamaz.");
    }

    // Ad kalıbın kimliğidir: iki kalıp aynı adı taşıyamaz (harf büyüklüğü fark etmez).
    for (int row = 0; row < count(); ++row) {
        if (row != ignoreRow && m_dies.at(row).name.compare(trimmed, Qt::CaseInsensitive) == 0)
            return tr("Bu adla bir kalıp zaten var.");
    }
    return {};
}

int DieLibrary::indexOf(const QString &name) const
{
    const QString trimmed = name.trimmed();
    for (int row = 0; row < count(); ++row) {
        if (m_dies.at(row).name.compare(trimmed, Qt::CaseInsensitive) == 0)
            return row;
    }
    return -1;
}

QVariantMap DieLibrary::get(int row) const
{
    if (row < 0 || row >= count())
        return {};
    const Die &die = m_dies.at(row);
    return { { QStringLiteral("name"), die.name },
             { QStringLiteral("radius"), die.radius },
             { QStringLiteral("tubeDiameter"), die.tubeDiameter },
             { QStringLiteral("mandrel"), die.mandrel },
             { QStringLiteral("feedDuringBend"), die.feedDuringBend },
             { QStringLiteral("active"), row == activeRow() } };
}

// ---------------------------------------------------------------------------
// Değişiklikler
// ---------------------------------------------------------------------------

bool DieLibrary::add(const QString &name, double radius, double tubeDiameter, bool mandrel,
                     bool feedDuringBend)
{
    QString problem = nameError(name);
    if (problem.isEmpty())
        problem = valueError(radius, tubeDiameter);
    if (!problem.isEmpty()) {
        setLastError(problem);
        return false;
    }

    QList<Die> dies = m_dies;
    dies.append(Die { name.trimmed(), radius, tubeDiameter, mandrel, feedDuringBend });
    return apply(dies, m_activeName, tr("Kalıp kaydedilemedi: %1."));
}

bool DieLibrary::update(int row, const QString &name, double radius, double tubeDiameter,
                        bool mandrel, bool feedDuringBend)
{
    if (row < 0 || row >= count()) {
        setLastError(tr("Kalıp bulunamadı."));
        return false;
    }

    QString problem = nameError(name, row);
    if (problem.isEmpty())
        problem = valueError(radius, tubeDiameter);
    if (!problem.isEmpty()) {
        setLastError(problem);
        return false;
    }

    // Takılı kalıbın adı değişirse "takılı" bilgisi yeni adı izler.
    const QString active = row == activeRow() ? name.trimmed() : m_activeName;

    QList<Die> dies = m_dies;
    dies[row] = Die { name.trimmed(), radius, tubeDiameter, mandrel, feedDuringBend };
    return apply(dies, active, tr("Kalıp kaydedilemedi: %1."));
}

bool DieLibrary::remove(int row)
{
    if (row < 0 || row >= count()) {
        setLastError(tr("Kalıp bulunamadı."));
        return false;
    }

    // Makinede duran kalıp listeden silinirse ekran neyin takılı olduğunu bilemez.
    if (row == activeRow()) {
        setLastError(tr("Takılı kalıp silinemez: önce başka bir kalıbı takılı yapın."));
        return false;
    }

    QList<Die> dies = m_dies;
    dies.removeAt(row);
    return apply(dies, m_activeName, tr("Kalıp silinemedi: %1."));
}

bool DieLibrary::setActive(int row)
{
    if (row < 0 || row >= count())
        return false;

    setLastError({});
    const QString name = m_dies.at(row).name;
    if (name == m_activeName)
        return true;

    m_activeName = name;
    emit dataChanged(index(0), index(count() - 1), { ActiveRole });
    emit activeChanged();
    return true;
}

bool DieLibrary::setActiveName(const QString &name)
{
    const int row = indexOf(name);
    return row >= 0 && setActive(row);
}

// ---------------------------------------------------------------------------
// Dosya biçimi
// ---------------------------------------------------------------------------

QJsonObject DieLibrary::toJson(const QList<Die> &dies)
{
    QJsonArray array;
    for (const Die &die : dies) {
        array.append(QJsonObject {
            { QStringLiteral("name"), die.name },
            { QStringLiteral("radius"), die.radius },
            { QStringLiteral("tubeDiameter"), die.tubeDiameter },
            { QStringLiteral("mandrel"), die.mandrel },
            { QStringLiteral("feedDuringBend"), die.feedDuringBend },
        });
    }

    return QJsonObject {
        { QStringLiteral("format"), FormatName },
        { QStringLiteral("version"), FormatVersion },
        { QStringLiteral("dies"), array },
    };
}

bool DieLibrary::fromJson(const QJsonObject &json, QList<Die> &dies, QString &error)
{
    if (json.value(QStringLiteral("format")).toString() != FormatName) {
        error = tr("bu dosya bir kalıp listesi değil");
        return false;
    }

    const QJsonValue version = json.value(QStringLiteral("version"));
    if (!version.isDouble() || version.toDouble() != version.toInt() || version.toInt() < 1) {
        error = tr("dosyanın sürüm bilgisi hatalı");
        return false;
    }
    if (version.toInt() > FormatVersion) {
        error = tr("dosya programın daha yeni bir sürümüyle kaydedilmiş (sürüm %1)").arg(version.toInt());
        return false;
    }

    const QJsonValue list = json.value(QStringLiteral("dies"));
    if (!list.isArray()) {
        error = tr("kalıp listesi bulunamadı");
        return false;
    }

    QList<Die> result;
    const QJsonArray array = list.toArray();
    for (qsizetype i = 0; i < array.size(); ++i) {
        const QJsonObject item = array.at(i).toObject();
        const QJsonValue mandrel = item.value(QStringLiteral("mandrel"));
        const QJsonValue feed = item.value(QStringLiteral("feedDuringBend"));

        Die die;
        die.name = item.value(QStringLiteral("name")).toString().trimmed();
        if (die.name.isEmpty() || die.name.size() > MaxNameLength
            || !readNumber(item.value(QStringLiteral("radius")), die.radius)
            || !readNumber(item.value(QStringLiteral("tubeDiameter")), die.tubeDiameter)
            || !(die.radius > 0.0) || !(die.tubeDiameter > 0.0) || !mandrel.isBool() || !feed.isBool()) {
            error = tr("%1. kalıp hatalı").arg(i + 1);
            return false;
        }
        die.mandrel = mandrel.toBool();
        die.feedDuringBend = feed.toBool();

        for (const Die &other : std::as_const(result)) {
            if (other.name.compare(die.name, Qt::CaseInsensitive) == 0) {
                error = tr("«%1» adı iki kez geçiyor").arg(die.name);
                return false;
            }
        }
        result.append(die);
    }

    dies = result;
    return true;
}

// ---------------------------------------------------------------------------
// Yardımcılar
// ---------------------------------------------------------------------------

int DieLibrary::activeRow() const
{
    return m_activeName.isEmpty() ? -1 : indexOf(m_activeName);
}

QString DieLibrary::valueError(double radius, double tubeDiameter) const
{
    if (!std::isfinite(radius) || radius < MinRadius || radius > MaxRadius)
        return tr("Kalıp yarıçapı %1 ile %2 mm arasında olmalı.").arg(MinRadius).arg(MaxRadius);
    if (!std::isfinite(tubeDiameter) || tubeDiameter < MinDiameter || tubeDiameter > MaxDiameter)
        return tr("Boru çapı %1 ile %2 mm arasında olmalı.").arg(MinDiameter).arg(MaxDiameter);
    return {};
}

// Yeni listeyi önce dosyaya yaz; yazılabildiyse ekrandaki listeyi değiştir.
// Böylece ekranda görünen liste her zaman dosyadakiyle aynıdır.
bool DieLibrary::apply(QList<Die> dies, const QString &activeName, const QString &failMessage)
{
    sortDies(dies);

    QString error;
    if (!write(dies, error)) {
        setLastError(failMessage.arg(error));
        return false;
    }

    // Takılı kalıp değişti mi (adı ya da bilgileri)? Makine bu bilgilerle çalışır.
    const int oldActive = activeRow();
    const Die before = oldActive >= 0 ? m_dies.at(oldActive) : Die {};

    const int oldCount = count();
    beginResetModel();
    m_dies = dies;
    m_activeName = activeName;
    endResetModel();

    if (count() != oldCount)
        emit countChanged();

    const int newActive = activeRow();
    if ((oldActive >= 0) != (newActive >= 0)
        || (newActive >= 0 && !sameDie(before, m_dies.at(newActive))))
        emit activeChanged();

    setLastError({});
    return true;
}

bool DieLibrary::write(const QList<Die> &dies, QString &error) const
{
    if (!QDir().mkpath(QFileInfo(m_path).absolutePath())) {
        error = tr("klasör oluşturulamadı");
        return false;
    }

    // Güvenli kaydetme (QSaveFile): önce geçici dosyaya yazılır, bitince tek hamlede
    // eskisinin yerine geçer. Yazarken elektrik kesilirse eski liste kalır.
    QSaveFile file(m_path);
    if (!file.open(QIODevice::WriteOnly)) {
        error = tr("dosya yazılamadı");
        return false;
    }
    file.write(QJsonDocument(toJson(dies)).toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        error = tr("dosya yazılamadı");
        return false;
    }
    return true;
}

void DieLibrary::load()
{
    // İlk açılış: dosya yoksa örnek kalıpla oluşturulur (demoda liste boş görünmesin).
    if (!QFileInfo::exists(m_path)) {
        const QList<Die> dies { exampleDie() };
        QString error;
        if (!write(dies, error))
            m_loadWarning = tr("Kalıp dosyası oluşturulamadı: %1.").arg(error);
        m_dies = dies;
        return;
    }

    QList<Die> dies;
    QString error;
    bool ok = false;

    QFile file(m_path);
    // Kalıp listesi birkaç kilobayttır; çok büyük bir dosya kalıp listesi olamaz.
    if (file.size() <= 1024 * 1024 && file.open(QIODevice::ReadOnly)) {
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
        file.close();
        if (parseError.error == QJsonParseError::NoError && document.isObject())
            ok = fromJson(document.object(), dies, error);
        else
            error = tr("dosyanın biçimi bozuk");
    } else {
        error = tr("dosya okunamadı");
    }

    if (ok) {
        sortDies(dies);
        m_dies = dies;
        return;
    }

    // Bozuk dosyanın üzerine yazılmaz: yedeklenir, liste boş başlar. Kalıplar yeniden
    // girilir ya da yedekten kurtarılır. Hangi kalıbın takılı olduğu da bilinmez.
    const QString backup = m_path + QStringLiteral(".bozuk");
    QFile::remove(backup);
    if (QFile::rename(m_path, backup)) {
        m_loadWarning = tr("Kalıp dosyası okunamadı (%1). Dosya «%2» adıyla yedeklendi; "
                           "kalıpları yeniden girin.")
                            .arg(error, QFileInfo(backup).fileName());
    } else {
        m_loadWarning = tr("Kalıp dosyası okunamadı (%1).").arg(error);
    }
}

void DieLibrary::setLastError(const QString &error)
{
    if (m_lastError == error)
        return;
    m_lastError = error;
    emit lastErrorChanged();
}
