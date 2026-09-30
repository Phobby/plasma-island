/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Media in the split bubble: round album art with a tiny equalizer overlay.
*/
import QtQuick

Item {
    id: media

    required property var activity
    required property Theme theme
    property PlasmaBackend backend: activity?.backend ?? null

    AlbumArt {
        anchors.centerIn: parent
        width: parent.width - 8
        height: width
        radius: width / 2
        source: media.backend?.artUrl ?? ""
        fallbackIcon: media.backend?.playerIcon || "media-album-cover"
        fallbackColor: media.theme.faint
    }
}
