/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include "wheelsender.h"

#include <QCoreApplication>
#include <QPointingDevice>
#include <QQuickWindow>
#include <QWheelEvent>

WheelSender::WheelSender(QObject *parent)
    : QObject(parent)
{
    m_clock.start();
}

bool WheelSender::send(QQuickItem *item, qreal x, qreal y, int pixelX, int pixelY, int angleX, int angleY, int phase)
{
    if (!item || !item->window()) {
        return false;
    }
    QQuickWindow *window = item->window();
    const QPointF scene = item->mapToScene(QPointF(x, y));
    const QPoint pixels(pixelX, pixelY);
    QWheelEvent event(scene, window->mapToGlobal(scene), pixels, QPoint(angleX, angleY), Qt::NoButton, Qt::NoModifier,
                      Qt::ScrollPhase(phase), false,
                      pixels.isNull() ? Qt::MouseEventNotSynthesized : Qt::MouseEventSynthesizedBySystem,
                      QPointingDevice::primaryPointingDevice());
    event.setTimestamp(quint64(m_clock.elapsed()));
    event.setAccepted(false);
    QCoreApplication::sendEvent(window, &event);
    return event.isAccepted();
}
