#include "BendProgram.h"

#include <QtMath>

#include <cmath>

namespace {

// QML'den her sayı gelebilir: komut dizilerinin dışına taşmamak için denetle.
bool isCommand(int command)
{
    return command >= BendProgram::Feed && command <= BendProgram::Rotate;
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
}

void BendProgram::setTubeDiameter(double diameter)
{
    if (!(diameter > 0.0) || m_tubeDiameter == diameter)
        return;
    m_tubeDiameter = diameter;
    emit tubeChanged();
}

void BendProgram::setDieRadius(double radius)
{
    if (!(radius > 0.0) || m_dieRadius == radius)
        return;
    m_dieRadius = radius;
    emit tubeChanged();
    emit summaryChanged(); // yay boyları yarıçapa bağlı
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

void BendProgram::setStepLimits(Command command, double minimum, double maximum)
{
    if (!isCommand(command))
        return;
    m_minimum[command] = minimum;
    m_maximum[command] = maximum;

    // Sınırlar değişti: satırların geçerliliği yeniden hesaplanmalı.
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
    return true;
}

// ---------------------------------------------------------------------------
// Örnek program
// ---------------------------------------------------------------------------

void BendProgram::loadExample()
{
    // Müşterinin ekranındaki program: okul sandalyesinin oturak iskeleti (U parça).
    beginResetModel();
    m_steps = { { Feed, 260.0 }, { Bend, 88.5 }, { Feed, 95.0 }, { Bend, 88.5 }, { Feed, 260.0 } };
    endResetModel();

    setName(QStringLiteral("Ortaokul Oturak (2026)"));
    m_tubeLength = 980.0;
    m_tubeDiameter = 50.0;
    m_dieRadius = 116.0;
    emit tubeChanged();
    emit summaryChanged();
}
