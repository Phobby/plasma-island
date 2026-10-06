/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Expanded media card: cover, title/artist/source, seek bar, transport and
    per-player volume.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: media

    required property Theme theme
    required property PlasmaBackend backend
    // The ambient glow (cover colour, follows the music): on/off from here.
    property bool glowEnabled: false
    signal glowToggled()

    implicitHeight: layout.implicitHeight

    function formatTime(us: real): string {
        const total = Math.max(0, Math.floor(us / 1000000));
        const h = Math.floor(total / 3600), m = Math.floor((total % 3600) / 60), s = total % 60;
        const ss = s < 10 ? "0" + s : "" + s;
        return h > 0 ? h + ":" + (m < 10 ? "0" + m : m) + ":" + ss : m + ":" + ss;
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 8
        visible: media.backend.track.length > 0

        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            AlbumArt {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                radius: 12
                source: media.backend.artUrl
                fallbackIcon: media.backend.playerIcon || "media-album-cover"
                fallbackColor: media.theme.faint

                MouseArea {
                    anchors.fill: parent
                    enabled: media.backend.canRaise
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: media.backend.raisePlayer()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: media.backend.track
                    color: media.theme.text
                    font.pointSize: media.theme.fontTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: media.backend.artist
                    color: media.theme.subText
                    font.pointSize: media.theme.fontNormal
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                RowLayout {
                    spacing: 4
                    Layout.topMargin: 2
                    Kirigami.Icon {
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        source: media.backend.playerIcon
                        visible: media.backend.playerIcon.length > 0
                    }
                    Text {
                        textFormat: Text.PlainText
                        text: media.backend.playerName
                        color: media.theme.subText
                        font.pointSize: media.theme.fontSmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                spacing: 4
            IconButton {
                Layout.alignment: Qt.AlignRight
                iconName: "view-media-visualization-symbolic"
                iconSize: 14
                implicitWidth: 24; implicitHeight: 24
                toolTip: media.glowEnabled ? Lang.i18n("Turn off the glow") : Lang.i18n("Glow in the colour of the cover, with the music")
                color: media.glowEnabled ? media.theme.live : media.theme.subText
                hoverColor: media.theme.faint
                onClicked: media.glowToggled()
            }
            Equalizer {
                Layout.alignment: Qt.AlignRight
                Layout.rightMargin: 4
                // Decorative "now playing" indicator: only shown while playing
                // (paused bars look like a clickable "…" menu).
                running: media.visible && media.backend.isPlaying
                opacity: media.backend.isPlaying ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                color: media.theme.live
                Layout.preferredHeight: 16
            }
            }
        }

        // Seek bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: media.backend.length > 0

            Text {
                textFormat: Text.PlainText
                text: media.formatTime(seek.pressed ? seek.dragValue * media.backend.length : media.backend.position)
                color: media.theme.subText
                font.pointSize: media.theme.fontSmall
                font.features: { "tnum": 1 }
            }
            GlassSlider {
                id: seek
                Layout.fillWidth: true
                enabled: media.backend.canSeek
                value: media.backend.length > 0 ? media.backend.position / media.backend.length : 0
                fillColor: media.theme.sliderFill
                trackColor: media.theme.track
                onMoved: v => seekDebounce.restart()
                Timer {
                    id: seekDebounce
                    interval: 120
                    onTriggered: media.backend.seek(seek.dragValue * media.backend.length)
                }
            }
            Text {
                textFormat: Text.PlainText
                text: "-" + media.formatTime(media.backend.length - (seek.pressed ? seek.dragValue * media.backend.length : media.backend.position))
                color: media.theme.subText
                font.pointSize: media.theme.fontSmall
                font.features: { "tnum": 1 }
            }
        }

        // Transport + player volume
        RowLayout {
            Layout.fillWidth: true
            spacing: 2

            Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }

            IconButton {
                iconName: "media-skip-backward-symbolic"
                iconSize: Kirigami.Units.iconSizes.smallMedium
                color: media.theme.text
                hoverColor: media.theme.faint
                enabled: media.backend.canGoPrevious
                onClicked: media.backend.previous()
            }
            IconButton {
                iconName: media.backend.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                iconSize: Kirigami.Units.iconSizes.medium
                color: media.theme.text
                hoverColor: media.theme.faint
                enabled: media.backend.canControl
                onClicked: media.backend.playPause()
            }
            IconButton {
                iconName: "media-skip-forward-symbolic"
                iconSize: Kirigami.Units.iconSizes.smallMedium
                color: media.theme.text
                hoverColor: media.theme.faint
                enabled: media.backend.canGoNext
                onClicked: media.backend.next()
            }

            Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }

            Kirigami.Icon {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                source: "audio-volume-medium-symbolic"
                color: media.theme.subText
                isMask: true
            }
            GlassSlider {
                Layout.preferredWidth: 70
                value: media.backend.playerVolume
                fillColor: media.theme.subText
                trackColor: media.theme.track
                thickness: 4
                onMoved: v => media.backend.setPlayerVolume(v)
            }
        }
    }

    // Empty state
    ColumnLayout {
        anchors.centerIn: parent
        visible: !layout.visible
        spacing: 6
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            source: "media-playback-stopped-symbolic"
            color: media.theme.subText
            isMask: true
        }
        Text {
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignHCenter
            text: Lang.i18n("Nothing is playing")
            color: media.theme.subText
            font.pointSize: media.theme.fontNormal
        }
    }
}
