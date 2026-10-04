/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Three dots that take turns: an answer is on its way. They only move while
    they are shown.
*/
import QtQuick

Row {
    id: dots

    property color color: "white"
    property real size: 5
    property bool running: visible

    spacing: size * 0.7
    Repeater {
        model: 3
        delegate: Rectangle {
            id: dot
            required property int index
            width: dots.size
            height: dots.size
            radius: dots.size / 2
            color: dots.color
            opacity: 0.3
            SequentialAnimation on opacity {
                running: dots.running
                loops: Animation.Infinite
                PauseAnimation { duration: dot.index * 180 }
                NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { to: 0.3; duration: 260; easing.type: Easing.InQuad }
                PauseAnimation { duration: (2 - dot.index) * 180 + 220 }
            }
        }
    }
}
