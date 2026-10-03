/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Expanded view of running transfers: "source → target: file", percentage,
    speed, remaining time (only when known), pause / cancel when supported.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "TransferFormat.js" as Fmt

Rectangle {
    id: card

    required property var activity
    required property Theme theme
    readonly property var transfers: activity?.transfers ?? []

    implicitHeight: column.implicitHeight + 16
    radius: 14
    color: theme.faint

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            model: card.transfers
            delegate: ColumnLayout {
                id: row
                required property var modelData
                readonly property var t: modelData
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    spacing: 8
                    Kirigami.Icon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        source: row.t.icon
                        color: card.theme.text
                        isMask: true
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.t.headline
                            color: card.theme.text
                            font.pointSize: card.theme.fontSmall
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                        }
                        Text {
                            Layout.fillWidth: true
                            text: [row.t.detail,
                                   row.t.speed > 0 ? Fmt.bytes(row.t.speed) + "/s" : "",
                                   row.t.percent < 0 && row.t.processedBytes > 0 ? Fmt.bytes(row.t.processedBytes) : "",
                                   row.t.remaining > 0 ? Lang.i18nc("@info remaining time m:ss", "%1 left", Fmt.eta(row.t.remaining)) : "",
                                   row.t.suspended ? Lang.i18n("Paused") : ""].filter(s => s).join(" · ")
                            color: card.theme.subText
                            font.pointSize: card.theme.fontSmall
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        visible: row.t.percent >= 0
                        text: Lang.percent(Math.round(row.t.percent))
                        color: card.theme.text
                        font.pointSize: card.theme.fontSmall
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    IconButton {
                        visible: typeof row.t.suspendFn === "function"
                        iconName: row.t.suspended ? "media-playback-start-symbolic" : "media-playback-pause-symbolic"
                        color: card.theme.text
                        hoverColor: card.theme.hoverFill
                        onClicked: row.t.suspended ? row.t.resumeFn() : row.t.suspendFn()
                    }
                    IconButton {
                        visible: typeof row.t.cancelFn === "function"
                        iconName: "dialog-cancel-symbolic"
                        color: card.theme.readable(card.theme.red, card.theme.faint)
                        hoverColor: card.theme.hoverFill
                        onClicked: row.t.cancelFn()
                    }
                }
                // progress bar (indeterminate: a sliding segment)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: card.theme.track
                    clip: true
                    Rectangle {
                        visible: row.t.percent >= 0
                        width: parent.width * Math.max(0, Math.min(1, row.t.percent / 100))
                        height: parent.height
                        radius: 2
                        color: row.t.suspended ? card.theme.subText : card.activity.color
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                    Rectangle {
                        visible: row.t.percent < 0
                        width: parent.width * 0.3
                        height: parent.height
                        radius: 2
                        color: card.activity.color
                        SequentialAnimation on x {
                            running: row.t.percent < 0 && card.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: -card.width * 0.3; to: card.width; duration: 1200; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }
        }
    }
}
