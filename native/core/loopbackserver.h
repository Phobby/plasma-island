// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

class QTcpServer;

/*
 * The local end of an OAuth sign-in in the browser ("loopback redirect"):
 * listens on 127.0.0.1, answers the browser with a short page and reports the
 * query string it was called with (code=…&state=…). Also hashes the PKCE
 * verifier, which QML cannot do.
 */
class LoopbackServer : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit LoopbackServer(QObject *parent = nullptr);

    // Starts listening on a free port and returns it (0 = failed).
    Q_INVOKABLE int start();
    Q_INVOKABLE void stop();
    // base64url(SHA-256(text)), the PKCE "S256" challenge.
    Q_INVOKABLE QString challenge(const QString &verifier) const;

Q_SIGNALS:
    void received(const QString &query);

private:
    void accept();

    QTcpServer *m_server = nullptr;
};
