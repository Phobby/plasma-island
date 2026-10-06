// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QDBusContext>
#include <QDBusObjectPath>
#include <QHash>
#include <QObject>
#include <QTimer>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

/*
 * Installs and updates made through PackageKit (Discover, the update
 * notifier's "install updates"): the daemon says how far a transaction is on
 * the system bus (org.freedesktop.PackageKit.Transaction: Percentage, Speed,
 * RemainingTime), so these have an exact percentage. Only read: nothing is
 * started, cancelled or asked of the daemon beyond its list of transactions
 * and their properties, and the daemon is never started from here.
 *
 * Shown: installing, updating, downloading packages, a system upgrade.
 * Not shown unless `showBackground`: refreshing the package lists and
 * transactions that only download (the notifier preparing an update).
 * Simulations and queries are never shown.
 */
class PackageKitWatcher : public QObject, protected QDBusContext
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool showBackground MEMBER m_showBackground NOTIFY showBackgroundChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit PackageKitWatcher(QObject *parent = nullptr);

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    int count() const { return m_shown.size(); }

Q_SIGNALS:
    void enabledChanged();
    void showBackgroundChanged();
    void countChanged();
    // info: { action: "install" | "update" | "download" | "upgrade" | "refresh", background (bool) }
    void started(const QString &id, const QVariantMap &info);
    // percent: 0..100, or -1 (not known). remaining: seconds, 0 = not known. stage: "" | "download" | "install"
    void progress(const QString &id, int percent, qint64 speed, int remaining, const QString &stage);
    // outcome: "done" | "failed" | "cancelled" | "unknown"
    void finished(const QString &id, const QString &outcome);

private Q_SLOTS:
    void listChanged(const QStringList &paths);
    void transactionFinished(uint exit, uint runtime);

private:
    void poll();
    void look(const QString &path);

    bool m_enabled = false;
    bool m_showBackground = false;
    QStringList m_paths;                // the daemon's transactions
    QHash<QString, QString> m_shown;    // path → id
    quint64 m_next = 1;
    QTimer m_timer;
};
