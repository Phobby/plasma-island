/*
    SPDX-License-Identifier: GPL-2.0-or-later
    iOS style battery: rounded body + cap; fills with a sweep animation while
    charging and shows a bolt.
*/
import QtQuick
import QtQuick.Shapes

Item {
    id: glyph

    property real value: 0.5
    property bool charging: false
    property color color: "#32d74b"
    property bool running: visible

    implicitWidth: 30
    implicitHeight: 14

    property real shown: 0
    Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    Component.onCompleted: shown = value
    onValueChanged: shown = value
    // Refill from empty each time the glyph appears while charging (iOS).
    onRunningChanged: if (running && charging) { shown = 0; Qt.callLater(() => { shown = value; }); }

    Rectangle {
        id: body
        width: parent.width - 3
        height: parent.height
        radius: 4
        color: "transparent"
        border.width: 1.2
        border.color: Qt.rgba(glyph.color.r, glyph.color.g, glyph.color.b, 0.55)

        Rectangle {
            x: 2
            y: 2
            height: parent.height - 4
            width: Math.max(2, (parent.width - 4) * Math.max(0, Math.min(1, glyph.shown)))
            radius: 2.5
            color: glyph.color
        }
    }
    Rectangle {
        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: body.verticalCenter
        width: 2
        height: parent.height * 0.4
        radius: 1
        color: Qt.rgba(glyph.color.r, glyph.color.g, glyph.color.b, 0.55)
    }
    // Lightning bolt
    Shape {
        id: bolt
        anchors.centerIn: body
        visible: glyph.charging
        width: body.height * 0.62
        height: body.height * 0.9
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0.8
            strokeColor: Qt.rgba(0, 0, 0, 0.35)
            fillColor: "white"
            startX: bolt.width * 0.62; startY: 0
            PathLine { x: bolt.width * 0.05; y: bolt.height * 0.58 }
            PathLine { x: bolt.width * 0.45; y: bolt.height * 0.58 }
            PathLine { x: bolt.width * 0.32; y: bolt.height }
            PathLine { x: bolt.width * 0.95; y: bolt.height * 0.38 }
            PathLine { x: bolt.width * 0.55; y: bolt.height * 0.38 }
            PathLine { x: bolt.width * 0.62; y: 0 }
        }
    }
}
