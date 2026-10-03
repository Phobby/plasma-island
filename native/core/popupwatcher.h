// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

/*
 * Whether a popup menu of this process (plasmashell) is on screen, e.g. the
 * "open with" menu Klipper shows for a clipboard entry. QML gets no signal
 * when such a QMenu closes; while `active`, this looks at the process's
 * windows a few times a second and reports `open`.
 */
class PopupWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool open READ isOpen NOTIFY openChanged)

public:
    explicit PopupWatcher(QObject *parent = nullptr);

    bool active() const { return m_active; }
    void setActive(bool active);
    bool isOpen() const { return m_open; }

Q_SIGNALS:
    void activeChanged();
    void openChanged();

private:
    void check();

    QTimer m_timer;
    bool m_active = false;
    bool m_open = false;
};
