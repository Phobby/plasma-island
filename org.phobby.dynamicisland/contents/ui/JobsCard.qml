/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Expanded view of running jobs: file, speed, remaining time, pause / cancel.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: card

    required property var activity
    required property Theme theme
    readonly property var jobs: activity?.jobs ?? []

    implicitHeight: column.implicitHeight + 16
    radius: 14
    color: theme.faint

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Repeater {
            model: card.jobs
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    spacing: 8
                    Kirigami.Icon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        source: modelData.icon || card.activity.icon
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: modelData.detail || modelData.summary
                            color: card.theme.text
                            font.pointSize: card.theme.fontSmall
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                        }
                        Text {
                            Layout.fillWidth: true
                            text: [modelData.summary,
                                   modelData.speed > 0 ? card.activity.formatBytes(modelData.speed) + "/s" : "",
                                   card.activity.formatEta(modelData.eta),
                                   modelData.suspended ? i18n("Paused") : ""].filter(s => s).join(" · ")
                            color: card.theme.subText
                            font.pointSize: card.theme.fontSmall
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        text: modelData.percentage + "%"
                        color: card.theme.text
                        font.pointSize: card.theme.fontSmall
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    IconButton {
                        visible: modelData.job && modelData.job.suspendable
                        iconName: modelData.suspended ? "media-playback-start-symbolic" : "media-playback-pause-symbolic"
                        color: card.theme.text
                        hoverColor: card.theme.faint
                        onClicked: modelData.suspended ? modelData.job.resume() : modelData.job.suspend()
                    }
                    IconButton {
                        visible: modelData.job && modelData.job.killable
                        iconName: "dialog-cancel-symbolic"
                        color: card.theme.red
                        hoverColor: card.theme.faint
                        onClicked: modelData.job.kill()
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: card.theme.track
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, modelData.percentage / 100))
                        height: parent.height
                        radius: 2
                        color: modelData.suspended ? card.theme.subText : card.activity.color
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }
        }
    }
}
