// SPDX-License-Identifier: GPL-2.0-or-later
#include "audiolevels.h"

#include <QStandardPaths>

#include <algorithm>
#include <cmath>

namespace
{
constexpr int Rate = 8000;
constexpr int FrameSamples = 256;       // 32 ms
constexpr float BassCutoff = 150.0f;    // Hz
// one-pole low-pass coefficient for the cutoff at this rate
const float BassAlpha = 1.0f - std::exp(-2.0f * float(M_PI) * BassCutoff / Rate);
constexpr float PeakFall = 0.997f;      // per frame: about -0.8 dB/s
constexpr float PeakFloor = 0.004f;     // below this the signal counts as silence
constexpr float Attack = 0.65f, Release = 0.18f;
constexpr int FirstRetry = 2000, LastRetry = 5 * 60000;     // ms
constexpr int Settled = 10000;                               // a pw-record that lived this long had something to record
}

AudioLevels::AudioLevels(QObject *parent)
    : QObject(parent)
{
    m_retry.setSingleShot(true);
    connect(&m_retry, &QTimer::timeout, this, &AudioLevels::start);
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &AudioLevels::read);
    connect(&m_process, &QProcess::stateChanged, this, &AudioLevels::runningChanged);
    // The output went away (sink changed, PipeWire restarted): try again. One that ends at once has
    // no PipeWire to record from: tried ever more rarely, not every two seconds while music plays.
    connect(&m_process, &QProcess::finished, this, [this] {
        reset();
        if (!m_active) return;
        if (m_lifetime.isValid() && m_lifetime.elapsed() >= Settled) m_retryDelay = FirstRetry;
        m_retry.start(m_retryDelay);
        m_retryDelay = qMin(m_retryDelay * 2, LastRetry);
    });
    m_process.setProcessChannelMode(QProcess::SeparateChannels);
    m_process.setStandardErrorFile(QProcess::nullDevice());
}

AudioLevels::~AudioLevels()
{
    m_active = false;
    stop();
}

void AudioLevels::setActive(bool active)
{
    if (m_active == active) return;
    m_active = active;
    if (active) start(); else stop();
    Q_EMIT activeChanged();
}

void AudioLevels::setTarget(const QString &target)
{
    if (m_target == target) return;
    m_target = target;
    if (m_active) { stop(); start(); }
    Q_EMIT targetChanged();
}

void AudioLevels::start()
{
    if (!m_active || isRunning()) return;
    const QString program = QStandardPaths::findExecutable(QStringLiteral("pw-record"));
    if (program.isEmpty()) return;
    QStringList args = {QStringLiteral("--raw"), QStringLiteral("--rate"), QString::number(Rate),
                        QStringLiteral("--channels"), QStringLiteral("1"), QStringLiteral("--format"), QStringLiteral("f32"),
                        QStringLiteral("--latency"), QStringLiteral("32ms"),
                        QStringLiteral("-P"),
                        QStringLiteral("{ stream.capture.sink = true node.passive = true node.name = dynamic-island-levels "
                                       "media.name = \"Dynamic Island glow\" application.name = \"Dynamic Island\" }")};
    if (!m_target.isEmpty()) args << QStringLiteral("--target") << m_target;
    args << QStringLiteral("-");
    reset();
    m_lifetime.start();
    m_process.start(program, args, QIODevice::ReadOnly);
}

void AudioLevels::stop()
{
    m_retry.stop();
    m_retryDelay = FirstRetry;
    if (isRunning()) {
        m_process.terminate();
        if (!m_process.waitForFinished(300)) m_process.kill();
    }
    reset();
}

void AudioLevels::reset()
{
    m_pending.clear();
    m_lp1 = m_lp2 = 0;
    m_sumAll = m_sumBass = 0;
    m_frame = 0;
    m_peakAll = m_peakBass = 0.02f;
    m_bassAverage = 0;
    m_sinceBeat.invalidate();
    if (m_level != 0 || m_bass != 0) {
        m_level = m_bass = 0;
        Q_EMIT levelsChanged();
    }
}

void AudioLevels::read()
{
    m_pending += m_process.readAllStandardOutput();
    const int whole = int(m_pending.size() / sizeof(float));
    if (whole == 0) return;
    analyse(reinterpret_cast<const float *>(m_pending.constData()), whole);
    m_pending.remove(0, whole * int(sizeof(float)));
}

void AudioLevels::analyse(const float *samples, int count)
{
    for (int i = 0; i < count; ++i) {
        const float x = samples[i];
        m_lp1 += BassAlpha * (x - m_lp1);
        m_lp2 += BassAlpha * (m_lp1 - m_lp2);
        m_sumAll += double(x) * x;
        m_sumBass += double(m_lp2) * m_lp2;
        if (++m_frame < FrameSamples) continue;

        const float rmsAll = float(std::sqrt(m_sumAll / FrameSamples));
        const float rmsBass = float(std::sqrt(m_sumBass / FrameSamples));
        m_sumAll = m_sumBass = 0;
        m_frame = 0;

        // automatic gain: a peak that follows rises at once and falls slowly
        m_peakAll = std::max({rmsAll, m_peakAll * PeakFall, PeakFloor});
        m_peakBass = std::max({rmsBass, m_peakBass * PeakFall, PeakFloor});
        const bool silent = rmsAll < PeakFloor * 0.25f;
        const qreal level = silent ? 0 : std::min(1.0f, rmsAll / m_peakAll);
        const qreal bass = silent ? 0 : std::min(1.0f, rmsBass / m_peakBass);
        m_level += (level > m_level ? Attack : Release) * (level - m_level);
        m_bass += (bass > m_bass ? Attack : Release) * (bass - m_bass);
        Q_EMIT levelsChanged();

        // a bass hit: well above the last ~0.6 s, not too soon after the previous one
        const float average = m_bassAverage;
        m_bassAverage += 0.05f * (rmsBass - m_bassAverage);
        if (!silent && average > 0 && rmsBass > average * 1.45f && rmsBass > m_peakBass * 0.45f
            && (!m_sinceBeat.isValid() || m_sinceBeat.elapsed() > 180)) {
            m_sinceBeat.restart();
            Q_EMIT beat(std::min(1.0, qreal(rmsBass / (average * 2.5f))));
        }
    }
}
