/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Tinted symbolic icon that can pulse (recording dot) — or a plain dot when
    `icon` is "dot", or one of the widget's own pictures when it is
    "weather:<name>" or "lucide:<name>" (WeatherIcon.qml).
*/
import QtQuick
import org.kde.kirigami as Kirigami
import "WeatherIcons.js" as WeatherIcons

Item {
    id: root

    property string icon
    property color color: "white"
    property bool pulse: false
    property bool running: visible

    implicitWidth: 18
    implicitHeight: 18

    readonly property string ownName: WeatherIcons.own(root.icon)
    readonly property bool own: ownName.length > 0
    Kirigami.Icon {
        id: glyph
        anchors.fill: parent
        visible: root.icon !== "dot" && !root.own
        source: root.own ? "" : root.icon
        color: root.color
        isMask: true
    }
    WeatherIcon {
        anchors.fill: parent
        visible: root.own
        name: root.ownName
        color: root.color
    }
    Rectangle {
        anchors.centerIn: parent
        visible: root.icon === "dot"
        width: parent.width * 0.62
        height: width
        radius: width / 2
        color: root.color
    }
    // The blink of something urgent (a recording, a call): down to a quarter and up again in 1.3 s.
    // In steps (12 a second), not as an animation: that would draw the island at every refresh of
    // the display for as long as the recording runs.
    property int pulseAt: 0
    opacity: pulse && running ? 0.625 + 0.375 * Math.cos(2 * Math.PI * pulseAt / 1300) : 1
    Timer {
        interval: 83
        repeat: true
        running: root.pulse && root.running
        onRunningChanged: root.pulseAt = 0
        onTriggered: root.pulseAt = (root.pulseAt + interval) % 1300
    }
}
