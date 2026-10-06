/*
    SPDX-License-Identifier: GPL-2.0-or-later
    An event that asks something: its icon, one sentence, and the event's
    buttons under it ("Yes · Always · No", and behind "⋯" those marked `more`).
    Several things for one moment are ticks (`checks`), each switched by
    itself. A button answers; the cross or a middle click closes it without
    an answer.
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: banner

    required property Theme theme
    property var event: null
    readonly property var buttons: event !== null && Array.isArray(event.buttons) ? event.buttons : []
    readonly property color accent: event?.color ?? theme.text
    readonly property var checks: event !== null && Array.isArray(event.checks) ? event.checks : []
    readonly property bool hasMore: buttons.some(b => b.more === true)
    property bool more: false
    // counts the ticks' changes (they are plain objects of the event)
    property int ticked: 0

    signal chosen(int index)
    signal dismissed()

    onEventChanged: { more = false; if (event) appear.restart(); }
    ParallelAnimation {
        id: appear
        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "scale"; from: 0.94; to: 1; duration: 380; easing.type: Easing.OutBack }
    }

    MouseArea {
        id: bannerMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton
        onClicked: banner.dismissed()
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 9
        anchors.bottomMargin: 9
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            ActivityIcon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignTop
                icon: banner.event?.icon ?? ""
                color: banner.accent
                running: banner.visible
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: banner.event?.title ?? ""
                    color: banner.theme.text
                    font.pointSize: banner.theme.fontSmall
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: banner.event?.subtitle ?? ""
                    color: banner.theme.subText
                    font.pointSize: banner.theme.fontSmall * 0.9
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
            IconButton {
                Layout.alignment: Qt.AlignTop
                iconName: "window-close-symbolic"
                iconSize: 10
                implicitWidth: 18; implicitHeight: 18
                color: banner.theme.subText
                hoverColor: banner.theme.faint
                onClicked: banner.dismissed()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: banner.checks.length > 0
            spacing: 6
            Repeater {
                model: banner.checks.length
                delegate: PillButton {
                    required property int index
                    readonly property var check: banner.checks[index] ?? null
                    readonly property bool on: banner.ticked >= 0 && check !== null && check.checked === true
                    objectName: "suggestionCheck"
                    theme: banner.theme
                    implicitHeight: 22
                    primary: on
                    tint: banner.theme.control
                    text: (on ? "☑ " : "☐ ") + (check !== null ? check.text : "")
                    onClicked: { check.checked = !check.checked; ++banner.ticked; }
                }
            }
            Item { Layout.fillWidth: true }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Item { Layout.fillWidth: true }
            Repeater {
                model: banner.buttons.length
                delegate: PillButton {
                    required property int index
                    readonly property var button: banner.buttons[index] ?? null
                    visible: button !== null && (button.more === true) === banner.more
                    theme: banner.theme
                    implicitHeight: 24
                    primary: button !== null && button.primary === true
                    tint: banner.theme.control
                    text: button !== null ? button.text : ""
                    onClicked: banner.chosen(index)
                }
            }
            PillButton {
                objectName: "suggestionMore"
                visible: banner.hasMore
                theme: banner.theme
                implicitHeight: 24
                tint: banner.theme.control
                text: banner.more ? "‹" : "⋯"
                onClicked: banner.more = !banner.more
            }
        }
    }
}
