// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QByteArray>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

/*
 * One command whose output is read while it is still running: the AI tab's
 * Claude Code, which writes its answer as lines of JSON, piece by piece.
 * (LocalTools::run hands over the output only when the command has ended.)
 *
 * No shell is involved. The command always runs in the directory it is
 * given, which is made (for the owner only) when it is missing: the caller
 * decides where, and it is never the directory plasmashell happens to be in.
 * What is to be said to the command goes to its standard input, not to its
 * arguments, so it does not show in the list of processes.
 */
class StreamProcess : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    // The command's process id while it runs, else 0 (for the tests: where it runs).
    Q_PROPERTY(qint64 processId READ processId NOTIFY runningChanged)

public:
    explicit StreamProcess(QObject *parent = nullptr);
    ~StreamProcess() override;

    bool running() const;
    qint64 processId() const;

    // false: one is running already, or the directory could not be made (nothing is started then).
    Q_INVOKABLE bool start(const QString &program, const QStringList &arguments, const QString &input, const QString &workingDirectory);
    // Ends the command (asked first, then killed); `finished` follows with -1.
    Q_INVOKABLE void stop();

Q_SIGNALS:
    // Complete lines of standard output, in order, as they arrive.
    void lines(const QStringList &lines);
    // exitCode -1: could not be started, crashed or was stopped. errorOutput: the end of standard error.
    void finished(int exitCode, const QString &errorOutput);
    void runningChanged();

private:
    void read();
    void end(int exitCode);

    QProcess *m_process = nullptr;
    QByteArray m_buffer;
    QByteArray m_errors;
    bool m_stopped = false;
};
