#include "ProgramStore.h"

#include "BendProgram.h"

#include <QCollator>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QRegularExpression>
#include <QSaveFile>

#include <algorithm>

namespace {

const QString Extension = QStringLiteral(".json");

// Bir program dosyasını oku ve denetle.
bool readProgram(const QString &path, BendProgram::Data &data, QString &error)
{
    QFile file(path);
    if (!file.exists()) {
        error = ProgramStore::tr("dosya bulunamadı");
        return false;
    }
    // Program dosyaları birkaç kilobayttır; çok büyük bir dosya program olamaz.
    if (file.size() > 1024 * 1024 || !file.open(QIODevice::ReadOnly)) {
        error = ProgramStore::tr("dosya okunamadı");
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        error = ProgramStore::tr("dosyanın biçimi bozuk");
        return false;
    }
    return BendProgram::fromJson(document.object(), data, error);
}

} // namespace

ProgramStore::ProgramStore(const QString &folder, BendProgram *program, QObject *parent)
    : QAbstractListModel(parent)
    , m_folder(QDir::cleanPath(folder))
    , m_program(program)
{
    QDir().mkpath(m_folder);
    refresh();
}

// ---------------------------------------------------------------------------
// QAbstractListModel
// ---------------------------------------------------------------------------

int ProgramStore::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : count();
}

QVariant ProgramStore::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= count())
        return {};

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case NameRole:
        return entry.name;
    case StepCountRole:
        return entry.stepCount;
    case SavedAtRole:
        return entry.savedAt;
    case ReadableRole:
        return entry.readable;
    case CurrentRole:
        return !m_currentName.isEmpty() && entry.name.compare(m_currentName, Qt::CaseInsensitive) == 0;
    default:
        return {};
    }
}

QHash<int, QByteArray> ProgramStore::roleNames() const
{
    return { { NameRole, "name" },
             { StepCountRole, "stepCount" },
             { SavedAtRole, "savedAt" },
             { ReadableRole, "readable" },
             { CurrentRole, "current" } };
}

// ---------------------------------------------------------------------------
// Liste
// ---------------------------------------------------------------------------

QString ProgramStore::displayFolder() const
{
    return QDir::toNativeSeparators(m_folder);
}

void ProgramStore::refresh()
{
    QList<Entry> entries;
    const QFileInfoList files = QDir(m_folder).entryInfoList({ QLatin1Char('*') + Extension }, QDir::Files);
    for (const QFileInfo &info : files) {
        Entry entry;
        entry.name = info.completeBaseName();
        entry.savedAt = info.lastModified();

        BendProgram::Data data;
        QString error;
        entry.readable = readProgram(info.absoluteFilePath(), data, error);
        entry.stepCount = entry.readable ? int(data.steps.size()) : -1;
        entries.append(entry);
    }

    // Türkçe alfabe sırası; sayılar sayı gibi sıralanır ("Parça 2", "Parça 10"dan önce).
    QCollator collator(QLocale(QLocale::Turkish, QLocale::Turkey));
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    collator.setNumericMode(true);
    std::sort(entries.begin(), entries.end(), [&collator](const Entry &a, const Entry &b) {
        return collator.compare(a.name, b.name) < 0;
    });

    const int oldCount = count();
    beginResetModel();
    m_entries = entries;
    endResetModel();
    if (count() != oldCount)
        emit countChanged();
}

QString ProgramStore::nameError(const QString &name) const
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty())
        return tr("Program adı boş olamaz.");
    if (trimmed.size() > MaxNameLength)
        return tr("Program adı en fazla %1 karakter olabilir.").arg(MaxNameLength);

    // Program adı dosya adıdır: Windows'un dosya adlarında kabul etmediği karakterler olamaz.
    static const QString forbidden = QStringLiteral("\\/:*?\"<>|");
    for (const QChar c : trimmed) {
        if (forbidden.contains(c) || c.unicode() < 32)
            return tr("Şu karakterler kullanılamaz: \\ / : * ? \" < > |");
    }
    if (trimmed.endsWith(QLatin1Char('.')))
        return tr("Program adı nokta ile bitemez.");

    // Windows'un aygıtlara ayırdığı adlar (CON, PRN, COM1, …) dosya adı olamaz.
    static const QRegularExpression reserved(QStringLiteral("^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\\..*)?$"),
                                             QRegularExpression::CaseInsensitiveOption);
    if (reserved.match(trimmed).hasMatch())
        return tr("Bu ad Windows'ta dosya adı olarak kullanılamaz.");

    return {};
}

bool ProgramStore::wouldOverwrite(const QString &name) const
{
    const QString trimmed = name.trimmed();
    if (!m_currentName.isEmpty() && trimmed.compare(m_currentName, Qt::CaseInsensitive) == 0)
        return false; // açık programın kendi dosyası
    return !existingName(trimmed).isEmpty();
}

// ---------------------------------------------------------------------------
// Dosya işlemleri
// ---------------------------------------------------------------------------

bool ProgramStore::open(const QString &name)
{
    setLastError({});

    BendProgram::Data data;
    QString error;
    if (!readProgram(filePath(name), data, error)) {
        setLastError(tr("«%1» açılamadı: %2.").arg(name, error));
        return false;
    }

    data.name = name; // dosyanın adı programın adıdır
    m_program->setData(data);
    setCurrentName(name);
    return true;
}

bool ProgramStore::save()
{
    setLastError({});
    if (m_currentName.isEmpty()) {
        setLastError(tr("Programın henüz bir adı yok."));
        return false;
    }

    QString error;
    if (!write(filePath(m_currentName), error)) {
        setLastError(tr("«%1» kaydedilemedi: %2.").arg(m_currentName, error));
        return false;
    }
    m_program->setModified(false);
    refresh();
    return true;
}

bool ProgramStore::saveAs(const QString &name)
{
    setLastError({});
    const QString problem = nameError(name);
    if (!problem.isEmpty()) {
        setLastError(problem);
        return false;
    }

    // Aynı ad (harf büyüklüğü farklı olsa bile) zaten varsa o dosyaya yazılır;
    // böylece bir program için hiçbir zaman iki dosya oluşmaz.
    const QString existing = existingName(name.trimmed());
    const QString target = existing.isEmpty() ? name.trimmed() : existing;

    // Önce adı ver, sonra yaz: dosyanın içindeki ad da doğru olsun.
    const QString oldName = m_program->name();
    m_program->setName(target);

    QString error;
    if (!write(filePath(target), error)) {
        m_program->setName(oldName);
        setLastError(tr("«%1» kaydedilemedi: %2.").arg(target, error));
        return false;
    }
    m_program->setModified(false);
    setCurrentName(target);
    refresh();
    return true;
}

bool ProgramStore::remove(const QString &name)
{
    setLastError({});
    if (name.isEmpty() || !QFile::remove(filePath(name))) {
        setLastError(tr("«%1» silinemedi.").arg(name));
        refresh();
        return false;
    }

    // Açık programın dosyası silindiyse program ekranda kalır ama artık kayıtlı değildir.
    if (!m_currentName.isEmpty() && name.compare(m_currentName, Qt::CaseInsensitive) == 0) {
        setCurrentName({});
        m_program->setModified(true);
    }
    refresh();
    return true;
}

void ProgramStore::newProgram()
{
    setLastError({});
    m_program->clear(tr("Yeni program"));
    setCurrentName({});
}

bool ProgramStore::openFirst()
{
    refresh();
    for (const Entry &entry : std::as_const(m_entries)) {
        if (entry.readable && open(entry.name))
            return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Yardımcılar
// ---------------------------------------------------------------------------

QString ProgramStore::filePath(const QString &name) const
{
    return QDir(m_folder).filePath(name + Extension);
}

QString ProgramStore::existingName(const QString &name) const
{
    // Liste eski kalmış olabilir: klasöre doğrudan bakılır.
    const QStringList files = QDir(m_folder).entryList({ QLatin1Char('*') + Extension }, QDir::Files);
    for (const QString &file : files) {
        const QString base = QFileInfo(file).completeBaseName();
        if (base.compare(name, Qt::CaseInsensitive) == 0)
            return base;
    }
    return {};
}

bool ProgramStore::write(const QString &path, QString &error) const
{
    if (!QDir().mkpath(m_folder)) {
        error = tr("klasör oluşturulamadı");
        return false;
    }

    // Güvenli kaydetme: QSaveFile önce geçici bir dosyaya yazar, yazma bitince tek
    // hamlede eski dosyanın yerine koyar. Kaydederken elektrik kesilirse elde yarım
    // yazılmış bir dosya değil, eski program kalır.
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        error = tr("dosya yazılamadı");
        return false;
    }
    file.write(QJsonDocument(m_program->toJson()).toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        error = tr("dosya yazılamadı");
        return false;
    }
    return true;
}

void ProgramStore::setCurrentName(const QString &name)
{
    if (m_currentName == name)
        return;
    m_currentName = name;
    emit currentNameChanged();
    // Listede "açık" işareti de değişti.
    if (count() > 0)
        emit dataChanged(index(0), index(count() - 1), { CurrentRole });
}

void ProgramStore::setLastError(const QString &error)
{
    if (m_lastError == error)
        return;
    m_lastError = error;
    emit lastErrorChanged();
}
