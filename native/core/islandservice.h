// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

/*
 * Session bus API so any program can drive its own Live Activity:
 *
 *   service   org.phobby.DynamicIsland
 *   object    /org/phobby/DynamicIsland
 *   interface org.phobby.DynamicIsland
 *
 *   Push(s id, a{sv} props)     create or update a live activity
 *   Update(s id, a{sv} props)   same as Push
 *   Finish(s id, s status)      end it; status: success | error | cancel | ""
 *   Flash(a{sv} props)          one-off transient event
 *   List() -> as                ids of the activities pushed over D-Bus
 *   signal ActivityClicked(s id)
 *
 * props: title, subtitle, icon, progress (0-100, -1 = none), color (name or
 * #rrggbb), trailing, priority (int), category (timer | transfer | …),
 * timeout (seconds, auto-finish), duration (ms, Flash only)
 */
class IslandService : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_CLASSINFO("D-Bus Interface", "org.phobby.DynamicIsland")
    Q_PROPERTY(bool registered READ isRegistered NOTIFY registeredChanged)
    Q_PROPERTY(QStringList ids MEMBER m_ids NOTIFY idsChanged)

public:
    explicit IslandService(QObject *parent = nullptr);
    ~IslandService() override;

    bool isRegistered() const { return m_registered; }

    // Called from QML when the user clicks a D-Bus activity.
    Q_INVOKABLE void emitClicked(const QString &id);

public Q_SLOTS:
    Q_SCRIPTABLE void Push(const QString &id, const QVariantMap &properties);
    Q_SCRIPTABLE void Update(const QString &id, const QVariantMap &properties);
    Q_SCRIPTABLE void Finish(const QString &id, const QString &status);
    Q_SCRIPTABLE void Flash(const QVariantMap &properties);
    Q_SCRIPTABLE QStringList List();

Q_SIGNALS:
    Q_SCRIPTABLE void ActivityClicked(const QString &id);

    // To QML
    void pushed(const QString &id, const QVariantMap &properties);
    void finished(const QString &id, const QString &status);
    void flashed(const QVariantMap &properties);
    void registeredChanged();
    void idsChanged();

private:
    bool m_registered = false;
    QStringList m_ids;
};
