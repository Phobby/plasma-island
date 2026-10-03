/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Default output device volume + mute.
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: vol

    required property Theme theme
    required property PlasmaBackend backend

    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 8
        enabled: vol.backend.hasSink

        IconButton {
            iconName: vol.backend.volumeIcon
            color: vol.backend.muted ? vol.theme.subText : vol.theme.text
            hoverColor: vol.theme.faint
            toolTip: vol.backend.muted ? Lang.i18n("Unmute") : Lang.i18n("Mute")
            onClicked: vol.backend.toggleMute()
        }
        GlassSlider {
            Layout.fillWidth: true
            value: vol.backend.muted ? 0 : vol.backend.volume
            fillColor: vol.backend.muted ? vol.theme.subText : vol.theme.sliderFill
            trackColor: vol.theme.track
            onMoved: v => vol.backend.setVolume(v)
        }
        Text {
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
            text: vol.backend.muted ? Lang.i18nc("@label volume muted", "Muted") : Lang.percent(Math.round(vol.backend.volume * 100))
            color: vol.theme.subText
            font.pointSize: vol.theme.fontSmall
            font.features: { "tnum": 1 }
        }
    }
}
