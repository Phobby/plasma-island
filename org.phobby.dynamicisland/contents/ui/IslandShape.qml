/*
    SPDX-License-Identifier: GPL-2.0-or-later

    IslandShape: Oxygen-inspired metallic glass surface.
      drop shadow → graphite vertical gradient body (translucent over KWin blur)
      → inner shadow → top gloss → silver rim brighter at the top.
    Children are placed in a clipped, padded content item.
*/
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: shape

    required property Theme theme
    property real radius: height / 2
    default property alias content: contentItem.data
    property real contentPadding: 0

    Kirigami.ShadowedRectangle {
        anchors.fill: parent
        radius: shape.radius
        color: "transparent"
        shadow.size: shape.theme.shadowSize
        shadow.yOffset: 4
        shadow.color: shape.theme.dropShadow
    }

    // Body
    Rectangle {
        anchors.fill: parent
        radius: shape.radius
        border.width: 1
        border.color: shape.theme.rimBottom
        gradient: Gradient {
            GradientStop { position: 0.0; color: shape.theme.bodyTop }
            GradientStop { position: 0.45; color: shape.theme.bodyMid }
            GradientStop { position: 1.0; color: shape.theme.bodyBottom }
        }
    }

    // Inner shadow (inset depth)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, shape.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: shape.theme.innerShadow
    }

    // Top gloss
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 1
        }
        height: Math.min(parent.height * 0.5, 60)
        radius: Math.max(0, shape.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0.0; color: shape.theme.highlight }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Silver rim: bright over the top arc, fading in two steps down the sides.
    Repeater {
        model: [
            { h: 0.5, o: 1.0 },
            { h: 0.8, o: 0.45 }
        ]
        delegate: Item {
            required property var modelData
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: Math.max(1, Math.min(shape.radius, shape.height / 2) * modelData.h * 2)
            clip: true
            opacity: modelData.o
            Rectangle {
                width: shape.width
                height: shape.height
                radius: shape.radius
                color: "transparent"
                border.width: 1
                border.color: shape.theme.rimTop
            }
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: shape.contentPadding
        clip: true
    }
}
