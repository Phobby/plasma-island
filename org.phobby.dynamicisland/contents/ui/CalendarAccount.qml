/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Sign in to Apple iCloud so events can be added and deleted from the island
    (CalDavClient). Shows the connected account once that is done.
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: accountPage

    required property Theme theme
    required property var client            // CalDavClient
    signal finished()
    signal cancelled()

    property string error: ""
    property bool busy: false
    readonly property bool interacting: true
    readonly property string passwordsUrl: "https://account.apple.com/account/manage"

    function reset(): void {
        error = ""; busy = false;
        userField.text = client.account.user; passwordField.text = "";
        Qt.callLater(() => { (userField.text.length > 0 ? passwordField : userField).input.forceActiveFocus(); });
    }
    function submit(): void {
        if (busy) return;
        if (userField.text.trim().length === 0 || passwordField.text.trim().length === 0) { error = Lang.i18n("Enter your Apple ID and the app-specific password."); return; }
        busy = true; error = "";
        client.connect(userField.text, passwordField.text, result => {
            busy = false;
            if (!result.ok) { error = result.error; return; }
            passwordField.text = "";
            accountPage.finished();
        });
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: Lang.i18n("iCloud account")
                color: accountPage.theme.text
                font.pointSize: accountPage.theme.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            IconButton {
                iconName: "window-close-symbolic"
                color: accountPage.theme.subText
                hoverColor: accountPage.theme.faint
                onClicked: accountPage.cancelled()
            }
        }

        IslandFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: info.implicitHeight
            Text {
                id: info
                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                linkColor: accountPage.theme.readable(accountPage.theme.control, accountPage.theme.surface)
                color: accountPage.error.length > 0 ? accountPage.theme.readable(accountPage.theme.danger, accountPage.theme.surface) : accountPage.theme.text
                font.pointSize: accountPage.theme.fontSmall * 0.9
                text: accountPage.error.length > 0 ? accountPage.error
                    : accountPage.client.ready
                        ? Lang.i18n("Connected: %1 · %2 calendars.", accountPage.client.account.user, accountPage.client.account.calendars.length) + " "
                          + (accountPage.client.core && accountPage.client.core.secretsAvailable ? Lang.i18n("The password is kept in KDE Wallet.")
                                                                                                  : Lang.i18n("The password is only kept for this session; it is asked for again after a restart."))
                    : accountPage.client.connected
                        ? Lang.i18n("The password of %1 was not found. Enter the app-specific password again.", accountPage.client.account.user)
                    : Lang.i18n("With your account all your calendars are shown and you can add events. Create a password at <a href=\"%1\">account.apple.com</a> → Sign-In and Security → App-Specific Passwords and enter it here. Your normal Apple password does not work.", accountPage.passwordsUrl)
                onLinkActivated: link => Qt.openUrlExternally(link)
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            PillField {
                id: userField
                visible: !accountPage.client.ready
                theme: accountPage.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                placeholder: Lang.i18n("Apple ID (email)")
                enabled: !accountPage.busy
                onEdited: accountPage.error = ""
                onAccepted: passwordField.input.forceActiveFocus()
                onEscaped: accountPage.cancelled()
            }
            PillField {
                id: passwordField
                visible: !accountPage.client.ready
                theme: accountPage.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                secret: true
                placeholder: Lang.i18n("App-specific password")
                enabled: !accountPage.busy
                onEdited: accountPage.error = ""
                onAccepted: accountPage.submit()
                onEscaped: accountPage.cancelled()
            }
            PillButton {
                visible: !accountPage.client.ready
                theme: accountPage.theme
                primary: true
                text: accountPage.busy ? Lang.i18n("Connecting…") : Lang.i18n("Connect")
                enabled: !accountPage.busy
                onClicked: accountPage.submit()
            }
            Item { visible: accountPage.client.ready; Layout.fillWidth: true }
            PillButton {
                visible: accountPage.client.ready
                theme: accountPage.theme
                text: Lang.i18n("Remove account")
                onClicked: { accountPage.client.disconnect(); accountPage.reset(); }
            }
        }
    }
}
