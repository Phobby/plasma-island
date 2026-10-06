/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Media live activity inside the pill: album art · title · equalizer.
    (Moved unchanged from Island.qml's former "live" layer.)
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: media

    required property var activity
    required property Theme theme
    property PlasmaBackend backend: activity?.backend ?? null

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 14
        spacing: 8

        AlbumArt {
            Layout.preferredWidth: media.theme.pillHeight - 10
            Layout.preferredHeight: media.theme.pillHeight - 10
            radius: height / 2
            source: media.backend?.artUrl ?? ""
            fallbackIcon: media.backend?.playerIcon || "media-album-cover"
            fallbackColor: media.theme.faint
        }
        Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: media.backend?.track ?? ""
            color: media.theme.subText
            font.pointSize: media.theme.fontSmall
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Equalizer {
            running: media.visible && (media.backend?.isPlaying ?? false)
            color: media.theme.live
            Layout.preferredHeight: 14
        }
    }
}
