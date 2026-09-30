/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Compact list of the most recent notifications. Only instantiates
    delegates while shown (model is detached otherwise).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: notif

    required property Theme theme
    required property PlasmaBackend backend
    property bool active: false
    // Quick reply in progress (the island then takes keyboard focus).
    readonly property bool replying: replyTarget !== null
    property var replyTarget: null     // { id, summary }
    onActiveChanged: if (!active) replyTarget = null
    property int maximumCount: 3
    readonly property real rowHeight: 36

    implicitHeight: rowHeight * maximumCount + 4 * (maximumCount - 1)

    function timeAgo(d: date): string {
        const s = Math.max(0, (Date.now() - d.getTime()) / 1000);
        if (s < 60) return i18nc("@label time", "now");
        if (s < 3600) return i18nc("@label minutes ago, short", "%1m", Math.floor(s / 60));
        if (s < 86400) return i18nc("@label hours ago, short", "%1h", Math.floor(s / 3600));
        return Qt.formatDate(d, Qt.locale().dateFormat(Locale.ShortFormat));
    }

    ListView {
        id: list
        anchors.fill: parent
        interactive: false
        spacing: 4
        clip: true
        model: notif.active ? notif.backend.notificationModel : null

        delegate: Rectangle {
            id: row
            required property int index
            required property var model
            width: ListView.view.width
            height: notif.rowHeight
            visible: index < notif.maximumCount
            radius: 12
            color: rowMouse.containsMouse ? notif.theme.faint : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 8
                spacing: 8

                Kirigami.Icon {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    source: row.model.image || row.model.iconName || row.model.applicationIconName || "preferences-desktop-notification-bell"

                    PhoneBadge {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -4
                        width: 12
                        height: 12
                        visible: row.model.notifyRcName === "kdeconnect"
                        tint: notif.theme.blue
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: row.model.summary || row.model.applicationName || ""
                        color: notif.theme.text
                        font.pointSize: notif.theme.fontSmall
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: notif.backend.plainText(row.model.body || "")
                        color: notif.theme.subText
                        font.pointSize: notif.theme.fontSmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 3
                    text: row.model.created ? notif.timeAgo(row.model.created) : ""
                    color: notif.theme.subText
                    font.pointSize: notif.theme.fontSmall * 0.95
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notif.backend.activateNotification(row.model.notificationId)
            }
            // Quick reply (SMS / messengers via KDE Connect or apps that support it)
            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                visible: row.model.hasReplyAction === true && rowMouse.containsMouse
                iconName: "mail-reply-sender-symbolic"
                toolTip: i18n("Reply")
                color: notif.theme.text
                hoverColor: notif.theme.faint
                onClicked: notif.replyTarget = { id: row.model.notificationId, summary: row.model.summary || row.model.applicationName }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: list.count === 0
        spacing: 6
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            source: "notifications-disabled-symbolic"
            color: notif.theme.subText
            isMask: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("No notifications")
            color: notif.theme.subText
            font.pointSize: notif.theme.fontNormal
        }
    }

    // Reply bar
    Rectangle {
        anchors.fill: parent
        visible: notif.replying
        radius: 14
        color: notif.theme.bodyMid

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: i18n("Reply to %1", notif.replyTarget?.summary ?? "")
                color: notif.theme.subText
                font.pointSize: notif.theme.fontSmall
                elide: Text.ElideRight
            }
            RowLayout {
                spacing: 6
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 15
                    color: notif.theme.faint
                    border.width: 1
                    border.color: replyInput.activeFocus ? notif.theme.blue : "transparent"
                    TextInput {
                        id: replyInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: notif.theme.text
                        font.pointSize: notif.theme.fontNormal
                        clip: true
                        onAccepted: sendButton.clicked()
                        Keys.onEscapePressed: notif.replyTarget = null
                    }
                }
                IconButton {
                    id: sendButton
                    iconName: "document-send-symbolic"
                    color: notif.theme.blue
                    hoverColor: notif.theme.faint
                    enabled: replyInput.text.length > 0
                    onClicked: {
                        notif.backend.replyToNotification(notif.replyTarget.id, replyInput.text);
                        replyInput.text = "";
                        notif.replyTarget = null;
                    }
                }
                IconButton {
                    iconName: "dialog-cancel-symbolic"
                    color: notif.theme.subText
                    hoverColor: notif.theme.faint
                    onClicked: notif.replyTarget = null
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
    onReplyingChanged: if (replying) Qt.callLater(() => replyInput.forceActiveFocus())
}
