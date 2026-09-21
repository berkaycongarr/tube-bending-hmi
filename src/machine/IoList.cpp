#include "IoList.h"

IoList::IoList(QObject *parent)
    : QAbstractListModel(parent)
{
}

int IoList::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : count();
}

QVariant IoList::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= count())
        return {};

    const Point &p = m_points.at(index.row());
    switch (role) {
    case AddressRole:
        return p.address;
    case NameRole:
        return p.name;
    case NoteRole:
        return p.note;
    case ActiveRole:
        return p.active;
    case LockRole:
        return p.lock;
    default:
        return {};
    }
}

QHash<int, QByteArray> IoList::roleNames() const
{
    return {
        { AddressRole, "address" },
        { NameRole, "name" },
        { NoteRole, "note" },
        { ActiveRole, "active" },
        { LockRole, "lock" },
    };
}

void IoList::add(const QString &address, const QString &name, const QString &note)
{
    beginInsertRows(QModelIndex(), count(), count());
    m_points.append({ address, name, note, false, QString() });
    endInsertRows();
    emit countChanged();
}

int IoList::indexOf(const QString &address) const
{
    for (int i = 0; i < count(); ++i) {
        if (m_points.at(i).address == address)
            return i;
    }
    return -1;
}

bool IoList::isActive(const QString &address) const
{
    const int row = indexOf(address);
    return row >= 0 && m_points.at(row).active;
}

QString IoList::lock(const QString &address) const
{
    const int row = indexOf(address);
    return row >= 0 ? m_points.at(row).lock : QString();
}

void IoList::setActive(const QString &address, bool active)
{
    const int row = indexOf(address);
    if (row < 0 || m_points.at(row).active == active)
        return;
    m_points[row].active = active;
    emit dataChanged(index(row), index(row), { ActiveRole });
}

void IoList::setLock(const QString &address, const QString &lock)
{
    const int row = indexOf(address);
    if (row < 0 || m_points.at(row).lock == lock)
        return;
    m_points[row].lock = lock;
    emit dataChanged(index(row), index(row), { LockRole });
}
