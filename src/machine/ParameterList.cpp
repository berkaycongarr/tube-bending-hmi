#include "ParameterList.h"

#include <cmath>

namespace {

// Değeri gösterilen ondalık basamağa yuvarla: ekranda görünen neyse saklanan da o olsun.
double rounded(double value, int decimals)
{
    const double scale = std::pow(10.0, decimals);
    return std::round(value * scale) / scale;
}

} // namespace

ParameterList::ParameterList(QObject *parent)
    : QAbstractListModel(parent)
{
}

int ParameterList::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : count();
}

QVariant ParameterList::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= count())
        return {};

    const Parameter &p = m_parameters.at(index.row());
    switch (role) {
    case KeyRole:
        return p.key;
    case TitleRole:
        return p.title;
    case NoteRole:
        return p.note;
    case UnitRole:
        return p.unit;
    case ValueRole:
        return p.value;
    case DefaultValueRole:
        return p.defaultValue;
    case MinimumRole:
        return p.minimum;
    case MaximumRole:
        return p.maximum;
    case DecimalsRole:
        return p.decimals;
    case ModifiedRole:
        return p.value != p.defaultValue;
    default:
        return {};
    }
}

QHash<int, QByteArray> ParameterList::roleNames() const
{
    return {
        { KeyRole, "key" },
        { TitleRole, "title" },
        { NoteRole, "note" },
        { UnitRole, "unit" },
        { ValueRole, "value" },
        { DefaultValueRole, "defaultValue" },
        { MinimumRole, "minimum" },
        { MaximumRole, "maximum" },
        { DecimalsRole, "decimals" },
        { ModifiedRole, "modified" },
    };
}

void ParameterList::add(const Parameter &parameter)
{
    Parameter p = parameter;
    p.defaultValue = rounded(p.defaultValue, p.decimals);
    p.value = p.defaultValue;

    beginInsertRows(QModelIndex(), count(), count());
    m_parameters.append(p);
    endInsertRows();
    emit countChanged();
}

int ParameterList::indexOf(const QString &key) const
{
    for (int i = 0; i < count(); ++i) {
        if (m_parameters.at(i).key == key)
            return i;
    }
    return -1;
}

double ParameterList::value(const QString &key) const
{
    const int row = indexOf(key);
    return row >= 0 ? m_parameters.at(row).value : 0.0;
}

QVariantMap ParameterList::get(int row) const
{
    if (row < 0 || row >= count())
        return {};

    QVariantMap map;
    const QHash<int, QByteArray> roles = roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        map.insert(QString::fromLatin1(it.value()), data(index(row), it.key()));
    return map;
}

bool ParameterList::setValue(const QString &key, double value)
{
    const int row = indexOf(key);
    if (m_locked || row < 0 || !std::isfinite(value))
        return false;

    Parameter &p = m_parameters[row];
    const double v = rounded(value, p.decimals);
    if (v < p.minimum || v > p.maximum)
        return false;
    if (v == p.value)
        return true;

    p.value = v;
    const QModelIndex changed = index(row);
    emit dataChanged(changed, changed, { ValueRole, ModifiedRole });
    bumpRevision();
    emit valueChanged(p.key, p.value);
    return true;
}

bool ParameterList::reset(const QString &key)
{
    const int row = indexOf(key);
    return row >= 0 && setValue(key, m_parameters.at(row).defaultValue);
}

bool ParameterList::resetAll()
{
    if (m_locked)
        return false;

    // Varsayılanlar birbirine uyar (aralıklara bakmadan hepsi birden döner); makine,
    // valueChanged ile her değeri kullanır ve aralıkları yeniden hesaplar.
    for (int row = 0; row < count(); ++row) {
        Parameter &p = m_parameters[row];
        if (p.value == p.defaultValue)
            continue;
        p.value = p.defaultValue;
        emit dataChanged(index(row), index(row), { ValueRole, ModifiedRole });
        bumpRevision();
        emit valueChanged(p.key, p.value);
    }
    return true;
}

void ParameterList::setRange(const QString &key, double minimum, double maximum)
{
    const int row = indexOf(key);
    if (row < 0)
        return;
    Parameter &p = m_parameters[row];
    if (p.minimum == minimum && p.maximum == maximum)
        return;
    p.minimum = minimum;
    p.maximum = maximum;
    emit dataChanged(index(row), index(row), { MinimumRole, MaximumRole });
    bumpRevision();
}

void ParameterList::setLocked(bool locked, const QString &reason)
{
    const QString newReason = locked ? reason : QString();
    if (m_locked == locked && m_lockReason == newReason)
        return;
    m_locked = locked;
    m_lockReason = newReason;
    emit lockedChanged();
}

void ParameterList::bumpRevision()
{
    ++m_revision;
    emit revisionChanged();
}
