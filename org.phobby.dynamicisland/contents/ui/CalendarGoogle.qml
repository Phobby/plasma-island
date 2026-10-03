/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Connect the Google account (GoogleCalendar): explains the steps, opens the
    browser for Google's sign-in and waits for the approval. Before that can
    work once, the OAuth client registered in Google Cloud is asked for.
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: googlePage

    required property Theme theme
    required property var google            // GoogleCalendar
    signal finished()
    signal cancelled()
    signal clientSaved(string id, string secret)

    property string error: ""
    property bool editingClient: false
    // "client" (register the OAuth client) | "waiting" (browser) | "done" | "start"
    readonly property string step: !google.configured || editingClient ? "client" : google.signingIn ? "waiting" : google.ready ? "done" : "start"
    readonly property bool interacting: step === "client"
    readonly property string consoleUrl: "https://console.cloud.google.com/apis/credentials"

    function reset(): void {
        error = ""; editingClient = false;
        idField.text = google.clientId; secretField.text = google.clientSecret;
        if (step === "client") Qt.callLater(() => idField.input.forceActiveFocus());
    }
    function saveClient(): void {
        if (idField.text.trim().length === 0) { error = Lang.i18n("Paste the client ID."); return; }
        error = "";
        clientSaved(idField.text.trim(), secretField.text.trim());
        editingClient = false;
    }
    Connections {
        target: googlePage.google
        function onReadyChanged() { if (googlePage.google.ready && googlePage.visible) googlePage.finished(); }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: Lang.i18n("Google account")
                color: googlePage.theme.text
                font.pointSize: googlePage.theme.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            IconButton {
                iconName: "window-close-symbolic"
                color: googlePage.theme.subText
                hoverColor: googlePage.theme.faint
                onClicked: googlePage.cancelled()
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: info.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Text {
                id: info
                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                linkColor: googlePage.theme.readable(googlePage.theme.control, googlePage.theme.surface)
                readonly property string problem: googlePage.error.length > 0 ? googlePage.error : googlePage.step === "start" ? googlePage.google.signInError : ""
                color: googlePage.theme.text
                font.pointSize: googlePage.theme.fontSmall * 0.9
                text: (problem.length > 0 ? "<font color=\"" + googlePage.theme.readable(googlePage.theme.danger, googlePage.theme.surface) + "\">" + problem + "</font><br>" : "")
                    + (googlePage.step === "client"
                        ? Lang.i18n("Google only gives access to an account through a registered app; this is done once:<br>1. Open a project in the <a href=\"%1\">Google Cloud Console</a> and enable the \"Google Calendar API\".<br>2. Set up the OAuth consent screen (External) and add yourself as a test user.<br>3. Clients → Create client → \"Desktop app\".<br>4. Paste the client ID and client secret it gives you below.", googlePage.consoleUrl)
                     : googlePage.step === "waiting"
                        ? Lang.i18n("The browser has opened:<br>1. Choose your Google account.<br>2. Allow access to your calendars.<br>3. Come back here once the page says \"Sent to the island\".<br>Waiting…")
                     : googlePage.step === "done"
                        ? Lang.i18n("Connected: %1 · %2 calendars. All your calendars are shown and you can add events.", googlePage.google.account.user, googlePage.google.account.calendars.length)
                        : Lang.i18n("1. Press \"Sign in with Google\"; the browser opens.<br>2. Choose your Google account and allow calendar access.<br>3. All your calendars appear here.<br>Your password never reaches the island; you can withdraw the access in your Google account at any time."))
                onLinkActivated: link => Qt.openUrlExternally(link)
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            PillField {
                id: idField
                visible: googlePage.step === "client"
                theme: googlePage.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                placeholder: Lang.i18n("Client ID")
                onEdited: googlePage.error = ""
                onAccepted: secretField.input.forceActiveFocus()
                onEscaped: googlePage.cancelled()
            }
            PillField {
                id: secretField
                visible: googlePage.step === "client"
                theme: googlePage.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                secret: true
                placeholder: Lang.i18n("Client secret")
                onEdited: googlePage.error = ""
                onAccepted: googlePage.saveClient()
                onEscaped: googlePage.cancelled()
            }
            PillButton {
                visible: googlePage.step === "client"
                theme: googlePage.theme
                primary: true
                text: Lang.i18n("Save")
                onClicked: googlePage.saveClient()
            }
            Item { visible: googlePage.step !== "client"; Layout.fillWidth: true }
            PillButton {
                visible: googlePage.step === "start"
                theme: googlePage.theme
                text: Lang.i18n("Change client")
                onClicked: { googlePage.reset(); googlePage.editingClient = true; idField.input.forceActiveFocus(); }
            }
            PillButton {
                visible: googlePage.step === "start"
                theme: googlePage.theme
                primary: true
                enabled: googlePage.google.canSignIn
                text: Lang.i18n("Sign in with Google")
                onClicked: { googlePage.error = ""; googlePage.google.startSignIn(); }
            }
            PillButton {
                visible: googlePage.step === "waiting"
                theme: googlePage.theme
                text: Lang.i18n("Cancel")
                onClicked: googlePage.google.cancelSignIn()
            }
            PillButton {
                visible: googlePage.step === "done"
                theme: googlePage.theme
                text: Lang.i18n("Remove account")
                onClicked: googlePage.google.disconnect()
            }
        }
    }
}
