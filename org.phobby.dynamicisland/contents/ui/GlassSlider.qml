/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Thin iOS-like slider. `moved(value)` fires on user interaction; `value`
    follows the external binding unless the user is dragging.
*/
import QtQuick

Item {
    id: slider

    property real value: 0          // 0..1
    property color fillColor: "white"
    property color trackColor: Qt.rgba(1, 1, 1, 0.18)
    property real thickness: 5
    property bool showKnob: true
    readonly property bool pressed: mouse.pressed
    readonly property bool hovered: mouse.containsMouse
    readonly property real shownValue: pressed ? dragValue : Math.max(0, Math.min(1, value))
    property real dragValue: 0

    signal moved(real value)

    implicitHeight: 16

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: slider.hovered || slider.pressed ? slider.thickness + 2 : slider.thickness
        radius: height / 2
        color: slider.trackColor
        Behavior on height { NumberAnimation { duration: 120 } }

        Rectangle {
            width: Math.max(track.height, track.width * slider.shownValue)
            height: parent.height
            radius: parent.radius
            color: slider.fillColor
        }
    }

    Rectangle {
        visible: slider.showKnob && (slider.hovered || slider.pressed)
        width: 12
        height: 12
        radius: 6
        color: "white"
        border.color: Qt.rgba(0, 0, 0, 0.25)
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(slider.width - width, slider.width * slider.shownValue - width / 2))
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function update(mx: real): void {
            slider.dragValue = Math.max(0, Math.min(1, mx / slider.width));
            slider.moved(slider.dragValue);
        }
        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => { if (pressed) update(mouse.x); }
        // A notch is 5 %; a touchpad moves it by the way the fingers went. A
        // scroll that began elsewhere (a list passing under the pointer) is
        // not the slider's, and one that began here goes nowhere else.
        onWheel: wheel => {
            const step = ScrollGesture.step(wheel);
            if (!ScrollGesture.take(slider, !step.none, wheel)) { wheel.accepted = false; return; }
            if (step.horizontal || step.y === 0) return;
            const by = step.pixels ? step.y / ScrollGesture.sliderPixels : (step.y > 0 ? 0.05 : -0.05);
            slider.moved(Math.max(0, Math.min(1, slider.value + by)));
        }
    }
}
