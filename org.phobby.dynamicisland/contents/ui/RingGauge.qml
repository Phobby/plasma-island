/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Minimal ring gauge (0..1) with centered label.
*/
import QtQuick
import QtQuick.Shapes

Item {
    id: ring

    property real value: 0
    property color color: "white"
    property color trackColor: Qt.rgba(1, 1, 1, 0.15)
    property real lineWidth: 4
    property string label: ""
    // Optional second line (e.g. upload rate); both lines shrink to fit.
    property string secondaryLabel: ""
    property string caption: ""
    property color textColor: "white"
    property color captionColor: "gray"
    property real fontSize: 9

    implicitWidth: 52
    implicitHeight: 52 + captionText.height + 2

    readonly property real size: Math.min(width, height - captionText.height - 2)
    property real animatedValue: Math.max(0, Math.min(1, value))
    Behavior on animatedValue { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    Shape {
        id: shape
        width: ring.size
        height: ring.size
        anchors.horizontalCenter: parent.horizontalCenter
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: ring.trackColor
            strokeWidth: ring.lineWidth
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: ring.size / 2 - ring.lineWidth / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: ring.color
            strokeWidth: ring.lineWidth
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: ring.size / 2 - ring.lineWidth / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: 360 * ring.animatedValue
            }
        }
    }

    Column {
        anchors.centerIn: shape
        spacing: -1
        Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.label
            color: ring.textColor
            font.pointSize: ring.secondaryLabel.length > 0 ? ring.fontSize * 0.82 : ring.fontSize
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: ring.secondaryLabel.length > 0
            text: ring.secondaryLabel
            color: ring.textColor
            opacity: 0.75
            font.pointSize: ring.fontSize * 0.82
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    Text {
        textFormat: Text.PlainText
        id: captionText
        anchors.top: shape.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: ring.caption
        color: ring.captionColor
        font.pointSize: ring.fontSize * 0.9
    }
}
