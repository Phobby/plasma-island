/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Generic compact presentation: leading icon · title · trailing (text or ring).
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: compact

    required property var activity
    required property Theme theme

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        ActivityIcon {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            icon: compact.activity?.icon ?? ""
            color: compact.activity?.color ?? compact.theme.text
            pulse: compact.activity?.pulse ?? false
            running: compact.visible
        }
        Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: compact.activity?.title ?? ""
            color: compact.theme.subText
            font.pointSize: compact.theme.fontSmall
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            textFormat: Text.PlainText
            visible: text.length > 0
            text: compact.activity?.trailingText ?? ""
            color: compact.activity?.color ?? compact.theme.text
            font.pointSize: compact.theme.fontNormal
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        MiniRing {
            visible: (compact.activity?.progress ?? -1) >= 0 || indeterminate
            indeterminate: (compact.activity?.progress ?? -1) === -2
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            value: compact.activity?.progress ?? 0
            color: compact.activity?.color ?? compact.theme.text
            trackColor: compact.theme.track
        }
    }
}
