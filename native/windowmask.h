// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QVariantList>
#include <QWindow>
#include <QtQml/qqmlregistration.h>

/*
 * WindowMask makes `window` take the pointer only where the island is drawn:
 * a rounded rectangle (the pill, the card, the dot), when there is one the
 * split island's bubble, and any number of further shapes (the companion's
 * body: ellipses). Everywhere else in the window (the room for the shadow,
 * for the morph's overshoot, for the larger states, around the companion and
 * over its bubble) a click goes to whatever is underneath.
 *
 * It is QWindow::setMask(): on Wayland that is the surface's input region
 * (nothing is clipped from what is drawn), on X11 the window's shape. Plasma's
 * Dialog sets a mask of its own when it is shown or resized, so this one is
 * put back after those.
 */
class WindowMask : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QWindow *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(QRectF region READ region WRITE setRegion NOTIFY regionChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(QRectF region2 READ region2 WRITE setRegion2 NOTIFY region2Changed)
    // Further shapes that take the pointer: a list of rectangles, each the box of an ellipse.
    Q_PROPERTY(QVariantList shapes READ shapes WRITE setShapes NOTIFY shapesChanged)
    // false: the whole window takes the pointer, as without this helper.
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    // DYNAMICISLAND_DEBUG_REGION is set: the island draws the region's outline.
    Q_PROPERTY(bool debug READ debug CONSTANT)
    // How often the region was handed to the window (for measuring).
    Q_PROPERTY(int applied READ applied NOTIFY appliedChanged)

public:
    explicit WindowMask(QObject *parent = nullptr);
    ~WindowMask() override;

    QWindow *window() const { return m_window; }
    void setWindow(QWindow *window);
    QRectF region() const { return m_region; }
    void setRegion(const QRectF &region);
    qreal radius() const { return m_radius; }
    void setRadius(qreal radius);
    QRectF region2() const { return m_region2; }
    void setRegion2(const QRectF &region);
    QVariantList shapes() const { return m_shapes; }
    void setShapes(const QVariantList &shapes);
    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    bool debug() const;
    int applied() const { return m_applied; }

Q_SIGNALS:
    void windowChanged();
    void regionChanged();
    void radiusChanged();
    void region2Changed();
    void shapesChanged();
    void enabledChanged();
    void appliedChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void scheduleApply();
    void apply();

    QPointer<QWindow> m_window;
    QRectF m_region;
    qreal m_radius = 0;
    QRectF m_region2;
    QVariantList m_shapes;
    bool m_enabled = false;
    bool m_pending = false;
    int m_applied = 0;
};
