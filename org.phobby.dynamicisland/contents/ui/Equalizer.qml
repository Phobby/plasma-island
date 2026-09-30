/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Mini animated sound-wave bars. Animations only run while `running`.
*/
import QtQuick

Row {
    id: eq

    property bool running: false
    property color color: "white"
    property int bars: 4
    property real barWidth: 3

    spacing: 2
    height: 14

    Repeater {
        model: eq.bars
        delegate: Rectangle {
            id: bar
            required property int index
            // Pseudo-random but stable per bar
            readonly property int base: 260 + (index * 97) % 170
            anchors.verticalCenter: parent.verticalCenter
            width: eq.barWidth
            radius: width / 2
            color: eq.color
            height: eq.height * 0.3

            SequentialAnimation on height {
                running: eq.running
                loops: Animation.Infinite
                alwaysRunToEnd: false
                NumberAnimation { to: eq.height * (0.55 + (bar.index % 2) * 0.45); duration: bar.base; easing.type: Easing.InOutSine }
                NumberAnimation { to: eq.height * 0.25; duration: bar.base * 0.8; easing.type: Easing.InOutSine }
                NumberAnimation { to: eq.height * (0.95 - (bar.index % 3) * 0.2); duration: bar.base * 1.2; easing.type: Easing.InOutSine }
                NumberAnimation { to: eq.height * 0.35; duration: bar.base; easing.type: Easing.InOutSine }
            }
            Behavior on height {
                enabled: !eq.running
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }
}
