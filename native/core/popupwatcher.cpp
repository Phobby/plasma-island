// SPDX-License-Identifier: GPL-2.0-or-later
#include "popupwatcher.h"

#include <QGuiApplication>
#include <QWindow>

PopupWatcher::PopupWatcher(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(150);
    connect(&m_timer, &QTimer::timeout, this, &PopupWatcher::check);
}

void PopupWatcher::setActive(bool active)
{
    if (m_active == active) return;
    m_active = active;
    if (active) {
        m_timer.start();
        check();
    } else {
        m_timer.stop();
        if (m_open) {
            m_open = false;
            Q_EMIT openChanged();
        }
    }
    Q_EMIT activeChanged();
}

void PopupWatcher::check()
{
    bool open = false;
    const auto windows = QGuiApplication::topLevelWindows();
    for (const QWindow *w : windows) {
        if (w->isVisible() && w->type() == Qt::Popup) {
            open = true;
            break;
        }
    }
    if (open != m_open) {
        m_open = open;
        Q_EMIT openChanged();
    }
}
