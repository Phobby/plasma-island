/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Sends a wheel step to the window of an item, with everything a touchpad
    puts into one: pixels as well as the angle, and the phase of the scroll
    (Qt.ScrollBegin, ScrollUpdate, ScrollEnd, ScrollMomentum; Qt.NoScrollPhase
    is a mouse's wheel).
*/
#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QQuickItem>
#include <qqmlregistration.h>

class WheelSender : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit WheelSender(QObject *parent = nullptr);

    // At (x, y) of `item`. True when something accepted the step.
    Q_INVOKABLE bool send(QQuickItem *item, qreal x, qreal y, int pixelX, int pixelY, int angleX, int angleY, int phase);

private:
    QElapsedTimer m_clock;
};
