// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QPointer>
#include <QtQml/qqmlregistration.h>

/*
 * Drags a file of this computer out of the island, to the desktop or a file
 * manager (the Cloud tab: a file fetched into its cache).
 *
 * QML's own Drag with a binding on Drag.active crashed plasmashell: the
 * binding ran again inside the drag's own event loop, the drag's data went
 * away, and the program the file was dropped on then asked for it. Here the
 * drag is one object made for one drag, started after the mouse handler has
 * returned, and it owns its data until the drop is over.
 */
class FileDrag : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

public:
    explicit FileDrag(QObject *parent = nullptr);

    bool active() const;
    // Starts dragging `path` (a regular file that exists) from `source`; false if one is running or there is no such file.
    Q_INVOKABLE bool start(QObject *source, const QString &path, const QString &iconName = QString());

Q_SIGNALS:
    void activeChanged();
    // dropped: somebody took it
    void finished(bool dropped);

private:
    bool m_active = false;
};
