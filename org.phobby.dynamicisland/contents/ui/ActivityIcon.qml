/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Tinted symbolic icon that can pulse (recording dot) — or a plain dot when
    `icon` is "dot".
*/
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string icon
    property color color: "white"
    property bool pulse: false
    property bool running: visible

    implicitWidth: 18
    implicitHeight: 18

    Kirigami.Icon {
        id: glyph
        anchors.fill: parent
        visible: root.icon !== "dot"
        source: root.icon
        color: root.color
        isMask: true
    }
    Rectangle {
        anchors.centerIn: parent
        visible: root.icon === "dot"
        width: parent.width * 0.62
        height: width
        radius: width / 2
        color: root.color
    }
    SequentialAnimation on opacity {
        running: root.pulse && root.running
        loops: Animation.Infinite
        onRunningChanged: if (!running) root.opacity = 1
        NumberAnimation { to: 0.25; duration: 650; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
    }
}
