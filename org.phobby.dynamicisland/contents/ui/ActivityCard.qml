/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Generic expanded card: icon, title, subtitle, trailing text, progress bar
    and the activity's actions.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: card

    required property var activity
    required property Theme theme

    implicitHeight: layout.implicitHeight + 16
    radius: 14
    color: theme.faint

    MouseArea {
        anchors.fill: parent
        onClicked: card.activity?.clicked()
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        RowLayout {
            spacing: 8
            ActivityIcon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                icon: card.activity?.icon ?? ""
                color: card.activity?.color ?? card.theme.text
                pulse: card.activity?.pulse ?? false
                running: card.visible
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: card.activity?.title ?? ""
                    color: card.theme.text
                    font.pointSize: card.theme.fontSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: card.activity?.subtitle ?? ""
                    color: card.theme.subText
                    font.pointSize: card.theme.fontSmall
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
            }
            Text {
                visible: text.length > 0
                text: card.activity?.trailingText ?? ""
                color: card.activity?.color ?? card.theme.text
                font.pointSize: card.theme.fontNormal
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Repeater {
                model: card.activity?.actions ?? []
                delegate: IconButton {
                    required property var modelData
                    iconName: modelData.icon
                    toolTip: modelData.text ?? ""
                    color: card.theme.text
                    hoverColor: card.theme.faint
                    onClicked: modelData.trigger()
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            visible: (card.activity?.progress ?? -1) >= 0
            Layout.preferredHeight: 4
            radius: 2
            color: card.theme.track
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, card.activity?.progress ?? 0))
                height: parent.height
                radius: 2
                color: card.activity?.color ?? card.theme.text
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }
    }
}
