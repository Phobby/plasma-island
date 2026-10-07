/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Mini animated sound-wave bars. They only move while `running`.

    They move in steps, `stepsPerSecond` of them: an animation of their own
    would have the whole island drawn anew at every refresh of the display
    (60, 144, 180 times a second) for as long as music plays. Measured with
    music playing and nothing else going on, on a 60 Hz screen: 2.9 % of a
    core in the shell and 2.1 % in the compositor before, for four small bars.
*/
import QtQuick

Row {
    id: eq

    property bool running: false
    property color color: "white"
    property int bars: 4
    property real barWidth: 3
    property int stepsPerSecond: 12

    spacing: 2
    height: 14

    // how long it has been running (ms), in steps
    property real clock: 0
    Timer {
        interval: Math.round(1000 / Math.max(1, eq.stepsPerSecond))
        repeat: true
        running: eq.running && eq.visible
        onTriggered: eq.clock += interval
    }

    Repeater {
        model: eq.bars
        delegate: Rectangle {
            id: bar
            required property int index
            // Pseudo-random but stable per bar
            readonly property int base: 260 + (index * 97) % 170
            // Four moves, one after the other and round again: [how high, how long (ms)]
            readonly property var moves: [[0.55 + (index % 2) * 0.45, base], [0.25, base * 0.8], [0.95 - (index % 3) * 0.2, base * 1.2], [0.35, base]]
            readonly property real round: base * 4
            // The height at `t` ms into a round: eased (in-out sine) from one move's end to the next.
            function level(t: real): real {
                let from = moves[3][0];
                for (const move of moves) {
                    if (t < move[1]) return from + (move[0] - from) * (1 - Math.cos(Math.PI * t / move[1])) / 2;
                    t -= move[1];
                    from = move[0];
                }
                return from;
            }
            anchors.verticalCenter: parent.verticalCenter
            width: eq.barWidth
            radius: width / 2
            color: eq.color
            // (paused, they stay where they were)
            height: eq.height * (eq.clock > 0 ? level(eq.clock % round) : 0.3)
        }
    }
}
