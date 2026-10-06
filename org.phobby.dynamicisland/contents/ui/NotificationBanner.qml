/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Transient banner for an incoming notification. Click runs the default action.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: banner

    required property Theme theme
    property var notification: null

    signal activated()
    signal dismissed()

    // Pop in when the notification changes while already visible.
    onNotificationChanged: if (notification) popAnim.restart()

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 12

        Kirigami.Icon {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            source: banner.notification?.icon ?? ""

            PhoneBadge {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -3
                visible: banner.notification?.notifyRcName === "kdeconnect"
                tint: banner.theme.control
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: banner.notification?.appName ?? ""
                visible: text.length > 0
                color: banner.theme.subText
                font.pointSize: banner.theme.fontSmall
                elide: Text.ElideRight
            }
            Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: banner.notification?.summary ?? ""
                color: banner.theme.text
                font.pointSize: banner.theme.fontNormal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: banner.notification?.body ?? ""
                visible: text.length > 0
                color: banner.theme.subText
                font.pointSize: banner.theme.fontSmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: row; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => mouse.button === Qt.MiddleButton ? banner.dismissed() : banner.activated()
    }
}
