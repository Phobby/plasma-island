// SPDX-License-Identifier: GPL-2.0-or-later
#include "loopbackserver.h"

#include <QCryptographicHash>
#include <QHostAddress>
#include <QTcpServer>
#include <QTcpSocket>

LoopbackServer::LoopbackServer(QObject *parent)
    : QObject(parent)
{
}

int LoopbackServer::start()
{
    stop();
    m_server = new QTcpServer(this);
    connect(m_server, &QTcpServer::newConnection, this, &LoopbackServer::accept);
    if (!m_server->listen(QHostAddress::LocalHost, 0)) {
        stop();
        return 0;
    }
    return m_server->serverPort();
}

void LoopbackServer::stop()
{
    if (m_server) {
        m_server->close();
        m_server->deleteLater();
        m_server = nullptr;
    }
}

QString LoopbackServer::challenge(const QString &verifier) const
{
    return QString::fromLatin1(QCryptographicHash::hash(verifier.toLatin1(), QCryptographicHash::Sha256)
                                   .toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

void LoopbackServer::accept()
{
    while (m_server && m_server->hasPendingConnections()) {
        QTcpSocket *socket = m_server->nextPendingConnection();
        connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
        connect(socket, &QTcpSocket::readyRead, this, [this, socket] {
            if (!socket->canReadLine()) {
                return;
            }
            // "GET /?code=…&state=… HTTP/1.1"
            const QList<QByteArray> request = socket->readLine().split(' ');
            const QByteArray target = request.size() > 1 ? request.at(1) : QByteArray();
            const int mark = target.indexOf('?');
            const bool answer = mark >= 0;
            const QByteArray body = answer
                ? QByteArrayLiteral("<!doctype html><meta charset=\"utf-8\"><title>Dynamic Island</title>"
                                    "<body style=\"font-family:sans-serif;text-align:center;margin-top:20vh\">"
                                    "<h2>Sent to the island</h2><p>You can close this tab and return to the island; the result is shown on its Calendar page.</p></body>")
                : QByteArray();
            socket->write(QByteArrayLiteral("HTTP/1.1 ") + (answer ? "200 OK" : "404 Not Found")
                          + "\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\nContent-Length: "
                          + QByteArray::number(body.size()) + "\r\n\r\n" + body);
            socket->disconnectFromHost();
            if (answer) {
                Q_EMIT received(QString::fromLatin1(target.mid(mark + 1)));
            }
        });
    }
}
