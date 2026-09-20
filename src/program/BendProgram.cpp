#include "BendProgram.h"

#include <QJsonArray>
#include <QtMath>

#include <cmath>

namespace {

// QML'den her sayı gelebilir: komut dizilerinin dışına taşmamak için denetle.
bool isCommand(int command)
{
    return command >= BendProgram::Feed && command <= BendProgram::Rotate;
}

// Dosya biçiminin adı ve sürümü. Biçim değişirse sürüm artar; böylece eski
// dosyalar tanınır, daha yeni sürümle yazılmış dosya da yanlışlıkla açılmaz.
const QString FormatName = QStringLiteral("BoruBukmeProgram");
constexpr int FormatVersion = 1;

// Komutlar dosyada sayı değil yazı olarak saklanır: dosyayı açan kişi anlar,
// koddaki sıralama değişse de dosyalar bozulmaz.
const char *const CommandNames[] = { "feed", "bend", "rotate" };

// Sayı gerçekten bir sayı mı (sonsuz ya da tanımsız değil)?
bool readNumber(const QJsonValue &value, double &number)
{
    if (!value.isDouble() || !std::isfinite(value.toDouble()))
        return false;
    number = value.toDouble();
    return true;
}

} // namespace

BendProgram::BendProgram(QObject *parent)
    : QAbstractListModel(parent)
{
}

// ---------------------------------------------------------------------------
// QAbstractListModel
// ---------------------------------------------------------------------------

int BendProgram::rowCount(const QModelIndex &parent) const
{
    // Düz bir liste: alt satırlar yok.
    return parent.isValid() ? 0 : count();
}

QVariant BendProgram::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= count())
        return {};

    const Step &step = m_steps.at(index.row());
    switch (role) {
    case CommandRole:
        return int(step.command);
    case ValueRole:
        return step.value;
    case ValidRole:
        return inRange(step.command, step.value);
    default:
        return {};
    }
}

QHash<int, QByteArray> BendProgram::roleNames() const
{
    // QML'deki satır, bu adlarla okunur: command, value, valid.
    return { { CommandRole, "command" }, { ValueRole, "value" }, { ValidRole, "valid" } };
}

// ---------------------------------------------------------------------------
// Boru ve kalıp
// ---------------------------------------------------------------------------

void BendProgram::setName(const QString &name)
{
    if (m_name == name)
        return;
    m_name = name;
    emit nameChanged();
}

void BendProgram::setTubeLength(double length)
{
    if (!(length > 0.0) || m_tubeLength == length)
        return;
    m_tubeLength = length;
    emit tubeChanged();
    emit summaryChanged();
    setModified(true);
}

void BendProgram::setTubeDiameter(double diameter)
{
    if (!(diameter > 0.0) || m_tubeDiameter == diameter)
        return;
    m_tubeDiameter = diameter;
    emit tubeChanged();
    setModified(true);
}

void BendProgram::setDieRadius(double radius)
{
    if (!(radius > 0.0) || m_dieRadius == radius)
        return;
    m_dieRadius = radius;
    emit tubeChanged();
    emit summaryChanged(); // yay boyları yarıçapa bağlı
    setModified(true);
}

// ---------------------------------------------------------------------------
// Doğrulama
// ---------------------------------------------------------------------------

double BendProgram::developedLength() const
{
    double length = 0.0;
    for (const Step &step : m_steps) {
        if (step.command == Feed)
            length += step.value; // düz parça
        else if (step.command == Bend)
            length += m_dieRadius * qDegreesToRadians(step.value); // yay: yarıçap × açı (radyan)
        // Rotasyon boruyu döndürür, boy harcamaz.
    }
    return length;
}

int BendProgram::invalidStepCount() const
{
    int invalid = 0;
    for (const Step &step : m_steps) {
        if (!inRange(step.command, step.value))
            ++invalid;
    }
    return invalid;
}

bool BendProgram::isValid() const
{
    // Ondalıklı hesap küçük bir artı-eksi bırakabilir; binde bir mm'yi yok say.
    return count() > 0 && invalidStepCount() == 0 && remainingLength() >= -0.001;
}

QVariantList BendProgram::recipe() const
{
    QVariantList steps;
    steps.reserve(m_steps.size());
    for (const Step &step : m_steps) {
        steps.append(QVariantMap {
            { QStringLiteral("command"), int(step.command) },
            { QStringLiteral("value"), step.value },
        });
    }
    return steps;
}

void BendProgram::setModified(bool modified)
{
    if (m_modified == modified)
        return;
    m_modified = modified;
    emit modifiedChanged();
}

void BendProgram::setStepLimits(Command command, double minimum, double maximum)
{
    if (!isCommand(command))
        return;
    m_minimum[command] = minimum;
    m_maximum[command] = maximum;

    // Sınırlar değişti: satırların geçerliliği yeniden hesaplanmalı.
    // (Sınırlar makinenin ayarıdır; program değişmiş sayılmaz.)
    if (count() > 0)
        emit dataChanged(index(0), index(count() - 1), { ValidRole });
    emit summaryChanged();
}

double BendProgram::minimumValue(Command command) const
{
    return isCommand(command) ? m_minimum[command] : 0.0;
}

double BendProgram::maximumValue(Command command) const
{
    return isCommand(command) ? m_maximum[command] : 0.0;
}

bool BendProgram::inRange(Command command, double value) const
{
    return isCommand(command) && std::isfinite(value)
           && value >= m_minimum[command] && value <= m_maximum[command];
}

// ---------------------------------------------------------------------------
// Düzenleme
// ---------------------------------------------------------------------------

bool BendProgram::insertStep(int row, Command command, double value)
{
    if (row < 0 || row > count() || !inRange(command, value))
        return false;

    // ListView'e "şu satır ekleniyor" haber verilir; ekran yalnızca o satırı çizer.
    beginInsertRows(QModelIndex(), row, row);
    m_steps.insert(row, Step { command, value });
    endInsertRows();
    emit summaryChanged();
    setModified(true);
    return true;
}

bool BendProgram::setValue(int row, double value)
{
    if (row < 0 || row >= count())
        return false;

    Step &step = m_steps[row];
    if (!inRange(step.command, value))
        return false;

    step.value = value;
    emit dataChanged(index(row), index(row), { ValueRole, ValidRole });
    emit summaryChanged();
    setModified(true);
    return true;
}

bool BendProgram::removeStep(int row)
{
    if (row < 0 || row >= count())
        return false;

    beginRemoveRows(QModelIndex(), row, row);
    m_steps.removeAt(row);
    endRemoveRows();
    emit summaryChanged();
    setModified(true);
    return true;
}

bool BendProgram::moveStep(int from, int to)
{
    if (from < 0 || from >= count() || to < 0 || to >= count() || from == to)
        return false;

    // Qt'nin taşıma kuralı: aşağı taşırken hedef, "hedef satırın bir altı" olarak verilir.
    const int destination = to > from ? to + 1 : to;
    beginMoveRows(QModelIndex(), from, from, QModelIndex(), destination);
    m_steps.move(from, to);
    endMoveRows();
    emit summaryChanged();
    setModified(true);
    return true;
}

// ---------------------------------------------------------------------------
// Dosya biçimi
// ---------------------------------------------------------------------------

QJsonObject BendProgram::toJson() const
{
    QJsonArray steps;
    for (const Step &step : m_steps) {
        steps.append(QJsonObject {
            { QStringLiteral("command"), QString::fromLatin1(CommandNames[step.command]) },
            { QStringLiteral("value"), step.value },
        });
    }

    return QJsonObject {
        { QStringLiteral("format"), FormatName },
        { QStringLiteral("version"), FormatVersion },
        { QStringLiteral("name"), m_name },
        { QStringLiteral("tube"), QJsonObject {
              { QStringLiteral("length"), m_tubeLength },
              { QStringLiteral("diameter"), m_tubeDiameter },
              { QStringLiteral("dieRadius"), m_dieRadius },
          } },
        { QStringLiteral("steps"), steps },
    };
}

bool BendProgram::fromJson(const QJsonObject &json, Data &data, QString &error)
{
    if (json.value(QStringLiteral("format")).toString() != FormatName) {
        error = tr("bu dosya bir büküm programı değil");
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

    Data result;
    result.name = json.value(QStringLiteral("name")).toString();

    const QJsonObject tube = json.value(QStringLiteral("tube")).toObject();
    if (!readNumber(tube.value(QStringLiteral("length")), result.tubeLength)
        || !readNumber(tube.value(QStringLiteral("diameter")), result.tubeDiameter)
        || !readNumber(tube.value(QStringLiteral("dieRadius")), result.dieRadius)
        || !(result.tubeLength > 0.0) || !(result.tubeDiameter > 0.0) || !(result.dieRadius > 0.0)) {
        error = tr("boru ve kalıp bilgileri eksik ya da hatalı");
        return false;
    }

    const QJsonValue steps = json.value(QStringLiteral("steps"));
    if (!steps.isArray()) {
        error = tr("adım listesi bulunamadı");
        return false;
    }

    const QJsonArray array = steps.toArray();
    for (qsizetype i = 0; i < array.size(); ++i) {
        const QJsonObject item = array.at(i).toObject();
        const QString command = item.value(QStringLiteral("command")).toString();

        Step step;
        int found = -1;
        for (int c = Feed; c <= Rotate; ++c) {
            if (command == QLatin1String(CommandNames[c]))
                found = c;
        }
        if (found < 0 || !readNumber(item.value(QStringLiteral("value")), step.value)) {
            error = tr("%1. adım hatalı").arg(i + 1);
            return false;
        }
        step.command = Command(found);
        result.steps.append(step);
    }

    data = result;
    return true;
}

void BendProgram::setData(const Data &data)
{
    beginResetModel();
    m_steps = data.steps;
    endResetModel();

    setName(data.name);
    m_tubeLength = data.tubeLength;
    m_tubeDiameter = data.tubeDiameter;
    m_dieRadius = data.dieRadius;
    emit tubeChanged();
    emit summaryChanged();
    setModified(false);
}

void BendProgram::clear(const QString &name)
{
    Data data;
    data.name = name;
    data.tubeLength = m_tubeLength;
    data.tubeDiameter = m_tubeDiameter;
    data.dieRadius = m_dieRadius;
    setData(data);
}

// ---------------------------------------------------------------------------
// Örnek program
// ---------------------------------------------------------------------------

void BendProgram::loadExample()
{
    // Müşterinin ekranındaki program: okul sandalyesinin oturak iskeleti (U parça).
    Data data;
    data.name = QStringLiteral("Ortaokul Oturak (2026)");
    data.tubeLength = 980.0;
    data.tubeDiameter = 50.0;
    data.dieRadius = 116.0;
    data.steps = { { Feed, 260.0 }, { Bend, 88.5 }, { Feed, 95.0 }, { Bend, 88.5 }, { Feed, 260.0 } };
    setData(data);
}
