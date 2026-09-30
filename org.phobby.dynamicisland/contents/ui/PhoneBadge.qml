/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Small phone badge marking notifications that came from KDE Connect.
*/
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: badge

    property color tint: "#0a84ff"

    width: 16
    height: 16
    radius: 8
    color: tint
    border.width: 1.5
    border.color: Qt.rgba(0, 0, 0, 0.5)

    Kirigami.Icon {
        anchors.centerIn: parent
        width: 10
        height: 10
        source: "smartphone-symbolic"
        color: "white"
        isMask: true
    }
}
