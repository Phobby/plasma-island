// SPDX-License-Identifier: GPL-2.0-or-later
#include "pipewirewatcher.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QSet>
#include <QStandardPaths>

PipeWireWatcher::PipeWireWatcher(QObject *parent)
    : QObject(parent)
{
    m_recompute.setSingleShot(true);
    m_recompute.setInterval(120);
    connect(&m_recompute, &QTimer::timeout, this, &PipeWireWatcher::recompute);

    // pw-dump exits if PipeWire restarts: come back after a short delay.
    m_restart.setSingleShot(true);
    m_restart.setInterval(3000);
    connect(&m_restart, &QTimer::timeout, this, &PipeWireWatcher::start);

    connect(&m_process, &QProcess::readyReadStandardOutput, this, &PipeWireWatcher::readOutput);
    connect(&m_process, &QProcess::stateChanged, this, &PipeWireWatcher::runningChanged);
    connect(&m_process, &QProcess::finished, this, [this] {
        m_objects.clear();
        m_buffer.clear();
        m_chunk.clear();
        recompute();
        if (m_enabled) {
            m_restart.start();
        }
    });
    QTimer::singleShot(0, this, &PipeWireWatcher::start);
}

PipeWireWatcher::~PipeWireWatcher()
{
    m_enabled = false;
    stop();
}

void PipeWireWatcher::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
    enabled ? start() : stop();
}

void PipeWireWatcher::start()
{
    if (!m_enabled || m_process.state() != QProcess::NotRunning) {
        return;
    }
    const QString exe = QStandardPaths::findExecutable(QStringLiteral("pw-dump"));
    if (exe.isEmpty()) {
        qWarning("PipeWireWatcher: pw-dump not found, privacy indicators disabled");
        return;
    }
    m_process.setProcessChannelMode(QProcess::ForwardedErrorChannel);
    m_process.start(exe, {QStringLiteral("--monitor"), QStringLiteral("--no-colors")});
}

void PipeWireWatcher::stop()
{
    m_restart.stop();
    if (m_process.state() != QProcess::NotRunning) {
        m_process.disconnect(this);
        m_process.kill();
        m_process.waitForFinished(500);
        connect(&m_process, &QProcess::readyReadStandardOutput, this, &PipeWireWatcher::readOutput);
        connect(&m_process, &QProcess::stateChanged, this, &PipeWireWatcher::runningChanged);
    }
    m_objects.clear();
    recompute();
}

// Output is a stream of pretty-printed JSON arrays; each starts with a "["
// line and ends with a "]" line at column 0.
void PipeWireWatcher::readOutput()
{
    m_buffer += m_process.readAllStandardOutput();
    int nl;
    while ((nl = m_buffer.indexOf('\n')) >= 0) {
        const QByteArray line = m_buffer.left(nl);
        m_buffer.remove(0, nl + 1);
        if (line == "[") {
            m_chunk = "[";
        } else if (line == "]") {
            m_chunk += "]";
            applyChunk(m_chunk);
            m_chunk.clear();
        } else if (!m_chunk.isEmpty()) {
            m_chunk += line;
            m_chunk += '\n';
        }
    }
}

void PipeWireWatcher::applyChunk(const QByteArray &json)
{
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray()) {
        return;
    }
    for (const QJsonValue &v : doc.array()) {
        const QJsonObject o = v.toObject();
        const int id = o.value(QStringLiteral("id")).toInt(-1);
        if (id < 0) {
            continue;
        }
        const QJsonValue infoValue = o.value(QStringLiteral("info"));
        if (infoValue.isNull()) { // removed
            m_objects.remove(id);
            continue;
        }
        Object &obj = m_objects[id];
        const QString type = o.value(QStringLiteral("type")).toString();
        if (!type.isEmpty()) {
            obj.type = type;
        }
        const QJsonObject info = infoValue.toObject();
        if (info.contains(QStringLiteral("props"))) {
            obj.props = info.value(QStringLiteral("props")).toObject();
        }
        if (info.contains(QStringLiteral("state"))) {
            obj.state = info.value(QStringLiteral("state")).toString();
        }
        if (info.contains(QStringLiteral("output-node-id"))) {
            obj.outputNode = info.value(QStringLiteral("output-node-id")).toInt(-1);
            obj.inputNode = info.value(QStringLiteral("input-node-id")).toInt(-1);
        }
    }
    m_recompute.start();
}

QString PipeWireWatcher::appNameOf(int nodeId) const
{
    const auto it = m_objects.constFind(nodeId);
    if (it == m_objects.constEnd()) {
        return {};
    }
    QString name = it->props.value(QStringLiteral("application.name")).toString();
    if (name.isEmpty()) {
        const int client = it->props.value(QStringLiteral("client.id")).toInt(-1);
        const auto c = m_objects.constFind(client);
        if (c != m_objects.constEnd()) {
            name = c->props.value(QStringLiteral("application.name")).toString();
        }
    }
    if (name.isEmpty()) {
        name = it->props.value(QStringLiteral("node.description")).toString();
    }
    return name;
}

static QString binaryOf(const QJsonObject &props)
{
    return props.value(QStringLiteral("application.process.binary")).toString();
}

void PipeWireWatcher::recompute()
{
    QSet<QString> mic, camera, screen;
    const QString nodeType = QStringLiteral("PipeWire:Interface:Node");
    const QString linkType = QStringLiteral("PipeWire:Interface:Link");
    const QString runningState = QStringLiteral("running");

    for (auto it = m_objects.constBegin(); it != m_objects.constEnd(); ++it) {
        if (it->type != linkType) {
            continue;
        }
        const auto out = m_objects.constFind(it->outputNode);
        const auto in = m_objects.constFind(it->inputNode);
        if (out == m_objects.constEnd() || in == m_objects.constEnd() || out->type != nodeType || in->type != nodeType) {
            continue;
        }
        const QString outClass = out->props.value(QStringLiteral("media.class")).toString();
        const QString inClass = in->props.value(QStringLiteral("media.class")).toString();
        const bool consumerRunning = in->state == runningState;
        if (!consumerRunning) {
            continue;
        }
        // The consumer's client binary (to skip Plasma's own thumbnails/meters).
        QString binary = binaryOf(in->props);
        if (binary.isEmpty()) {
            const auto c = m_objects.constFind(in->props.value(QStringLiteral("client.id")).toInt(-1));
            if (c != m_objects.constEnd()) {
                binary = binaryOf(c->props);
            }
        }
        const bool fromPlasma = binary == QLatin1String("plasmashell") || binary == QLatin1String("kwin_wayland");

        if (outClass == QLatin1String("Audio/Source") && inClass.startsWith(QLatin1String("Stream/Input/Audio"))) {
            if (!fromPlasma) {
                mic.insert(appNameOf(it->inputNode));
            }
        } else if ((outClass == QLatin1String("Video/Source") || outClass == QLatin1String("Stream/Output/Video"))
                   && !inClass.startsWith(QLatin1String("Stream/Output"))) {
            const bool device = out->props.contains(QStringLiteral("device.api")) || out->props.contains(QStringLiteral("device.id"));
            const QString app = appNameOf(it->inputNode);
            if (device) {
                camera.insert(app);
            } else if (!fromPlasma) {
                screen.insert(app);
            }
        }
    }

    auto sorted = [](const QSet<QString> &set) {
        QStringList list(set.cbegin(), set.cend());
        list.removeAll(QString());
        list.sort(Qt::CaseInsensitive);
        return list;
    };
    const QStringList newMic = sorted(mic), newCamera = sorted(camera), newScreen = sorted(screen);
    if (newMic != m_mic || newCamera != m_camera || newScreen != m_screen) {
        m_mic = newMic;
        m_camera = newCamera;
        m_screen = newScreen;
        Q_EMIT usageChanged();
    }
}
