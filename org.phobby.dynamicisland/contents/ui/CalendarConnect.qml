/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Connect a calendar without leaving the island: pick Google Calendar or
    Apple iCloud, then how: the whole account (every calendar, events can be
    added; `accountRequested(type)` hands over to CalendarAccount or
    CalendarGoogle) or, for those who only want to look, the link of one
    shared calendar.
    For a link: follow the short instructions and paste it. The link is
    downloaded once to make sure it really is a calendar, then `added(source)`
    is emitted. `interacting` asks the island for keyboard focus while a text
    field is shown.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: connect

    required property Theme theme
    property var sources: []
    signal added(var source)
    signal cancelled()
    signal accountRequested(string type)
    // Whether an account can be connected here, and who is signed in ("" = nobody).
    property bool accountAvailable: false           // Apple iCloud
    property string accountUser: ""
    property bool googleAvailable: false
    property string googleUser: ""
    readonly property string modeUser: type === "google" ? googleUser : accountUser

    // "pick" → "mode" (Apple: account or link) → "link" → "name"
    property string step: "pick"
    property string type: "google"
    property string device: "iphone"          // which Apple instructions are shown
    property string error: ""
    property bool busy: false
    property string url: ""
    property int count: 0
    property string color: links.palette[0]
    readonly property bool interacting: step === "link" || step === "name"
    readonly property bool hasModes: type === "apple" ? accountAvailable : googleAvailable

    CalendarLinks { id: links; sources: connect.sources }

    function reset(): void {
        step = "pick"; error = ""; busy = false; url = ""; count = 0;
        linkInput.text = ""; nameInput.text = "";
        color = links.freeColor();
    }
    function tryConnect(): void {
        error = links.formatProblem(linkInput.text);
        if (error !== "" || busy) return;
        busy = true;
        const candidate = linkInput.text;
        links.check(candidate, result => {
            busy = false;
            if (!result.ok) { error = result.error; return; }
            url = links.normalize(candidate);
            count = result.count;
            nameInput.text = result.name;       // only a suggestion
            step = "name";
        });
    }
    function finish(): void {
        if (nameInput.text.trim().length === 0) { error = Lang.i18n("Give the calendar a short name (e.g. Work, Personal)."); return; }
        if (links.isConnected(url)) { error = Lang.i18n("This calendar is already connected."); return; }
        added(links.makeSource(type, url, nameInput.text, color));
        reset();
    }
    onStepChanged: Qt.callLater(() => { if (step === "link") linkInput.forceActiveFocus(); else if (step === "name") nameInput.forceActiveFocus(); })

    component PillButton: Rectangle {
        property string text
        property bool primary: false
        signal clicked()
        implicitWidth: pillLabel.implicitWidth + 22
        implicitHeight: 26
        radius: 13
        readonly property color fill: primary ? connect.theme.blue : connect.theme.faint
        color: pillMouse.pressed ? Qt.darker(fill, 1.2) : pillMouse.containsMouse && !primary ? connect.theme.over(connect.theme.hoverFill, connect.theme.over(fill, connect.theme.surface)) : fill
        opacity: enabled ? 1 : 0.4
        scale: pillMouse.pressed ? 0.95 : pillMouse.containsMouse ? 1.05 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: parent.text
            color: parent.primary ? connect.theme.onColor(connect.theme.blue) : connect.theme.text
            font.pointSize: connect.theme.fontSmall
            font.weight: Font.DemiBold
        }
        MouseArea { id: pillMouse; anchors.fill: parent; enabled: parent.enabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    component Field: Rectangle {
        property alias input: fieldInput
        property string placeholder
        signal accepted()
        implicitHeight: 28
        radius: 14
        color: connect.theme.faint
        border.width: 1
        border.color: fieldInput.activeFocus ? connect.theme.blue : "transparent"
        TextInput {
            id: fieldInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: connect.theme.text
            selectionColor: connect.theme.blue
            font.pointSize: connect.theme.fontSmall
            clip: true
            selectByMouse: true
            onAccepted: parent.accepted()
            onTextEdited: connect.error = ""
            Keys.onEscapePressed: connect.cancelled()
        }
        Text {
            anchors.fill: fieldInput
            verticalAlignment: Text.AlignVCenter
            visible: fieldInput.text.length === 0
            text: parent.placeholder
            color: connect.theme.subText
            font.pointSize: connect.theme.fontSmall
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconButton {
                visible: connect.step !== "pick"
                iconName: "go-previous-symbolic"
                color: connect.theme.text
                hoverColor: connect.theme.faint
                enabled: !connect.busy
                onClicked: { connect.error = ""; connect.step = connect.step === "name" ? "link" : connect.step === "link" && connect.hasModes ? "mode" : "pick"; }
            }
            Kirigami.Icon {
                visible: connect.step !== "pick"
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                source: links.typeIcons[connect.type]
                color: connect.theme.text
                isMask: true
            }
            Text {
                Layout.fillWidth: true
                text: connect.step === "pick" ? Lang.i18n("Connect a Calendar") : links.typeNames[connect.type]
                color: connect.theme.text
                font.pointSize: connect.theme.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            // Apple: which device the instructions are for
            Repeater {
                model: connect.step === "link" && connect.type === "apple" ? [{ key: "iphone", text: "iPhone / iPad" }, { key: "mac", text: "Mac" }] : []
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: deviceLabel.implicitWidth + 16
                    implicitHeight: 20
                    radius: 10
                    color: connect.device === modelData.key ? connect.theme.faint : "transparent"
                    Text {
                        id: deviceLabel
                        anchors.centerIn: parent
                        text: parent.modelData.text
                        color: connect.device === parent.modelData.key ? connect.theme.text : connect.theme.subText
                        font.pointSize: connect.theme.fontSmall * 0.9
                        font.weight: Font.DemiBold
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connect.device = parent.modelData.key }
                }
            }
            IconButton {
                iconName: "window-close-symbolic"
                color: connect.theme.subText
                hoverColor: connect.theme.faint
                onClicked: connect.cancelled()
            }
        }

        // ---- step 1: which calendar ----
        RowLayout {
            visible: connect.step === "pick"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Repeater {
                model: ["google", "apple"]
                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: 14
                    color: tileMouse.pressed ? connect.theme.pressedFill
                         : tileMouse.containsMouse ? connect.theme.over(connect.theme.hoverFill, connect.theme.over(connect.theme.faint, connect.theme.surface))
                         : connect.theme.faint
                    scale: tileMouse.pressed ? 0.97 : tileMouse.containsMouse ? 1.03 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            source: links.typeIcons[tile.modelData]
                            color: connect.theme.text
                            isMask: true
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: links.typeNames[tile.modelData]
                            color: connect.theme.text
                            font.pointSize: connect.theme.fontSmall
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { connect.type = tile.modelData; connect.error = ""; connect.step = connect.hasModes ? "mode" : "link"; }
                    }
                }
            }
        }

        // ---- step 2: the whole account, or one shared calendar ----
        RowLayout {
            visible: connect.step === "mode"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Repeater {
                model: [
                    { key: "account", icon: "user-identity-symbolic", title: connect.modeUser.length > 0 ? Lang.i18n("Account connected") : Lang.i18n("Connect the account"),
                      text: connect.modeUser.length > 0 ? connect.modeUser
                          : connect.type === "google" ? Lang.i18n("Every calendar is shown and events can be added here. You sign in with Google in the browser; your password never reaches the island.")
                          : Lang.i18n("Every calendar is shown and events can be added here. Uses a revocable app-specific password, not your real one.") },
                    { key: "link", icon: "insert-link-symbolic", title: Lang.i18n("View only"),
                      text: connect.type === "google" ? Lang.i18n("No account is connected. You paste the secret link of the one calendar you choose.")
                                                      : Lang.i18n("No account details are entered. You share the one calendar you choose on your phone as a link.") }
                ]
                delegate: Rectangle {
                    id: modeTile
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: 14
                    color: modeMouse.pressed ? connect.theme.pressedFill
                         : modeMouse.containsMouse ? connect.theme.over(connect.theme.hoverFill, connect.theme.over(connect.theme.faint, connect.theme.surface))
                         : connect.theme.faint
                    Behavior on color { ColorAnimation { duration: 120 } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 2
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 5
                            Kirigami.Icon {
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                source: modeTile.modelData.icon
                                color: connect.theme.text
                                isMask: true
                            }
                            Text {
                                text: modeTile.modelData.title
                                color: connect.theme.text
                                font.pointSize: connect.theme.fontSmall
                                font.weight: Font.DemiBold
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modeTile.modelData.text
                            color: connect.theme.subText
                            font.pointSize: connect.theme.fontSmall * 0.8
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (modeTile.modelData.key === "account") connect.accountRequested(connect.type); else { connect.error = ""; connect.step = "link"; } }
                    }
                }
            }
        }

        // ---- step 2: instructions + link ----
        Flickable {
            visible: connect.step === "link"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: steps.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: steps
                width: parent.width
                spacing: 3
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: connect.type === "google" ? links.instructions.google : links.instructions[connect.device]
                    color: connect.theme.text
                    font.pointSize: connect.theme.fontSmall * 0.9
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: links.secretWarning
                    color: connect.theme.subText
                    font.pointSize: connect.theme.fontSmall * 0.85
                }
            }
        }

        // ---- step 3: name + colour ----
        ColumnLayout {
            visible: connect.step === "name"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: Lang.i18np("Calendar found: it has %1 event.", "Calendar found: it has %1 events.", connect.count)
                color: connect.theme.subText
                font.pointSize: connect.theme.fontSmall
            }
            Row {
                spacing: 8
                Repeater {
                    model: links.palette
                    delegate: Rectangle {
                        required property string modelData
                        width: 20; height: 20; radius: 10
                        color: modelData
                        border.width: connect.color === modelData ? 2.5 : 0
                        border.color: connect.theme.text
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connect.color = parent.modelData }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        Text {
            Layout.fillWidth: true
            visible: connect.error.length > 0
            text: connect.error
            color: connect.theme.readable(connect.theme.danger, connect.theme.surface)
            font.pointSize: connect.theme.fontSmall * 0.9
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // ---- input row ----
        RowLayout {
            visible: connect.step === "link" || connect.step === "name"
            Layout.fillWidth: true
            spacing: 6
            Field {
                id: linkField
                visible: connect.step === "link"
                Layout.fillWidth: true
                placeholder: Lang.i18n("Paste your calendar link here")
                enabled: !connect.busy
                onAccepted: connect.tryConnect()
            }
            IconButton {
                visible: connect.step === "link"
                iconName: "edit-paste-symbolic"
                color: connect.theme.text
                hoverColor: connect.theme.faint
                enabled: !connect.busy
                onClicked: { linkInput.forceActiveFocus(); linkInput.selectAll(); linkInput.paste(); connect.error = ""; }
            }
            Field {
                id: nameField
                visible: connect.step === "name"
                Layout.fillWidth: true
                placeholder: Lang.i18n("Name of the calendar (e.g. Work, Personal)")
                onAccepted: connect.finish()
            }
            PillButton {
                visible: connect.step === "link"
                primary: true
                text: connect.busy ? Lang.i18n("Checking…") : Lang.i18n("Connect")
                enabled: !connect.busy
                onClicked: connect.tryConnect()
            }
            PillButton {
                visible: connect.step === "name"
                primary: true
                text: Lang.i18n("Add")
                onClicked: connect.finish()
            }
        }
    }

    readonly property TextInput linkInput: linkField.input
    readonly property TextInput nameInput: nameField.input
}
