/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Small rounded text button for the pages inside the island.
*/
import QtQuick

Rectangle {
    id: pill

    required property Theme theme
    property string text
    property bool primary: false
    property color tint: theme.blue          // fill of a primary button
    signal clicked()

    implicitWidth: label.implicitWidth + 22
    implicitHeight: 26
    radius: height / 2
    readonly property color fill: primary ? tint : theme.faint
    color: mouse.pressed ? Qt.darker(fill, 1.2) : mouse.containsMouse && !primary ? theme.over(theme.hoverFill, theme.over(fill, theme.surface)) : fill
    opacity: enabled ? 1 : 0.4
    scale: mouse.pressed ? 0.95 : mouse.containsMouse ? 1.05 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Text {
        id: label
        anchors.centerIn: parent
        text: pill.text
        color: pill.primary ? pill.theme.onColor(pill.tint) : pill.theme.text
        font.pointSize: pill.theme.fontSmall
        font.weight: Font.DemiBold
    }
    MouseArea { id: mouse; anchors.fill: parent; enabled: pill.enabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
}
