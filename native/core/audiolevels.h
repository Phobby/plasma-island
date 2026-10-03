// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QByteArray>
#include <QElapsedTimer>
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

/*
 * How loud the music is right now, and its bass, for the island's ambient
 * glow. Reads what goes to the speakers: `pw-record` captures the default
 * output's monitor (stream.capture.sink) as raw 32-bit float, mono, 8 kHz,
 * so no libpipewire headers are needed and only ~32 KB/s go through a pipe.
 * Nothing runs while `active` is false: the process is stopped.
 *
 * Every 32 ms (256 samples):
 *   level - RMS of the signal
 *   bass  - RMS after two one-pole low-pass filters at 150 Hz (12 dB/oct):
 *           kick drums and bass lines, cheaper than an FFT and enough here
 * Both are divided by a slowly falling peak (automatic gain), so a quiet
 * track moves as much as a loud one, and smoothed (fast attack, slower
 * release). `beat` fires when the bass jumps well above its recent average.
 */
class AudioLevels : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged)
    // A sink name or serial to listen to; empty = the default output.
    Q_PROPERTY(QString target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(qreal level READ level NOTIFY levelsChanged)
    Q_PROPERTY(qreal bass READ bass NOTIFY levelsChanged)

public:
    explicit AudioLevels(QObject *parent = nullptr);
    ~AudioLevels() override;

    bool isActive() const { return m_active; }
    void setActive(bool active);
    QString target() const { return m_target; }
    void setTarget(const QString &target);
    bool isRunning() const { return m_process.state() != QProcess::NotRunning; }
    qreal level() const { return m_level; }
    qreal bass() const { return m_bass; }

Q_SIGNALS:
    void activeChanged();
    void targetChanged();
    void runningChanged();
    void levelsChanged();
    // A bass hit; strength 0..1.
    void beat(qreal strength);

private:
    void start();
    void stop();
    void read();
    void analyse(const float *samples, int count);
    void reset();

    QProcess m_process;
    QTimer m_retry;
    QElapsedTimer m_sinceBeat;
    QByteArray m_pending;
    QString m_target;
    bool m_active = false;

    // filter and analysis state
    float m_lp1 = 0, m_lp2 = 0;
    double m_sumAll = 0, m_sumBass = 0;
    int m_frame = 0;
    float m_peakAll = 0.02f, m_peakBass = 0.02f, m_bassAverage = 0;
    qreal m_level = 0, m_bass = 0;
};
