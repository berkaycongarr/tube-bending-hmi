#include "AlarmList.h"

AlarmList::AlarmList(QObject *parent)
    : QAbstractListModel(parent)
{
}

int AlarmList::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : count();
}

QVariant AlarmList::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= count())
        return {};

    const Alarm &a = m_alarms.at(index.row());
    switch (role) {
    case CodeRole:
        return a.code;
    case TitleRole:
        return a.title;
    case DetailRole:
        return a.detail;
    case TimeRole:
        return a.time;
    case ClearedTimeRole:
        return a.clearedTime;
    case StateRole:
        return a.state;
    default:
        return {};
    }
}

QHash<int, QByteArray> AlarmList::roleNames() const
{
    return {
        { CodeRole, "code" },
        { TitleRole, "title" },
        { DetailRole, "detail" },
        { TimeRole, "time" },
        { ClearedTimeRole, "clearedTime" },
        { StateRole, "alarmState" }, // "state" QML'de Item'ın kendi özelliğidir
    };
}

int AlarmList::unresolved() const
{
    int total = 0;
    for (const Alarm &a : m_alarms)
        total += a.state == Cleared ? 0 : 1;
    return total;
}

bool AlarmList::canReset() const
{
    for (const Alarm &a : m_alarms) {
        if (a.state == Latched)
            return true;
    }
    return false;
}

const AlarmList::Alarm *AlarmList::newest() const
{
    // Liste en yeniden eskiye doğru: ilk silinmemiş kayıt en yenisidir.
    for (const Alarm &a : m_alarms) {
        if (a.state != Cleared)
            return &a;
    }
    return nullptr;
}

int AlarmList::indexOfUnresolved(const QString &code) const
{
    for (int i = 0; i < count(); ++i) {
        if (m_alarms.at(i).code == code && m_alarms.at(i).state != Cleared)
            return i;
    }
    return -1;
}

void AlarmList::raise(const QString &code, const QString &title, const QString &detail,
                      bool persistent)
{
    // Aynı arıza zaten duruyorsa listeyi şişirmeyiz; yalnızca sebebi yeniden oluştuysa
    // (ör. acil stop bırakılıp yeniden basıldıysa) durumu güncellenir.
    const int existing = indexOfUnresolved(code);
    if (existing >= 0) {
        if (persistent && m_alarms.at(existing).state != Active) {
            m_alarms[existing].state = Active;
            const QModelIndex changedRow = index(existing);
            emit dataChanged(changedRow, changedRow, { StateRole });
            emit changed();
        }
        return;
    }

    Alarm alarm;
    alarm.code = code;
    alarm.title = title;
    alarm.detail = detail;
    alarm.time = QDateTime::currentDateTime();
    alarm.state = persistent ? Active : Latched;

    beginInsertRows(QModelIndex(), 0, 0);
    m_alarms.prepend(alarm);
    endInsertRows();
    trim();
    emit changed();
}

void AlarmList::setCondition(const QString &code, bool present)
{
    const int row = indexOfUnresolved(code);
    if (row < 0)
        return;

    const State state = present ? Active : Latched;
    if (m_alarms.at(row).state == state)
        return;

    m_alarms[row].state = state;
    const QModelIndex changedRow = index(row);
    emit dataChanged(changedRow, changedRow, { StateRole });
    emit changed();
}

int AlarmList::reset()
{
    // Yalnızca sebebi geçmiş arızalar silinir. Sebebi süren arıza listede kalır:
    // önce sebep giderilmelidir.
    int cleared = 0;
    const QDateTime now = QDateTime::currentDateTime();
    for (int row = 0; row < count(); ++row) {
        if (m_alarms.at(row).state != Latched)
            continue;
        m_alarms[row].state = Cleared;
        m_alarms[row].clearedTime = now;
        const QModelIndex changedRow = index(row);
        emit dataChanged(changedRow, changedRow, { StateRole, ClearedTimeRole });
        ++cleared;
    }

    if (cleared > 0)
        emit changed();
    return cleared;
}

void AlarmList::trim()
{
    // Geçmiş sınırsız büyümez; en eski silinmiş kayıtlar atılır. Silinmemiş arıza atılmaz.
    while (count() > MaximumAlarms && m_alarms.last().state == Cleared) {
        beginRemoveRows(QModelIndex(), count() - 1, count() - 1);
        m_alarms.removeLast();
        endRemoveRows();
    }
}
