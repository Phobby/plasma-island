/*
    SPDX-License-Identifier: GPL-2.0-or-later
    One system metric. Small: ring + caption. Large (active / wide): ring
    beside title, detail and a second detail line.
*/
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    required property Theme theme
    property var metric: ({})
    property bool large: false
    readonly property alias hovered: hover.hovered

    radius: 14
    color: large && metric.active ? theme.over(Qt.rgba(metric.color.r, metric.color.g, metric.color.b, 0.12), theme.over(theme.faint, theme.surface))
         : hovered ? theme.over(theme.hoverFill, theme.over(theme.faint, theme.surface))
         : theme.faint
    Behavior on color { ColorAnimation { duration: 250 } }

    HoverHandler { id: hover }

    // small
    ColumnLayout {
        anchors.centerIn: parent
        visible: !card.large
        spacing: 2
        MiniRing {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(40, card.height - 24)
            Layout.preferredHeight: Layout.preferredWidth
            lineWidth: 3.5
            value: card.metric.value ?? 0
            color: card.metric.color ?? card.theme.text
            trackColor: card.theme.track
            text: card.metric.ringText ?? ""
            textColor: card.theme.text
            fontSize: card.theme.fontSmall * 0.8
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: card.metric.caption ?? ""
            color: card.theme.subText
            font.pointSize: card.theme.fontSmall * 0.9
        }
    }

    // large
    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        visible: card.large
        spacing: 10
        MiniRing {
            Layout.preferredWidth: Math.min(46, card.height - 16)
            Layout.preferredHeight: Layout.preferredWidth
            lineWidth: 4
            value: card.metric.value ?? 0
            color: card.metric.color ?? card.theme.text
            trackColor: card.theme.track
            text: card.metric.ringText ?? ""
            textColor: card.theme.text
            fontSize: card.theme.fontSmall * 0.85
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: card.metric.caption ?? ""
                color: card.theme.text
                font.pointSize: card.theme.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: card.metric.detail ?? ""
                visible: text.length > 0
                color: card.theme.text
                font.pointSize: card.theme.fontSmall
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: card.metric.detail2 ?? ""
                visible: text.length > 0
                color: card.theme.subText
                font.pointSize: card.theme.fontSmall * 0.9
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
            }
        }
    }
}
