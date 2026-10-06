// SPDX-License-Identifier: GPL-2.0-or-later
#include "windowmask.h"

#include <QEvent>
#include <QPainterPath>
#include <QRegion>
#include <QTimer>

WindowMask::WindowMask(QObject *parent)
    : QObject(parent)
{
}

WindowMask::~WindowMask()
{
    if (m_window) {
        m_window->removeEventFilter(this);
        m_window->setMask(QRegion());
    }
}

bool WindowMask::debug() const
{
    return qEnvironmentVariableIsSet("DYNAMICISLAND_DEBUG_REGION");
}

void WindowMask::setWindow(QWindow *window)
{
    if (m_window == window) {
        return;
    }
    if (m_window) {
        m_window->removeEventFilter(this);
        disconnect(m_window, nullptr, this, nullptr);
    }
    m_window = window;
    if (m_window) {
        m_window->installEventFilter(this);
        connect(m_window, &QWindow::visibleChanged, this, &WindowMask::scheduleApply);
        connect(m_window, &QWindow::widthChanged, this, &WindowMask::scheduleApply);
        connect(m_window, &QWindow::heightChanged, this, &WindowMask::scheduleApply);
    }
    Q_EMIT windowChanged();
    scheduleApply();
}

void WindowMask::setRegion(const QRectF &region)
{
    if (m_region == region) {
        return;
    }
    m_region = region;
    Q_EMIT regionChanged();
    scheduleApply();
}

void WindowMask::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius)) {
        return;
    }
    m_radius = radius;
    Q_EMIT radiusChanged();
    scheduleApply();
}

void WindowMask::setRegion2(const QRectF &region)
{
    if (m_region2 == region) {
        return;
    }
    m_region2 = region;
    Q_EMIT region2Changed();
    scheduleApply();
}

void WindowMask::setShapes(const QVariantList &shapes)
{
    if (m_shapes == shapes) {
        return;
    }
    m_shapes = shapes;
    Q_EMIT shapesChanged();
    scheduleApply();
}

void WindowMask::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
    scheduleApply();
}

bool WindowMask::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_window && (event->type() == QEvent::Expose || event->type() == QEvent::PlatformSurface || event->type() == QEvent::Show || event->type() == QEvent::Resize)) {
        scheduleApply();
    }
    return QObject::eventFilter(watched, event);
}

// The many changes of one animation frame make one request, after Plasma's own Dialog code has run.
void WindowMask::scheduleApply()
{
    if (m_pending) {
        return;
    }
    m_pending = true;
    QTimer::singleShot(0, this, &WindowMask::apply);
}

void WindowMask::apply()
{
    m_pending = false;
    if (!m_window || !m_window->isVisible()) {
        return;
    }
    if (!m_enabled || m_region.isEmpty()) {
        m_window->setMask(QRegion());
        return;
    }
    QPainterPath path;
    path.setFillRule(Qt::WindingFill);
    const qreal r = qMin(m_radius, qMin(m_region.width(), m_region.height()) / 2.0);
    path.addRoundedRect(m_region, r, r);
    QRegion region(path.toFillPolygon().toPolygon());
    if (!m_region2.isEmpty()) {
        QPainterPath second;
        const qreal r2 = qMin(m_region2.width(), m_region2.height()) / 2.0;
        second.addRoundedRect(m_region2, r2, r2);
        region += QRegion(second.toFillPolygon().toPolygon());
    }
    for (const QVariant &shape : std::as_const(m_shapes)) {
        const QRectF box = shape.toRectF();
        if (box.width() < 1 || box.height() < 1) {
            continue;
        }
        QPainterPath ellipse;
        ellipse.addEllipse(box);
        region += QRegion(ellipse.toFillPolygon().toPolygon());
    }
    m_window->setMask(region);
    ++m_applied;
    Q_EMIT appliedChanged();
}
