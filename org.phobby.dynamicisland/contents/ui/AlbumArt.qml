/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Rounded album cover with a player-icon fallback.
*/
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: art

    property string source: ""
    property string fallbackIcon: "media-album-cover"
    property real radius: 6
    property color fallbackColor: Qt.rgba(1, 1, 1, 0.1)
    property color iconColor: "white"

    readonly property bool hasImage: image.status === Image.Ready

    Image {
        id: image
        anchors.fill: parent
        visible: false
        source: art.source
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 256
        sourceSize.height: 256
    }

    Kirigami.ShadowedTexture {
        anchors.fill: parent
        visible: art.hasImage
        radius: art.radius
        color: "transparent"
        source: image
    }

    Rectangle {
        anchors.fill: parent
        visible: !art.hasImage
        radius: art.radius
        color: art.fallbackColor
        Kirigami.Icon {
            anchors.centerIn: parent
            width: parent.width * 0.6
            height: width
            source: art.fallbackIcon
        }
    }
}
