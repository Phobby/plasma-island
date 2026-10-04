// SPDX-License-Identifier: GPL-2.0-or-later
#include "filedrag.h"

#include <QDrag>
#include <QFileInfo>
#include <QIcon>
#include <QMimeData>
#include <QTimer>
#include <QUrl>

FileDrag::FileDrag(QObject *parent)
    : QObject(parent)
{
}

bool FileDrag::active() const
{
    return m_active;
}

bool FileDrag::start(QObject *source, const QString &path, const QString &iconName)
{
    const QFileInfo info(path);
    if (m_active || !source || !(info.isFile() || info.isDir())) {
        return false;
    }
    m_active = true;
    Q_EMIT activeChanged();
    const QPointer<QObject> from(source);
    const QString file = info.absoluteFilePath();
    // Not from inside the mouse handler that asked for it.
    QTimer::singleShot(0, this, [this, from, file, iconName] {
        Qt::DropAction action = Qt::IgnoreAction;
        if (from) {
            // (the drag deletes itself, and its data with it, when the drop is over)
            auto *drag = new QDrag(this);
            auto *data = new QMimeData;
            data->setUrls({QUrl::fromLocalFile(file)});
            drag->setMimeData(data);
            const QIcon icon = QIcon::fromTheme(iconName.isEmpty() ? QStringLiteral("text-x-generic") : iconName);
            if (!icon.isNull()) {
                drag->setPixmap(icon.pixmap(32, 32));
            }
            action = drag->exec(Qt::CopyAction, Qt::CopyAction);
        }
        m_active = false;
        Q_EMIT activeChanged();
        Q_EMIT finished(action != Qt::IgnoreAction);
    });
    return true;
}
