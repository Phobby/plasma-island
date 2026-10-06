// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QElapsedTimer>
#include <QProcess>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

/*
 * Watches the PipeWire graph through `pw-dump --monitor` (event driven, no
 * polling, no libpipewire headers needed) and reports who uses:
 *   - a microphone : running Stream/Input/Audio linked from an Audio/Source
 *   - a camera     : device Video/Source (v4l2/libcamera) with running consumers
 *   - the screen   : non-device video source (KWin/portal screencast) with
 *                    running consumers, except plasmashell's own window
 *                    thumbnails
 */
class PipeWireWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(QStringList microphoneApps READ microphoneApps NOTIFY usageChanged)
    Q_PROPERTY(QStringList cameraApps READ cameraApps NOTIFY usageChanged)
    Q_PROPERTY(QStringList screenCastApps READ screenCastApps NOTIFY usageChanged)

public:
    explicit PipeWireWatcher(QObject *parent = nullptr);
    ~PipeWireWatcher() override;

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    bool isRunning() const { return m_process.state() == QProcess::Running; }
    QStringList microphoneApps() const { return m_mic; }
    QStringList cameraApps() const { return m_camera; }
    QStringList screenCastApps() const { return m_screen; }

Q_SIGNALS:
    void enabledChanged();
    void runningChanged();
    void usageChanged();

private:
    void start();
    void stop();
    void ended();
    void readOutput();
    void applyChunk(const QByteArray &json);
    void recompute();
    QString appNameOf(int nodeId) const;

    struct Object {
        QString type;
        QJsonObject props;
        QString state;
        int outputNode = -1; // links only
        int inputNode = -1;
    };

    bool m_enabled = true;
    QProcess m_process;
    QByteArray m_buffer;
    QByteArray m_chunk;
    QHash<int, Object> m_objects;
    QTimer m_recompute;
    QTimer m_restart;
    QElapsedTimer m_lifetime; // of the running pw-dump
    int m_retryDelay = 0;     // ms until it is started again
    QStringList m_mic, m_camera, m_screen;
};
