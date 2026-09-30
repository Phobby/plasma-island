/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Transient system event: leading icon · title/subtitle · trailing widget.
    trailing.type: "ring" (value 0..1), "battery" (value 0..1, charging),
                   "slider" (value 0..1), "text", "dot"
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: banner

    required property Theme theme
    property var event: null
    readonly property var trailing: event?.trailing ?? null
    readonly property color accent: event?.color ?? theme.text

    signal activated()

    // Soft "appear" for every new event, like iOS.
    onEventChanged: if (event) appear.restart()
    ParallelAnimation {
        id: appear
        NumberAnimation { target: row; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: row; property: "scale"; from: 0.9; to: 1; duration: 380; easing.type: Easing.OutBack }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        ActivityIcon {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            icon: banner.event?.icon ?? ""
            color: banner.accent
            pulse: banner.event?.pulse ?? false
            running: banner.visible
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: banner.event?.title ?? ""
                color: banner.theme.text
                font.pointSize: banner.theme.fontNormal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: banner.event?.subtitle ?? ""
                color: banner.theme.subText
                font.pointSize: banner.theme.fontSmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // trailing: ring
        MiniRing {
            visible: banner.trailing?.type === "ring"
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            value: banner.trailing?.value ?? 0
            color: banner.trailing?.color ?? banner.accent
            trackColor: banner.theme.track
            text: banner.trailing?.text ?? ""
            textColor: banner.theme.text
        }
        // trailing: battery
        BatteryGlyph {
            visible: banner.trailing?.type === "battery"
            Layout.preferredWidth: 30
            Layout.preferredHeight: 14
            value: banner.trailing?.value ?? 0
            charging: banner.trailing?.charging ?? false
            color: banner.trailing?.color ?? banner.accent
            running: banner.visible
        }
        // trailing: slider
        Rectangle {
            visible: banner.trailing?.type === "slider"
            Layout.preferredWidth: 90
            Layout.preferredHeight: 5
            radius: 2.5
            color: banner.theme.track
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, banner.trailing?.value ?? 0))
                height: parent.height
                radius: parent.radius
                color: banner.trailing?.color ?? banner.theme.text
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }
        // trailing: text (percentages etc.)
        Text {
            visible: (banner.trailing?.text ?? "").length > 0 && banner.trailing?.type !== "ring"
            text: banner.trailing?.text ?? ""
            color: banner.trailing?.color ?? banner.accent
            font.pointSize: banner.theme.fontNormal
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: typeof banner.event?.activate === "function" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: banner.activated()
    }
}
