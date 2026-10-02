/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Notes": jot something down quickly, or look up what was noted. One list
    of every connected notes app (NotesBackend), newest first, with a field on
    top that adds a quick note to the default source or searches the notes.
    Clicking a note opens it for editing; changes are written back to its app.
    Notes apps are connected right here: the ones found on this computer are
    offered first.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    required property var notes             // NotesBackend
    signal defaultPicked(string id)

    // "list" | "note" (editor) | "sources" (connected apps, add one) | "form" (connect `formType`)
    property string view: "list"
    property bool searching: false
    // The top field has keyboard focus (the island only takes the keyboard on request).
    property bool typing: false
    property string query: ""
    property string status: ""              // short feedback under the field
    property bool statusIsError: false
    readonly property bool interacting: visible && (view === "note" || view === "form" || typing)
    onVisibleChanged: if (!visible) typing = false; else arrive()
    Component.onCompleted: arrive()
    // Opening the page: fetch the notes, or look for notes apps when none is connected.
    function arrive(): void {
        if (!visible) return;
        if (notes.available) notes.refreshIfStale(); else if (!detected) detect();
    }

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        if (!searching || q.length === 0) return notes.notes;
        return notes.notes.filter(n => n.text.toLowerCase().indexOf(q) >= 0);
    }
    function when(t: real): string {
        if (t <= 0) return "";
        const d = new Date(t), now = new Date();
        if (d.toDateString() === now.toDateString()) return Qt.formatTime(d, Qt.locale().timeFormat(Locale.ShortFormat));
        return d.toLocaleDateString(Qt.locale(), d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy");
    }
    function say(text: string, error: bool): void {
        status = text; statusIsError = error;
        statusTimer.restart();
    }
    Timer { id: statusTimer; interval: 4000; onTriggered: page.status = "" }

    function focusField(): void {
        typing = true;
        Qt.callLater(() => topField.input.forceActiveFocus());
    }
    function addQuick(): void {
        const text = topField.text.trim();
        if (text.length === 0 || adding) return;
        adding = true;
        notes.create(text, "", result => {
            adding = false;
            if (!result.ok) { say(result.error, true); return; }
            topField.text = "";
            say(i18n("Saved to %1", notes.types[result.note.type].name), false);
        });
    }
    property bool adding: false

    // ---- editor ------------------------------------------------------------------
    property var current: null              // the note being edited; null = a new one
    property string savedText: ""
    property bool saving: false
    property string saveError: ""
    function open(n: var): void {
        current = n; savedText = n ? n.text : ""; saveError = "";
        editor.text = savedText;
        view = "note";
        Qt.callLater(() => { editor.forceActiveFocus(); editor.cursorPosition = editor.length; });
    }
    function saveNote(then: var): void {
        const text = editor.text;
        if (saving) return;
        if (text === savedText || (current === null && text.trim().length === 0)) { if (then) then(); return; }
        saving = true; saveError = "";
        const finished = result => {
            saving = false;
            if (!result.ok) { saveError = result.error; return; }
            current = result.note; savedText = text;
            // Typed on while it was being saved: save again.
            if (editor.text !== text) autoSave.restart(); else if (then) then();
        };
        if (current) notes.save(current, text, finished); else notes.create(text, "", finished);
    }
    function closeNote(): void {
        saveNote(() => { view = "list"; typing = false; });
    }
    Timer { id: autoSave; interval: 1500; onTriggered: page.saveNote(null) }

    // ---- connecting ----------------------------------------------------------------
    property var found: ({ joplin: false, joplinRunning: false, simplenote: false })
    property bool detected: false
    property string formType: "joplin"
    property string formError: ""
    property bool formBusy: false
    function detect(): void {
        notes.detect(result => { found = result; detected = true; });
    }
    function showSources(): void {
        view = "sources"; typing = false;
        detect();
    }
    function showForm(type: string): void {
        formType = type; formError = ""; formBusy = false;
        firstField.text = type === "memos" ? "" : ""; secondField.text = "";
        view = "form";
        Qt.callLater(() => firstField.input.forceActiveFocus());
    }
    function submitForm(): void {
        if (formBusy) return;
        const a = firstField.text.trim(), b = secondField.text.trim();
        const fields = formType === "joplin" ? { token: a } : formType === "simplenote" ? { user: a, password: secondField.text } : { server: a, token: b };
        if (a.length === 0 || (formType !== "joplin" && b.length === 0)) { formError = i18n("Fill in the fields first."); return; }
        formBusy = true; formError = "";
        notes.connect(formType, fields, result => {
            formBusy = false;
            if (!result.ok) { formError = result.error; return; }
            secondField.text = "";
            view = "list";
        });
    }
    readonly property var guidance: ({
        joplin: i18n("1. Open Joplin on this computer.<br>2. Tools → Options → Web Clipper.<br>3. Press \"Enable Web Clipper Service\".<br>4. Copy the token under \"Advanced options\" and paste it below."),
        simplenote: i18n("Sign in with the email and password of your Simplenote account. The password is only used to sign in; the island keeps the access token it gets back, in KDE Wallet."),
        memos: i18n("1. Open your Memos server in a browser.<br>2. Settings → My Account → Access Tokens → Create.<br>3. Paste the server address and the token below.")
    })

    Connections {
        target: page.notes
        function onAvailableChanged() { if (!page.notes.available && page.view === "list") page.detect(); }
    }

    // The app's logo in its own colour on a light tile (readable in both styles).
    component SourceBadge: Rectangle {
        id: badge
        property string type
        readonly property var info: page.notes.types[type] || null
        width: 16; height: 16; radius: width * 0.3
        color: "#f4f5f7"
        Image {
            anchors.centerIn: parent
            width: Math.round(badge.width * 0.68); height: width
            sourceSize: Qt.size(width * 2, height * 2)
            visible: badge.info !== null && badge.info.icon.toString().length > 0
            source: visible ? badge.info.icon : ""
        }
        Text {
            anchors.centerIn: parent
            visible: badge.info !== null && badge.info.icon.toString().length === 0
            text: badge.info ? badge.info.name.charAt(0) : ""
            color: badge.info ? badge.info.color : "black"
            font.pixelSize: Math.round(badge.width * 0.62)
            font.weight: Font.Bold
        }
    }

    // ---- list ----------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "list" && page.notes.available
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            PillField {
                id: topField
                theme: page.theme
                Layout.fillWidth: true
                implicitHeight: 26
                placeholder: page.searching ? i18n("Search notes…") : i18n("Quick note…")
                enabled: !page.adding
                onEdited: { if (page.searching) page.query = text; }
                onAccepted: { if (!page.searching) page.addQuick(); }
                onEscaped: { page.typing = false; if (page.searching) { page.searching = false; text = ""; page.query = ""; } }
                // The first click asks the island for the keyboard.
                MouseArea { anchors.fill: parent; visible: !page.typing; cursorShape: Qt.IBeamCursor; onClicked: page.focusField() }
            }
            IconButton {
                iconName: page.searching ? "window-close-symbolic" : "search-symbolic"
                iconSize: 14
                implicitWidth: 24; implicitHeight: 24
                color: page.theme.text
                hoverColor: page.theme.faint
                onClicked: { page.searching = !page.searching; topField.text = ""; page.query = ""; if (page.searching) page.focusField(); else page.typing = false; }
            }
            IconButton {
                iconName: "document-new-symbolic"
                iconSize: 14
                implicitWidth: 24; implicitHeight: 24
                color: page.theme.text
                hoverColor: page.theme.faint
                onClicked: page.open(null)
            }
            IconButton {
                iconName: "configure-symbolic"
                iconSize: 14
                implicitWidth: 24; implicitHeight: 24
                color: page.theme.subText
                hoverColor: page.theme.faint
                onClicked: page.showSources()
            }
        }
        Text {
            Layout.fillWidth: true
            readonly property var failed: page.notes.sources.filter(s => page.notes.errors[s.id] !== undefined)
            readonly property string message: page.status.length > 0 ? page.status
                : failed.length > 0 ? i18n("%1: %2", failed[0].name, page.notes.errors[failed[0].id]) : ""
            visible: message.length > 0
            text: message
            color: page.status.length > 0 && !page.statusIsError ? page.theme.subText : page.theme.readable(page.theme.warning, page.theme.surface)
            font.pointSize: page.theme.fontSmall * 0.9
            elide: Text.ElideRight
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: page.shown

            delegate: Rectangle {
                id: row
                required property var modelData
                width: list.width
                height: 30
                radius: 10
                color: rowMouse.pressed ? page.theme.pressedFill
                     : rowMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface)) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 8
                    spacing: 8
                    SourceBadge { type: row.modelData.type }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title || i18n("Untitled note")
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            readonly property string rest: row.modelData.text.replace(/^\s*\S[^\n]*\n?/, "").replace(/\s+/g, " ").trim()
                            visible: rest.length > 0
                            text: rest.slice(0, 120)
                            color: page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.85
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        text: page.when(row.modelData.updated)
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.85
                        font.features: { "tnum": 1 }
                    }
                }
                MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.open(row.modelData) }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: !page.notes.loaded ? i18n("Loading notes…") : page.searching && page.query.trim().length > 0 ? i18n("No note matches") : i18n("No notes yet")
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall
            }
        }
    }

    // ---- nothing connected ---------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "list" && !page.notes.available
        spacing: 6
        Text {
            Layout.fillWidth: true
            text: !page.detected ? i18n("Looking for notes apps…")
                : page.found.joplin || page.found.simplenote ? i18n("Notes apps found on this computer:")
                : i18n("No notes app was found. Connect one:")
            color: page.theme.text
            font.pointSize: page.theme.fontSmall
            font.weight: Font.DemiBold
        }
        Loader { Layout.fillWidth: true; Layout.fillHeight: true; active: parent.visible; sourceComponent: appCards }
    }

    // The apps that can be connected; the ones found here come first and say so.
    Component {
        id: appCards
        RowLayout {
            spacing: 6
            Repeater {
                model: ["joplin", "simplenote", "memos"].slice().sort((a, b) => (page.found[b] ? 1 : 0) - (page.found[a] ? 1 : 0))
                delegate: Rectangle {
                    id: card
                    required property string modelData
                    readonly property bool here: page.found[modelData] === true
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: 14
                    color: cardMouse.pressed ? page.theme.pressedFill
                         : cardMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                         : page.theme.faint
                    Behavior on color { ColorAnimation { duration: 120 } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 3
                        SourceBadge { Layout.alignment: Qt.AlignHCenter; type: card.modelData; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: page.notes.types[card.modelData].name
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: card.modelData === "joplin" ? (page.found.joplinRunning ? i18n("Found, running · Connect") : card.here ? i18n("Found · Connect") : i18n("Desktop app"))
                                : card.modelData === "simplenote" ? (card.here ? i18n("Found · Sign in") : i18n("Account"))
                                : i18n("Your own server")
                            color: card.here ? page.theme.readable(page.theme.live, page.theme.surface) : page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.85
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.showForm(card.modelData) }
                }
            }
        }
    }

    // ---- connected apps + add ------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "sources"
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            IconButton {
                iconName: "go-previous-symbolic"
                iconSize: 12
                implicitWidth: 20; implicitHeight: 20
                color: page.theme.text
                hoverColor: page.theme.faint
                onClicked: page.view = "list"
            }
            Text {
                Layout.fillWidth: true
                text: i18n("Notes apps")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
        }
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: sourceColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: sourceColumn
                width: parent.width
                spacing: 3
                Repeater {
                    model: page.notes.sources
                    delegate: RowLayout {
                        id: sourceRow
                        required property var modelData
                        readonly property bool isDefault: page.notes.defaultSource !== null && page.notes.defaultSource.id === modelData.id
                        Layout.fillWidth: true
                        spacing: 6
                        SourceBadge { type: sourceRow.modelData.type }
                        Text {
                            Layout.fillWidth: true
                            text: sourceRow.modelData.name + (sourceRow.modelData.user ? " · " + sourceRow.modelData.user : sourceRow.modelData.server ? " · " + sourceRow.modelData.server : "")
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            elide: Text.ElideMiddle
                        }
                        // Where quick notes go
                        PillButton {
                            theme: page.theme
                            implicitHeight: 20
                            primary: sourceRow.isDefault
                            text: sourceRow.isDefault ? i18n("Default") : i18n("Make default")
                            onClicked: page.defaultPicked(sourceRow.modelData.id)
                        }
                        PillButton {
                            theme: page.theme
                            implicitHeight: 20
                            text: i18n("Disconnect")
                            onClicked: page.notes.disconnect(sourceRow.modelData.id)
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    text: i18n("Connect another:")
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                }
                Loader { Layout.fillWidth: true; Layout.preferredHeight: 62; active: page.view === "sources"; sourceComponent: appCards }
            }
        }
    }

    // ---- connect form ----------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "form"
        spacing: 5
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconButton {
                iconName: "go-previous-symbolic"
                iconSize: 12
                implicitWidth: 20; implicitHeight: 20
                color: page.theme.text
                hoverColor: page.theme.faint
                enabled: !page.formBusy
                onClicked: { if (page.notes.available) page.showSources(); else page.view = "list"; }
            }
            SourceBadge { type: page.formType }
            Text {
                Layout.fillWidth: true
                text: page.notes.types[page.formType].name
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
        }
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: formInfo.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Text {
                id: formInfo
                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                text: page.formError.length > 0 ? page.formError : page.guidance[page.formType]
                color: page.formError.length > 0 ? page.theme.readable(page.theme.danger, page.theme.surface) : page.theme.text
                font.pointSize: page.theme.fontSmall * 0.9
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            PillField {
                id: firstField
                theme: page.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                secret: page.formType === "joplin"
                placeholder: page.formType === "joplin" ? i18n("API token") : page.formType === "simplenote" ? i18n("Email") : i18n("Server address (https://…)")
                enabled: !page.formBusy
                onEdited: page.formError = ""
                onAccepted: { if (page.formType === "joplin") page.submitForm(); else secondField.input.forceActiveFocus(); }
                onEscaped: page.view = "list"
            }
            PillField {
                id: secondField
                visible: page.formType !== "joplin"
                theme: page.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                secret: true
                placeholder: page.formType === "simplenote" ? i18n("Password") : i18n("Access token")
                enabled: !page.formBusy
                onEdited: page.formError = ""
                onAccepted: page.submitForm()
                onEscaped: page.view = "list"
            }
            PillButton {
                theme: page.theme
                primary: true
                enabled: !page.formBusy
                text: page.formBusy ? i18n("Connecting…") : i18n("Connect")
                onClicked: page.submitForm()
            }
        }
    }

    // ---- editor ----------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "note"
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconButton {
                iconName: "go-previous-symbolic"
                iconSize: 12
                implicitWidth: 20; implicitHeight: 20
                color: page.theme.text
                hoverColor: page.theme.faint
                onClicked: page.closeNote()
            }
            SourceBadge {
                visible: type.length > 0
                type: page.current ? page.current.type : page.notes.defaultSource ? page.notes.defaultSource.type : ""
            }
            Text {
                Layout.fillWidth: true
                text: page.saveError.length > 0 ? page.saveError
                    : page.current ? page.notes.types[page.current.type].name
                    : page.notes.defaultSource ? i18n("New note in %1", page.notes.defaultSource.name) : ""
                color: page.saveError.length > 0 ? page.theme.readable(page.theme.danger, page.theme.surface) : page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
                elide: Text.ElideRight
            }
            Text {
                text: page.saving ? i18n("Saving…") : editor.text !== page.savedText ? i18n("Edited") : page.current ? i18n("Saved") : ""
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
            }
        }
        Flickable {
            id: editorView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: editor.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            function follow(r: rect): void {
                if (r.y < contentY) contentY = r.y;
                else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height;
            }
            TextEdit {
                id: editor
                width: editorView.width
                height: Math.max(implicitHeight, editorView.height)
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                color: page.theme.text
                selectionColor: page.theme.blue
                font.pointSize: page.theme.fontSmall
                selectByMouse: true
                onCursorRectangleChanged: editorView.follow(cursorRectangle)
                onTextChanged: if (page.view === "note" && text !== page.savedText) autoSave.restart()
                Keys.onEscapePressed: page.closeNote()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) { page.saveNote(null); event.accepted = true; }
                }
            }
        }
    }
}
