// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QWindow>
#include <QtQml/qqmlregistration.h>

/*
 * WindowScreen puts a window that is not shown yet on a screen, by the
 * screen's name. For a layer-shell surface (LayerShellQt, the notch's window)
 * that is not done by the window's own screen: LayerShellQt takes the screen
 * from its attached object's `screen`, a QScreen* that QML cannot hand over.
 * That object is found among the window's children by its class name, so
 * nothing of LayerShellQt is needed to build this.
 */
class WindowScreen : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit WindowScreen(QObject *parent = nullptr);

    // false: there is no screen of that name (the window is left as it was).
    Q_INVOKABLE bool place(QWindow *window, const QString &screenName);
};
