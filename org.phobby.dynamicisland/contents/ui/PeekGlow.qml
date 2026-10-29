/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The light at the edge while the island is drawn up over a full-screen
    window (Appearance › Full screen): a soft glow from the top edge down,
    over the island's place, while the pointer comes near (from the edge down
    to a little above the closed notch's lower edge: PointerBridge.qml) or is
    at the place that opens it, or an event waits (a call, a recording…, in its colour). With nothing of
    the island showing (a strip of 0 px) it is the only sign of where it is.
    It fades in and out and holds still while it shows, unless an event waits:
    then it pulses like the bar on the strip does (main.qml), in steps.
    Drawn only; it takes no pointer (main.qml's region is the strip's).
*/
import QtQuick
import QtQuick.Shapes

Item {
    id: glow

    property color color: "#3daee9"
    // 0..1
    property real strength: 0.6
    property bool lit: false
    // An event waits: down to a little and up again in 1.1 s, then a rest, as the bar on the strip.
    // In steps (12 a second), not as an animation, which would draw at every refresh of the display
    // over the full-screen window for as long as the event lasts.
    property bool pulse: false

    opacity: lit ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // (a half circle from the edge, as wide as the light and pressed flat to its height)
    Item {
        property int pulseAt: 0
        opacity: !glow.pulse || pulseAt >= 1100 ? 1 : 0.6 + 0.4 * Math.cos(2 * Math.PI * pulseAt / 1100)
        Timer {
            interval: 83
            repeat: true
            running: glow.pulse && glow.visible
            onRunningChanged: parent.pulseAt = 0
            onTriggered: parent.pulseAt = (parent.pulseAt + interval) % 2000
        }
        width: glow.width
        height: Math.max(1, glow.width / 2)
        transform: Scale { yScale: glow.height / Math.max(1, glow.width / 2) }
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: glow.width / 2; centerY: 0; centerRadius: glow.width / 2
                    focalX: glow.width / 2; focalY: 0
                    GradientStop { position: 0; color: Qt.alpha(glow.color, glow.strength) }
                    GradientStop { position: 0.6; color: Qt.alpha(glow.color, glow.strength * 0.5) }
                    GradientStop { position: 1; color: Qt.alpha(glow.color, 0) }
                }
                startX: 0; startY: 0
                PathLine { x: glow.width; y: 0 }
                PathLine { x: glow.width; y: glow.width / 2 }
                PathLine { x: 0; y: glow.width / 2 }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}
