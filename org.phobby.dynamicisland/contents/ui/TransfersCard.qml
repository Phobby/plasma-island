/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Expanded view of running transfers: "source → target: file", the stage,
    "412 MB / 1.8 GB" ("412 MB / unknown" when the size is not known), the
    percentage, the speed, the remaining time (only when the size is known; "—"
    while it cannot be told), the time so far; pause / cancel when supported.
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
    // Sizes in the language's own form ("1,8 GB" in Turkish).
    function size(bytes: real): string { return Fmt.bytes(bytes, Lang.language === "tr"); }
    // The time passed is counted here, once a second, only while the card is shown.
    property real now: Date.now()
    Timer { interval: 1000; repeat: true; running: card.visible && card.transfers.length > 0; triggeredOnStart: true; onTriggered: card.now = Date.now() }

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
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: row.t.headline
                            color: card.theme.text
                            font.pointSize: card.theme.fontSmall
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                        }
                        // the stage, and how much of how much
                        Text {
                            textFormat: Text.PlainText
                            objectName: "transferAmount"
                            Layout.fillWidth: true
                            text: [row.t.suspended ? Lang.i18n("Paused") : row.t.stalled > 60 ? Lang.i18n("Stalled") : row.t.stalled > 5 ? Lang.i18n("Waiting") : row.t.detail,
                                   row.t.totalKnown ? Lang.i18nc("@info bytes done / bytes in all", "%1 / %2", card.size(row.t.processedBytes), card.size(row.t.totalBytes))
                                   : row.t.processedBytes > 0 ? Lang.i18nc("@info bytes done / bytes in all", "%1 / %2", card.size(row.t.processedBytes), Lang.i18n("unknown")) : ""
                                  ].filter(s => s).join(" · ")
                            color: card.theme.subText
                            font.pointSize: card.theme.fontSmall
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                        }
                        // how fast, how long still (only where the size is known), how long so far
                        Text {
                            textFormat: Text.PlainText
                            objectName: "transferPace"
                            Layout.fillWidth: true
                            readonly property real elapsed: row.t.startedAt > 0 ? Math.max(0, (card.now - row.t.startedAt) / 1000) : -1
                            text: [row.t.speed > 0 ? Lang.i18nc("@info bytes per second", "%1/s", card.size(row.t.speed)) : "",
                                   row.t.remaining > 0 ? Lang.i18nc("@info remaining time m:ss", "%1 left", Fmt.eta(row.t.remaining))
                                   : row.t.totalKnown ? "—" : "",
                                   elapsed >= 1 ? Lang.i18nc("@info time passed m:ss", "%1 so far", Fmt.duration(elapsed)) : ""].filter(s => s).join(" · ")
                            visible: text.length > 0
                            color: card.theme.subText
                            font.pointSize: card.theme.fontSmall * 0.95
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        textFormat: Text.PlainText
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
