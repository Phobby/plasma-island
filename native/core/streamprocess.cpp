// SPDX-License-Identifier: GPL-2.0-or-later
#include "streamprocess.h"
#include "userpaths.h"

#include <QDir>
#include <QFile>
#include <QTimer>

namespace
{
// A line longer than this is not an answer any more.
const qsizetype s_maxLine = 4 * 1024 * 1024;
const qsizetype s_maxErrors = 16 * 1024;
}

StreamProcess::StreamProcess(QObject *parent)
    : QObject(parent)
{
}

StreamProcess::~StreamProcess()
{
    if (m_process) {
        m_process->disconnect(this);
        m_process->kill();
        m_process->waitForFinished(1000);
    }
}

bool StreamProcess::running() const
{
    return m_process != nullptr;
}

qint64 StreamProcess::processId() const
{
    return m_process ? m_process->processId() : 0;
}

bool StreamProcess::start(const QString &program, const QStringList &arguments, const QString &input, const QString &workingDirectory)
{
    if (m_process || program.isEmpty() || workingDirectory.isEmpty()) {
        return false;
    }
    const QDir directory(workingDirectory);
    if (!directory.exists()) {
        if (!QDir().mkpath(directory.absolutePath())) {
            return false;
        }
        QFile::setPermissions(directory.absolutePath(), QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    }

    m_buffer.clear();
    m_errors.clear();
    m_stopped = false;
    m_process = new QProcess(this);
    m_process->setProgram(program);
    m_process->setArguments(arguments);
    m_process->setProcessEnvironment(UserPaths::environmentFor(program));
    m_process->setWorkingDirectory(directory.absolutePath());
    if (m_merge) {
        m_process->setProcessChannelMode(QProcess::MergedChannels);
    }

    connect(m_process, &QProcess::readyReadStandardOutput, this, &StreamProcess::read);
    connect(m_process, &QProcess::readyReadStandardError, this, [this] {
        if (m_merge) {
            return;
        }
        m_errors.append(m_process->readAllStandardError());
        if (m_errors.size() > s_maxErrors) {
            m_errors = m_errors.right(s_maxErrors);
        }
    });
    connect(m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        end(status == QProcess::NormalExit && !m_stopped ? code : -1);
    });
    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            end(-1);
        }
    });
    const QByteArray bytes = input.toUtf8();
    connect(m_process, &QProcess::started, this, [this, bytes] {
        m_process->write(bytes);
        m_process->closeWriteChannel();
    });
    m_process->start();
    Q_EMIT runningChanged();
    return true;
}

void StreamProcess::stop()
{
    if (!m_process || m_stopped) {
        return;
    }
    m_stopped = true;
    m_process->terminate();
    // One that does not listen is killed.
    QTimer::singleShot(1500, m_process, &QProcess::kill);
}

void StreamProcess::read()
{
    m_buffer.append(m_process->readAllStandardOutput());
    QStringList complete;
    qsizetype from = 0;
    for (qsizetype at = m_buffer.indexOf('\n'); at >= 0; at = m_buffer.indexOf('\n', from)) {
        // Whole lines only, so no character is ever cut in two.
        complete.append(QString::fromUtf8(m_buffer.constData() + from, at - from));
        from = at + 1;
    }
    m_buffer.remove(0, from);
    if (!complete.isEmpty() && !m_stopped) {
        Q_EMIT lines(complete);
    }
    if (m_buffer.size() > s_maxLine) {
        stop();
    }
}

void StreamProcess::end(int exitCode)
{
    if (!m_process) {
        return;
    }
    QProcess *process = m_process;
    if (exitCode >= 0) {
        // what came without a line break at the very end
        m_buffer.append(process->readAllStandardOutput());
        if (!m_buffer.isEmpty()) {
            Q_EMIT lines({QString::fromUtf8(m_buffer)});
        }
    }
    if (!m_merge) {
        m_errors.append(process->readAllStandardError());
    }
    const QString errors = QString::fromUtf8(m_errors.right(s_maxErrors));
    m_buffer.clear();
    m_errors.clear();
    m_process = nullptr;
    process->disconnect(this);
    process->deleteLater();
    Q_EMIT runningChanged();
    Q_EMIT finished(exitCode, errors);
}
