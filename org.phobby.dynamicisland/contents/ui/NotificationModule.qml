/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Notification center: most recent first, each with its arrival time
    (HH:mm), quick reply, and a clear-all button with a confirmation bubble.
    Only instantiates delegates while shown (model is detached otherwise).
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
    onActiveChanged: if (!active) { replyTarget = null; confirmingClear = false; }
    property bool confirmingClear: false
    readonly property int count: backend.notificationCount
    function requestClear(): void { confirmingClear = true; }
    function confirmClear(): void {
        backend.clearAllNotifications();
        confirmingClear = false;
    }
    property int maximumCount: 3
    readonly property real rowHeight: 36

    implicitHeight: rowHeight * maximumCount + 4 * (maximumCount - 1)

    // Arrival time: "14:32" today, "30 Sep 14:32" otherwise.
    function arrivalTime(d: date): string {
        const now = new Date();
        const today = d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
        return today ? Qt.formatTime(d, "HH:mm") : Qt.locale().toString(d, "d MMM HH:mm");
    }

    // Header: count + clear-all
    RowLayout {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 22
        visible: notif.count > 0
        Text {
            Layout.fillWidth: true
            leftPadding: 6
            text: i18np("%1 notification", "%1 notifications", notif.count)
            color: notif.theme.subText
            font.pointSize: notif.theme.fontSmall
        }
        IconButton {
            id: clearButton
            iconName: "window-close-symbolic"
            iconSize: 12
            toolTip: i18n("Clear all notifications")
            color: notif.theme.text
            hoverColor: notif.theme.hoverFill
            onClicked: notif.requestClear()
        }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: header.visible ? header.bottom : parent.top; bottom: parent.bottom; topMargin: header.visible ? 2 : 0 }
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        spacing: 4
        clip: true
        model: notif.active ? notif.backend.notificationModel : null

        delegate: Rectangle {
            id: row
            required property int index
            required property var model
            width: ListView.view.width
            height: notif.rowHeight
            radius: 12
            color: rowHover.hovered ? notif.theme.faint : "transparent"

            // Hovered even while the pointer is on one of the buttons.
            HoverHandler { id: rowHover }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: notif.backend.activateNotification(row.model.notificationId)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 4
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
                    Layout.minimumWidth: 0
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
                // Arrival time; under the mouse its place goes to reply and dismiss.
                Text {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 3
                    Layout.rightMargin: 4
                    visible: !rowHover.hovered
                    text: row.model.created ? notif.arrivalTime(row.model.created) : ""
                    font.features: { "tnum": 1 }
                    color: notif.theme.subText
                    font.pointSize: notif.theme.fontSmall * 0.95
                }
                Row {
                    visible: rowHover.hovered
                    spacing: 0
                    // Quick reply (SMS / messengers via KDE Connect or apps that support it)
                    IconButton {
                        visible: row.model.hasReplyAction === true
                        iconName: "mail-reply-sender-symbolic"
                        iconSize: 12
                        implicitWidth: 24; implicitHeight: 24
                        toolTip: i18n("Reply")
                        color: notif.theme.text
                        hoverColor: notif.theme.hoverFill
                        onClicked: notif.replyTarget = { id: row.model.notificationId, summary: row.model.summary || row.model.applicationName }
                    }
                    IconButton {
                        iconName: "window-close-symbolic"
                        iconSize: 12
                        implicitWidth: 24; implicitHeight: 24
                        toolTip: i18n("Dismiss")
                        color: notif.theme.text
                        hoverColor: notif.theme.hoverFill
                        onClicked: notif.backend.closeNotification(row.model.notificationId)
                    }
                }
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

    // Clear-all confirmation bubble (anchored under the X button)
    Rectangle {
        id: confirm
        visible: notif.confirmingClear
        z: 10
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 2
        width: confirmRow.implicitWidth + 20
        height: confirmRow.implicitHeight + 16
        radius: 14
        color: notif.theme.over(notif.theme.pressedFill, notif.theme.surface)
        border.width: 1
        border.color: notif.theme.rimBottom
        scale: visible ? 1 : 0.8
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

        RowLayout {
            id: confirmRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: i18n("Clear all notifications?")
                color: notif.theme.text
                font.pointSize: notif.theme.fontSmall
                font.weight: Font.DemiBold
            }
            Rectangle {
                implicitWidth: cancelLabel.implicitWidth + 18
                implicitHeight: 24
                radius: 12
                color: cancelMouse.pressed ? notif.theme.pressedFill : cancelMouse.containsMouse ? notif.theme.hoverFill : notif.theme.faint
                Text { id: cancelLabel; anchors.centerIn: parent; text: i18n("Cancel"); color: notif.theme.text; font.pointSize: notif.theme.fontSmall }
                MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: notif.confirmingClear = false }
            }
            Rectangle {
                implicitWidth: deleteLabel.implicitWidth + 18
                implicitHeight: 24
                radius: 12
                color: deleteMouse.pressed ? Qt.darker(notif.theme.red, 1.25) : deleteMouse.containsMouse ? Qt.lighter(notif.theme.red, 1.1) : notif.theme.red
                Text { id: deleteLabel; anchors.centerIn: parent; text: i18n("Clear"); color: notif.theme.onColor(notif.theme.red); font.pointSize: notif.theme.fontSmall; font.weight: Font.DemiBold }
                MouseArea {
                    id: deleteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notif.confirmClear()
                }
            }
        }
    }
}
