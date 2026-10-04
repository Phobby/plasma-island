/*
    SPDX-License-Identifier: GPL-2.0-or-later
    A look, small: the island in that style on something to see through it.
    For the cards of the settings (ready-made looks, own themes, the store).
*/
import QtQuick

Rectangle {
    id: preview

    property var style: Styles.defaults("oxygen")       // a whole style
    property var systemScheme: null

    implicitHeight: 54
    radius: 6
    clip: true
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#5b8def" }
        GradientStop { position: 0.5; color: "#c86dd7" }
        GradientStop { position: 1.0; color: "#f5a25d" }
    }
    Theme {
        id: sample
        follow: false
        systemScheme: preview.systemScheme
        style: preview.style
        blurActive: true
    }
    IslandShape {
        anchors.centerIn: parent
        theme: sample
        width: parent.width - 22
        height: 24
        radius: sample.rounded(height / 2)
        Row {
            anchors.centerIn: parent
            spacing: 6
            Rectangle { width: 8; height: 8; radius: 4; color: sample.control; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "12:45"; color: sample.text; font.pointSize: sample.fontSmall; font.weight: Font.DemiBold }
        }
    }
}
