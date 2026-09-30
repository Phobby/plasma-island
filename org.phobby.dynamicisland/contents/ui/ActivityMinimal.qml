/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Generic minimal presentation for the split bubble: progress ring around the
    icon, or just the icon.
*/
import QtQuick

Item {
    id: minimal

    required property var activity
    required property Theme theme

    readonly property bool hasProgress: (activity?.progress ?? -1) >= 0

    MiniRing {
        anchors.centerIn: parent
        visible: minimal.hasProgress
        width: parent.width - 8
        height: width
        value: minimal.activity?.progress ?? 0
        color: minimal.activity?.color ?? minimal.theme.text
        trackColor: minimal.theme.track
        icon: minimal.activity?.icon ?? ""
    }
    ActivityIcon {
        anchors.centerIn: parent
        visible: !minimal.hasProgress
        width: 16
        height: 16
        icon: minimal.activity?.icon ?? ""
        color: minimal.activity?.color ?? minimal.theme.text
        pulse: minimal.activity?.pulse ?? false
        running: minimal.visible
    }
}
