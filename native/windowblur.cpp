// SPDX-License-Identifier: GPL-2.0-or-later
#include "windowblur.h"

#include <KWindowEffects>
#include <QEvent>
#include <QPainterPath>
#include <QRegion>
#include <QTimer>

WindowBlur::WindowBlur(QObject *parent)
    : QObject(parent)
{
}

WindowBlur::~WindowBlur()
{
    if (m_window) {
        m_window->removeEventFilter(this);
        KWindowEffects::enableBlurBehind(m_window, false);
    }
}

bool WindowBlur::isAvailable() const
{
    return KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind);
}

void WindowBlur::setWindow(QWindow *window)
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
        connect(m_window, &QWindow::visibleChanged, this, &WindowBlur::scheduleApply);
        connect(m_window, &QWindow::widthChanged, this, &WindowBlur::scheduleApply);
        connect(m_window, &QWindow::heightChanged, this, &WindowBlur::scheduleApply);
    }
    Q_EMIT windowChanged();
    Q_EMIT availableChanged();
    scheduleApply();
}

void WindowBlur::setRegion(const QRectF &region)
{
    if (m_region == region) {
        return;
    }
    m_region = region;
    Q_EMIT regionChanged();
    scheduleApply();
}

void WindowBlur::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius)) {
        return;
    }
    m_radius = radius;
    Q_EMIT radiusChanged();
    scheduleApply();
}

void WindowBlur::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
    scheduleApply();
}

bool WindowBlur::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_window && (event->type() == QEvent::Expose || event->type() == QEvent::PlatformSurface || event->type() == QEvent::Show)) {
        scheduleApply();
    }
    return QObject::eventFilter(watched, event);
}

// Coalesce the many property changes of one animation frame into one request,
// and run after Plasma's own Dialog code (which may reset the blur).
void WindowBlur::scheduleApply()
{
    if (m_pending) {
        return;
    }
    m_pending = true;
    QTimer::singleShot(0, this, &WindowBlur::apply);
}

void WindowBlur::apply()
{
    m_pending = false;
    if (!m_window || !m_window->isVisible()) {
        return;
    }
    if (!m_enabled || m_region.isEmpty()) {
        KWindowEffects::enableBlurBehind(m_window, false);
        return;
    }
    QPainterPath path;
    const qreal r = qMin(m_radius, qMin(m_region.width(), m_region.height()) / 2.0);
    path.addRoundedRect(m_region.adjusted(0.5, 0.5, -0.5, -0.5), r, r);
    const QRegion region(path.toFillPolygon().toPolygon());
    KWindowEffects::enableBlurBehind(m_window, true, region);
}
