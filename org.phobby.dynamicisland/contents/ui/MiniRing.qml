/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Small progress ring (0..1) with optional centered icon or text.
*/
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: ring

    property real value: 0
    property color color: "white"
    property color trackColor: Qt.rgba(1, 1, 1, 0.18)
    property real lineWidth: 3
    property string icon
    property string text
    property color textColor: color
    property real fontSize: 7
    // Unknown progress: a quarter arc spinning (no fake percentage).
    property bool indeterminate: false

    implicitWidth: 22
    implicitHeight: 22

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: ring.trackColor
            strokeWidth: ring.lineWidth
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: Math.min(ring.width, ring.height) / 2 - ring.lineWidth / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: ring.color
            strokeWidth: ring.lineWidth
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: Math.min(ring.width, ring.height) / 2 - ring.lineWidth / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: ring.indeterminate ? 90 : 360 * ring.shown
            }
        }
        RotationAnimation on rotation {
            running: ring.indeterminate && ring.visible
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 1100
        }
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        visible: ring.icon.length > 0
        width: parent.width * 0.5
        height: width
        source: ring.icon
        color: ring.textColor
        isMask: true
    }
    Text {
        anchors.centerIn: parent
        visible: ring.text.length > 0 && ring.icon.length === 0
        text: ring.text
        color: ring.textColor
        font.pointSize: ring.fontSize
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}
