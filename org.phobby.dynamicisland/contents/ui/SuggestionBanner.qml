/*
    SPDX-License-Identifier: GPL-2.0-or-later
    An event that asks something: its icon, one sentence, and the event's
    buttons under it ("Yes · Not now · Never suggest this"). A button answers;
    the cross or a middle click closes it without an answer.
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: banner

    required property Theme theme
    property var event: null
    readonly property var buttons: event !== null && Array.isArray(event.buttons) ? event.buttons : []
    readonly property color accent: event?.color ?? theme.text

    signal chosen(int index)
    signal dismissed()

    onEventChanged: if (event) appear.restart()
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
            spacing: 6
            Item { Layout.fillWidth: true }
            Repeater {
                model: banner.buttons.length
                delegate: PillButton {
                    required property int index
                    readonly property var button: banner.buttons[index] ?? null
                    theme: banner.theme
                    implicitHeight: 24
                    primary: button !== null && button.primary === true
                    tint: banner.theme.control
                    text: button !== null ? button.text : ""
                    onClicked: banner.chosen(index)
                }
            }
        }
    }
}
