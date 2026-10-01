/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Round, flat symbolic icon button tinted for the island surface.
*/
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: button

    property string iconName
    property color color: "white"
    property color hoverColor: Qt.rgba(1, 1, 1, 0.12)
    property real iconSize: Kirigami.Units.iconSizes.small
    property string toolTip
    signal clicked()

    implicitWidth: iconSize + 14
    implicitHeight: iconSize + 14
    opacity: enabled ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.pressed ? Qt.darker(button.hoverColor, 1.3) : button.hoverColor
        opacity: mouse.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: button.iconSize
        height: button.iconSize
        source: button.iconName
        color: button.color
        isMask: true
        scale: mouse.pressed ? 0.88 : mouse.containsMouse ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
