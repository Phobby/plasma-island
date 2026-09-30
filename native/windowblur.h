// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QWindow>
#include <QtQml/qqmlregistration.h>

/*
 * WindowBlur asks KWin to blur a rounded rectangle behind `window`.
 * Re-applies itself whenever the window is (re)exposed, because Plasma's
 * Dialog resets the blur region on show / theme changes.
 */
class WindowBlur : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QWindow *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(QRectF region READ region WRITE setRegion NOTIFY regionChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    // Optional second shape (the split island's bubble), always a pill/circle.
    Q_PROPERTY(QRectF region2 READ region2 WRITE setRegion2 NOTIFY region2Changed)
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool available READ isAvailable NOTIFY availableChanged)

public:
    explicit WindowBlur(QObject *parent = nullptr);
    ~WindowBlur() override;

    QWindow *window() const { return m_window; }
    void setWindow(QWindow *window);
    QRectF region() const { return m_region; }
    void setRegion(const QRectF &region);
    qreal radius() const { return m_radius; }
    QRectF region2() const { return m_region2; }
    void setRegion2(const QRectF &region);
    void setRadius(qreal radius);
    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    bool isAvailable() const;

Q_SIGNALS:
    void windowChanged();
    void regionChanged();
    void radiusChanged();
    void region2Changed();
    void enabledChanged();
    void availableChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void scheduleApply();
    void apply();

    QPointer<QWindow> m_window;
    QRectF m_region;
    qreal m_radius = 0;
    QRectF m_region2;
    bool m_enabled = false;
    bool m_pending = false;
};
