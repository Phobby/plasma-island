// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

/*
 * Number of pending system updates from PackageKit's cache (the same data
 * Discover's notifier uses; no network refresh is triggered). Rechecks when
 * PackageKit emits UpdatesChanged and every `interval` minutes.
 */
class UpdatesChecker : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(int interval MEMBER m_intervalMinutes NOTIFY intervalChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int securityCount READ securityCount NOTIFY countChanged)
    Q_PROPERTY(bool available READ isAvailable NOTIFY availableChanged)

public:
    explicit UpdatesChecker(QObject *parent = nullptr);

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    int count() const { return m_count; }
    int securityCount() const { return m_security; }
    bool isAvailable() const { return m_available; }

    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void enabledChanged();
    void intervalChanged();
    void countChanged();
    void availableChanged();

private Q_SLOTS:
    void onPackage(uint info, const QString &packageId, const QString &summary);
    void onFinished(uint exit, uint runtime);
    void onUpdatesChanged();

private:
    void setAvailable(bool available);

    bool m_enabled = true;
    bool m_available = false;
    bool m_running = false;
    int m_intervalMinutes = 180;
    int m_count = 0, m_security = 0;
    int m_pending = 0, m_pendingSecurity = 0;
    QString m_transaction;
    QTimer m_timer;
};
