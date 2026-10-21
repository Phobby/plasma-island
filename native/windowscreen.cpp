// SPDX-License-Identifier: GPL-2.0-or-later
#include "windowscreen.h"

#include <QGuiApplication>
#include <QScreen>

WindowScreen::WindowScreen(QObject *parent)
    : QObject(parent)
{
}

bool WindowScreen::place(QWindow *window, const QString &screenName)
{
    if (!window) {
        return false;
    }
    QScreen *target = nullptr;
    const auto screens = QGuiApplication::screens();
    for (QScreen *screen : screens) {
        if (screen->name() == screenName) {
            target = screen;
            break;
        }
    }
    if (!target) {
        return false;
    }
    // (Qt picks a shown window's screen again by its position: that too on the target)
    window->setPosition(target->geometry().topLeft());
    window->setScreen(target);
    const auto children = window->children();
    for (QObject *child : children) {
        if (qstrcmp(child->metaObject()->className(), "LayerShellQt::Window") == 0) {
            child->setProperty("screen", QVariant::fromValue(target));
        }
    }
    return true;
}
