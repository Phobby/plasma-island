/*
    SPDX-License-Identifier: GPL-2.0-or-later

    What the companion has beside its head: a small bubble with a sign in it,
    or signs floating without one. It belongs to no character.

      dots      it thinks: three dots, one after the other a little higher
      question  it waits for an answer: ?
      exclaim   something is ready: !
      note      music: ♪
      hiss      it is angry: ! in red
      heart     it is stroked: hearts rising (motion reduced: one, in a bubble)
      zzz       it sleeps: z, zz, zzz

    Signs, not words: nothing to translate. Nothing here takes the pointer.
    What moves does so in steps, a few a second, and only while it is shown.
*/
import QtQuick
import QtQuick.Shapes

Item {
    id: bubble

    property string kind: ""
    property bool still: false
    property bool running: true
    // The bubble opens towards the head: -1 = the head is on its right, 1 = on its left.
    property int side: -1
    // Its height; everything follows from it.
    property real size: 20
    property color fill: "#2b2c31"
    property color rim: "#55575f"
    property color ink: "white"
    property color hot: "#ff453a"
    property color love: "#ff5c7a"
    // The gallery's: a phase by hand (0..1); -1 = it runs by itself.
    property real fixedPhase: -1

    // What is drawn stays while it fades out.
    property string drawn: ""
    onKindChanged: if (kind !== "") drawn = kind
    readonly property bool framed: drawn === "dots" || drawn === "question" || drawn === "exclaim" || drawn === "note" || drawn === "hiss" || (drawn === "heart" && still)
    readonly property bool floating: drawn === "zzz" || (drawn === "heart" && !still)

    width: size * 1.25
    height: size
    visible: opacity > 0.01
    opacity: kind !== "" ? 1 : 0
    scale: kind !== "" ? 1 : 0.6
    transformOrigin: side < 0 ? Item.BottomRight : Item.BottomLeft
    Behavior on opacity { enabled: !bubble.still; NumberAnimation { duration: 150 } }
    Behavior on scale { enabled: !bubble.still; NumberAnimation { duration: 190; easing.type: Easing.OutBack } }

    // ---- steps ---------------------------------------------------------------------
    // [one round (ms), steps in it]
    readonly property var pace: drawn === "dots" ? [1400, 4] : drawn === "zzz" ? [4000, 4] : drawn === "heart" ? [1500, 15] : drawn === "hiss" ? [240, 2] : [0, 0]
    property int step: 0
    readonly property real phase: fixedPhase >= 0 ? fixedPhase : pace[1] > 0 ? (step % pace[1]) / pace[1] : 0
    Timer {
        repeat: true
        running: bubble.running && !bubble.still && bubble.fixedPhase < 0 && bubble.kind !== "" && bubble.pace[1] > 0
        interval: bubble.pace[1] > 0 ? Math.round(bubble.pace[0] / bubble.pace[1]) : 1000
        onRunningChanged: if (running) bubble.step = 0
        onTriggered: bubble.step += 1
    }

    // ---- the bubble: a round box and two small rounds leading to the head --------------------
    Item {
        anchors.fill: parent
        visible: bubble.framed
        x: bubble.drawn === "hiss" && !bubble.still ? (bubble.phase < 0.5 ? -0.5 : 0.5) : 0
        Rectangle {
            id: box
            width: parent.width
            height: parent.height * 0.82
            radius: height / 2
            color: bubble.fill
            border.width: 1
            border.color: bubble.drawn === "hiss" ? bubble.hot : bubble.rim
        }
        Rectangle {
            x: bubble.side < 0 ? parent.width * 0.74 : parent.width * 0.26 - width
            y: parent.height * 0.8
            width: bubble.size * 0.2; height: width; radius: width / 2
            color: bubble.fill; border.width: 1; border.color: box.border.color
        }
        Rectangle {
            x: bubble.side < 0 ? parent.width * 0.93 : parent.width * 0.07 - width
            y: parent.height * 0.97
            width: bubble.size * 0.12; height: width; radius: width / 2
            color: bubble.fill; border.width: 1; border.color: box.border.color
        }
        // dots: the one whose turn it is stands a little higher and brighter
        Row {
            anchors.centerIn: box
            visible: bubble.drawn === "dots"
            spacing: bubble.size * 0.11
            Repeater {
                model: 3
                delegate: Item {
                    required property int index
                    readonly property bool up: !bubble.still && Math.floor(bubble.phase * 4 + 0.001) === index
                    width: bubble.size * 0.17
                    height: bubble.size * 0.3
                    Rectangle {
                        width: parent.width; height: width; radius: width / 2
                        y: parent.up ? 0 : parent.height - height
                        color: bubble.ink
                        opacity: parent.up || bubble.still ? 1 : 0.55
                    }
                }
            }
        }
        Text {
            textFormat: Text.PlainText
            anchors.centerIn: box
            anchors.verticalCenterOffset: bubble.drawn === "note" ? -bubble.size * 0.02 : 0
            visible: bubble.drawn === "question" || bubble.drawn === "exclaim" || bubble.drawn === "note" || bubble.drawn === "hiss"
            text: bubble.drawn === "question" ? "?" : bubble.drawn === "note" ? "♪" : bubble.drawn === "hiss" ? "!!" : "!"
            color: bubble.drawn === "hiss" ? bubble.hot : bubble.ink
            font.pixelSize: bubble.size * 0.6
            font.weight: Font.Bold
        }
        Heart {
            anchors.centerIn: box
            visible: bubble.drawn === "heart"
            width: bubble.size * 0.5
        }
    }

    component Heart: Shape {
        id: heart
        height: width * 0.92
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: bubble.love
            strokeColor: Qt.darker(bubble.love, 1.25)
            strokeWidth: Math.max(0.5, heart.width * 0.06)
            joinStyle: ShapePath.RoundJoin
            startX: heart.width * 0.5; startY: heart.height
            PathCubic { x: heart.width * 0.5; y: heart.height * 0.26; control1X: -heart.width * 0.34; control1Y: heart.height * 0.42; control2X: heart.width * 0.2; control2Y: -heart.height * 0.3 }
            PathCubic { x: heart.width * 0.5; y: heart.height; control1X: heart.width * 0.8; control1Y: -heart.height * 0.3; control2X: heart.width * 1.34; control2Y: heart.height * 0.42 }
        }
    }

    // ---- without a bubble: hearts rising, the letters of sleep -------------------------------
    // Three hearts, one after the other: each rises, sways and fades over its round.
    Repeater {
        model: bubble.drawn === "heart" && !bubble.still ? 3 : 0
        delegate: Heart {
            required property int index
            readonly property real at: (bubble.phase + index / 3) % 1
            width: bubble.size * (0.34 + 0.1 * ((index + 1) % 2))
            x: bubble.width * (bubble.side < 0 ? 0.62 - 0.2 * index : 0.18 + 0.2 * index) + Math.sin(at * 6.3 + index) * bubble.size * 0.07
            y: bubble.height * (0.72 - 0.95 * at)
            opacity: bubble.kind === "heart" ? Math.min(1, at * 5, (1 - at) * 2.4) : 0
            scale: 0.7 + 0.3 * Math.min(1, at * 4)
        }
    }
    // z, zz, zzz, then a breath without any
    Repeater {
        model: bubble.drawn === "zzz" ? 3 : 0
        delegate: Text {
            textFormat: Text.PlainText
            required property int index
            readonly property int shown: bubble.still ? 3 : Math.floor(bubble.phase * 4 + 0.001) + 1
            text: "z"
            visible: index < shown && shown <= 3
            x: bubble.side < 0 ? bubble.width * (0.66 - 0.3 * index) : bubble.width * (0.12 + 0.3 * index)
            y: bubble.height * (0.52 - 0.3 * index)
            color: bubble.ink
            style: Text.Outline
            styleColor: bubble.fill
            font.pixelSize: bubble.size * (0.36 + 0.1 * index)
            font.weight: Font.Bold
            font.italic: true
        }
    }
}
