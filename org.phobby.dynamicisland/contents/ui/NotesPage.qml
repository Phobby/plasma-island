/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Notes": jot something down quickly, or look up what was noted. One list
    of every connected notes app (NotesBackend), newest first, with a field on
    top that adds a quick note to the default source or searches the notes.
    Clicking a note opens it for editing; changes are written back to its app
    1.5 s after typing stops, when the field loses focus, or with Ctrl+S.
    A quick note to BetterNotes is its title alone, filled in later; the
    title can be changed in the editor too. Text that could not be saved
    stays (NotesBackend.drafts) and can be saved again.
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

    // "list" | "note" (editor)
    // | "sources" (connected apps, add one) | "form" (connect `formType`) | "install" (how to get BetterNotes)
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
        if (d.toDateString() === now.toDateString()) return Qt.formatTime(d, Lang.locale.timeFormat(Locale.ShortFormat));
        return d.toLocaleDateString(Lang.locale, d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy");
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
            say(Lang.i18n("Saved to %1", notes.types[result.note.type].name), false);
        });
    }
    property bool adding: false

    // ---- editor ------------------------------------------------------------------
    property var current: null              // the note being edited; null = a new one
    property string savedText: ""
    property bool saving: false
    property string saveError: ""
    property bool loading: false
    // Locked notes and BetterNotes notes with rich text are only shown here.
    readonly property bool readOnly: current !== null && current.readOnly === true
    // BetterNotes notes have a title of their own: edited in a field above the text.
    readonly property bool titled: current !== null && current.type === "betternotes"
    // BetterNotes shows a note as a sticky window on the desktop (0.1.14+). What was
    // typed here is saved first, so the window shows it. An older BetterNotes can
    // only be started.
    property bool opening: false
    function showInWindow(): void {
        if (!current || opening) return;
        if (!notes.betterNotesOpens) { notes.openBetterNotes(); return; }
        saveNote(() => {
            opening = true;
            notes.openNote(page.current, error => { opening = false; if (error.length > 0) page.saveError = error; });
        });
    }
    readonly property string draftKey: current ? current.key : "new:" + (notes.defaultSource ? notes.defaultSource.id : "")
    // What would be saved: "title\ncontent" for a titled note, the text otherwise.
    function composed(): string { return titled ? titleField.text.trim() + "\n" + editor.text : editor.text; }
    readonly property bool dirty: view === "note" && !readOnly && !loading && (titled ? titleField.text.trim() + "\n" + editor.text : editor.text) !== savedText
    function show(text: string): void {
        if (titled) {
            const i = text.indexOf("\n");
            titleField.text = i < 0 ? text : text.slice(0, i);
            editor.text = i < 0 ? "" : text.slice(i + 1);
        } else editor.text = text;
    }
    function open(n: var): void {
        autoSave.stop();
        current = n; saveError = ""; loading = false;
        view = "note";
        const draft = page.notes.drafts[draftKey];
        const resume = () => {
            if (draft !== undefined && !readOnly) {
                show(draft);
                saveError = Lang.i18n("Not saved yet.");
            }
            if (!readOnly) Qt.callLater(() => { editor.forceActiveFocus(); editor.cursorPosition = editor.length; });
        };
        if (n && n.type === "betternotes" && !n.loaded) {
            loading = true;
            titleField.text = n.title; editor.text = Lang.i18n("Loading…"); savedText = "";
            notes.loadText(n, (error, text, rich) => {
                // The list may have been refreshed meanwhile: the same note is another object then.
                if (!page.current || page.current.key !== n.key) return;
                loading = false;
                if (error) { page.saveError = error; editor.text = ""; savedText = page.composed(); return; }
                // Also found by the search from now on. Plain text would lose rich formatting: only shown.
                const fields = { text: page.current.title + "\n" + text, loaded: true };
                if (rich) { fields.rich = true; fields.readOnly = true; }
                page.notes.remember(n.key, fields);
                page.current = Object.assign({}, page.current, fields);
                savedText = page.current.text; show(savedText);
                resume();
            });
            return;
        }
        // A titled note is always "title\ncontent", also when it has no content yet.
        savedText = !n ? "" : !titled ? n.text : n.title + "\n" + (n.text.indexOf(n.title + "\n") === 0 ? n.text.slice(n.title.length + 1) : "");
        show(savedText);
        resume();
    }
    function saveNote(then: var): void {
        if (saving || loading) return;
        const text = composed();
        if (readOnly) { if (then) then(); return; }
        if (text === savedText || (current === null && text.trim().length === 0)) { if (then) then(); return; }
        if (titled && titleField.text.trim().length === 0) { saveError = Lang.i18n("Give the note a title."); return; }
        autoSave.stop();
        saving = true; saveError = "";
        const finished = result => {
            saving = false;
            // The text stays in the editor (and in the backend's drafts): nothing is lost.
            if (!result.ok) { saveError = result.error; return; }
            current = result.note; savedText = text;
            // Typed on while it was being saved: save again.
            if (composed() !== text) autoSave.restart(); else if (then) then();
        };
        if (current) notes.save(current, text, finished); else notes.create(text, "", finished);
    }
    function closeNote(): void {
        saveNote(() => { view = "list"; typing = false; });
    }
    // Back to the list without saving: the text stays as a draft of this note.
    function leaveNote(): void {
        if (dirty) notes.setDraft(draftKey, composed());
        autoSave.stop(); saveError = ""; view = "list"; typing = false;
    }
    Timer { id: autoSave; interval: 1500; onTriggered: page.saveNote(null) }
    // The island closes (the page goes away): what was typed is saved, or kept as a draft.
    Component.onDestruction: {
        if (!dirty) return;
        const text = composed();
        if (current) notes.save(current, text, () => {});
        else if (text.trim().length > 0) notes.create(text, "", () => {});
    }

    // ---- connecting ----------------------------------------------------------------
    property var found: ({ joplin: false, joplinRunning: false, simplenote: false, betternotes: false })
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
    readonly property string localOnly: Lang.i18n("BetterNotes keeps your notes on this computer; they do not appear on other devices.")
    function showForm(type: string): void {
        // BetterNotes: no account, so no form. Installed → its notes; otherwise how to install it.
        if (type === "betternotes") {
            if (!found.betternotes) { view = "install"; return; }
            notes.connect("betternotes", {}, result => {
                if (!result.ok) { view = "install"; return; }
                view = "list";
                say(localOnly, false);
            });
            return;
        }
        formType = type; formError = ""; formBusy = false;
        firstField.text = type === "memos" ? "" : ""; secondField.text = "";
        view = "form";
        Qt.callLater(() => firstField.input.forceActiveFocus());
    }
    function submitForm(): void {
        if (formBusy) return;
        const a = firstField.text.trim(), b = secondField.text.trim();
        const fields = formType === "joplin" ? { token: a } : formType === "simplenote" ? { user: a, password: secondField.text } : { server: a, token: b };
        if (a.length === 0 || (formType !== "joplin" && b.length === 0)) { formError = Lang.i18n("Fill in the fields first."); return; }
        formBusy = true; formError = "";
        notes.connect(formType, fields, result => {
            formBusy = false;
            if (!result.ok) { formError = result.error; return; }
            secondField.text = "";
            view = "list";
        });
    }
    readonly property var guidance: ({
        joplin: Lang.i18n("1. Open Joplin on this computer.<br>2. Tools → Options → Web Clipper.<br>3. Press \"Enable Web Clipper Service\".<br>4. Copy the token under \"Advanced options\" and paste it below."),
        simplenote: Lang.i18n("Sign in with the email and password of your Simplenote account. The password is only used to sign in; the island keeps the access token it gets back, in KDE Wallet."),
        memos: Lang.i18n("1. Open your Memos server in a browser.<br>2. Settings → My Account → Access Tokens → Create.<br>3. Paste the server address and the token below.")
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
                placeholder: page.searching ? Lang.i18n("Search notes…") : Lang.i18n("Quick note…")
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
                : failed.length > 0 ? Lang.i18n("%1: %2", failed[0].name, page.notes.errors[failed[0].id]) : ""
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
                            text: row.modelData.title || Lang.i18n("Untitled note")
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            // BetterNotes: tags and priority; others: the text after the title.
                            readonly property string rest: row.modelData.type === "betternotes"
                                ? (row.modelData.tags || []).map(t => "#" + t).concat(row.modelData.priority && row.modelData.priority !== "Normal" ? [row.modelData.priority] : [])
                                                              .concat(row.modelData.locked ? [Lang.i18n("Locked")] : [])
                                                              .concat(page.notes.drafts[row.modelData.key] !== undefined ? [Lang.i18n("Not saved")] : []).join(" · ")
                                : row.modelData.text.replace(/^\s*\S[^\n]*\n?/, "").replace(/\s+/g, " ").trim()
                            visible: rest.length > 0
                            text: rest.slice(0, 120)
                            color: page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.85
                            elide: Text.ElideRight
                        }
                    }
                    // A reminder set in BetterNotes (only a badge; the app itself notifies)
                    Kirigami.Icon {
                        visible: (row.modelData.reminder || 0) > 0
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        source: "alarm-symbolic"
                        color: page.theme.readable(page.theme.orange, page.theme.surface)
                        isMask: true
                    }
                    Text {
                        text: (row.modelData.reminder || 0) > 0 ? page.when(row.modelData.reminder) : page.when(row.modelData.updated)
                        color: (row.modelData.reminder || 0) > 0 ? page.theme.readable(page.theme.orange, page.theme.surface) : page.theme.subText
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
                text: !page.notes.loaded ? Lang.i18n("Loading notes…") : page.searching && page.query.trim().length > 0 ? Lang.i18n("No note matches") : Lang.i18n("No notes yet")
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
            text: !page.detected ? Lang.i18n("Looking for notes apps…")
                : page.found.joplin || page.found.simplenote || page.found.betternotes ? Lang.i18n("Notes apps found on this computer:")
                : Lang.i18n("No notes app was found. Connect one:")
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
                readonly property var order: ["joplin", "simplenote", "memos", "betternotes"]
                model: order.filter(t => t !== "betternotes" || !page.notes.hasBetterNotes)
                            .sort((a, b) => (page.found[b] ? 1 : 0) - (page.found[a] ? 1 : 0) || order.indexOf(a) - order.indexOf(b))
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
                            text: card.modelData === "joplin" ? (page.found.joplinRunning ? Lang.i18n("Found, running · Connect") : card.here ? Lang.i18n("Found · Connect") : Lang.i18n("Desktop app"))
                                : card.modelData === "simplenote" ? (card.here ? Lang.i18n("Found · Sign in") : Lang.i18n("Account"))
                                : card.modelData === "betternotes" ? (card.here ? Lang.i18n("On this device, no account") : page.detected ? Lang.i18n("Not found · Install") : Lang.i18n("On this device"))
                                : Lang.i18n("Your own server")
                            color: card.here ? page.theme.readable(page.theme.live, page.theme.surface) : page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.85
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
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
                text: Lang.i18n("Notes apps")
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
                            text: sourceRow.modelData.name + (sourceRow.modelData.user ? " · " + sourceRow.modelData.user : sourceRow.modelData.server ? " · " + sourceRow.modelData.server
                                                               : sourceRow.modelData.type === "betternotes" ? " · " + Lang.i18n("this computer only") : "")
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            elide: Text.ElideMiddle
                        }
                        // Where quick notes go
                        PillButton {
                            theme: page.theme
                            implicitHeight: 20
                            primary: sourceRow.isDefault
                            text: sourceRow.isDefault ? Lang.i18n("Default") : Lang.i18n("Make default")
                            onClicked: page.defaultPicked(sourceRow.modelData.id)
                        }
                        PillButton {
                            theme: page.theme
                            implicitHeight: 20
                            text: sourceRow.modelData.type === "betternotes" ? Lang.i18n("Hide") : Lang.i18n("Disconnect")
                            onClicked: page.notes.disconnect(sourceRow.modelData.id)
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    text: Lang.i18n("Connect another:")
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
                placeholder: page.formType === "joplin" ? Lang.i18n("API token") : page.formType === "simplenote" ? Lang.i18n("Email") : Lang.i18n("Server address (https://…)")
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
                placeholder: page.formType === "simplenote" ? Lang.i18n("Password") : Lang.i18n("Access token")
                enabled: !page.formBusy
                onEdited: page.formError = ""
                onAccepted: page.submitForm()
                onEscaped: page.view = "list"
            }
            PillButton {
                theme: page.theme
                primary: true
                enabled: !page.formBusy
                text: page.formBusy ? Lang.i18n("Connecting…") : Lang.i18n("Connect")
                onClicked: page.submitForm()
            }
        }
    }

    // ---- BetterNotes is not installed: how to get it (never run from here) ----------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "install"
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
                onClicked: { if (page.notes.available) page.showSources(); else page.view = "list"; }
            }
            SourceBadge { type: "betternotes" }
            Text {
                Layout.fillWidth: true
                text: Lang.i18n("BetterNotes was not found")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            wrapMode: Text.Wrap
            text: Lang.i18n("A notes app without an account. To install it, run this command in your own terminal, then come back and choose BetterNotes again.") + " " + page.localOnly
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.9
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 14
                color: page.theme.faint
                clip: true
                TextEdit {
                    id: installCommand
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextEdit.AlignVCenter
                    readOnly: true
                    selectByMouse: true
                    text: page.notes.betterNotesInstall
                    color: page.theme.text
                    selectionColor: page.theme.control
                    font.family: "monospace"
                    font.pointSize: page.theme.fontSmall * 0.85
                }
            }
            PillButton {
                theme: page.theme
                primary: true
                text: copied.running ? Lang.i18n("Copied") : Lang.i18n("Copy")
                onClicked: { installCommand.selectAll(); installCommand.copy(); installCommand.deselect(); copied.restart(); }
                Timer { id: copied; interval: 2000 }
            }
            PillButton {
                theme: page.theme
                text: Lang.i18n("Check again")
                onClicked: page.notes.detect(result => { page.found = result; page.detected = true; if (result.betternotes) page.showForm("betternotes"); })
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
                // Saving failed: leave anyway, the text is kept as a draft.
                onClicked: if (page.saveError.length > 0) page.leaveNote(); else page.closeNote()
            }
            SourceBadge {
                visible: type.length > 0
                type: page.current ? page.current.type : page.notes.defaultSource ? page.notes.defaultSource.type : ""
            }
            PillField {
                id: titleField
                visible: page.titled && !page.readOnly
                theme: page.theme
                Layout.fillWidth: true
                implicitHeight: 22
                placeholder: Lang.i18n("Title")
                onEdited: { if (!page.loading) autoSave.restart(); }
                onAccepted: { editor.forceActiveFocus(); editor.cursorPosition = editor.length; }
                onEscaped: page.closeNote()
                Connections {
                    target: titleField.input
                    function onActiveFocusChanged() { if (!titleField.input.activeFocus && page.view === "note") page.saveNote(null); }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: !titleField.visible
                text: page.saveError.length > 0 && !page.titled ? page.saveError
                    : page.readOnly ? page.current.title
                    : page.current ? page.notes.types[page.current.type].name
                    : page.notes.defaultSource ? Lang.i18n("New note in %1", page.notes.defaultSource.name) : ""
                color: page.saveError.length > 0 ? page.theme.readable(page.theme.danger, page.theme.surface) : page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
                elide: Text.ElideRight
            }
            Text {
                visible: !page.readOnly
                text: page.loading ? "" : page.saving ? Lang.i18n("Saving…") : page.dirty ? Lang.i18n("Edited") : page.current ? Lang.i18n("Saved") : ""
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
            }
            // The note as its sticky window on the desktop.
            IconButton {
                visible: page.titled && !page.readOnly && page.notes.betterNotesOpens
                enabled: !page.loading && !page.saving && !page.opening
                iconName: "window-new-symbolic"
                iconSize: 12
                implicitWidth: 20; implicitHeight: 20
                color: page.theme.text
                hoverColor: page.theme.faint
                toolTip: Lang.i18n("Open in a window")
                onClicked: page.showInWindow()
            }
            // BetterNotes has its own editor (rich text, images, checklists): edit there.
            PillButton {
                visible: page.readOnly
                enabled: !page.loading && !page.opening
                theme: page.theme
                implicitHeight: 20
                text: Lang.i18n("Edit in BetterNotes")
                onClicked: page.showInWindow()
            }
        }
        // Saving failed: say why, keep the text, offer to try again.
        Rectangle {
            Layout.fillWidth: true
            visible: page.titled && page.saveError.length > 0
            implicitHeight: errorRow.implicitHeight + 8
            radius: 8
            color: Qt.rgba(page.theme.danger.r, page.theme.danger.g, page.theme.danger.b, 0.16)
            RowLayout {
                id: errorRow
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 4
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: page.saveError
                    color: page.theme.readable(page.theme.danger, page.theme.surface)
                    font.pointSize: page.theme.fontSmall * 0.9
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                PillButton {
                    visible: !page.readOnly && page.dirty
                    theme: page.theme
                    implicitHeight: 20
                    primary: true
                    text: page.saving ? Lang.i18n("Saving…") : Lang.i18n("Try again")
                    onClicked: page.saveNote(null)
                }
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
                selectionColor: page.theme.control
                font.pointSize: page.theme.fontSmall
                selectByMouse: true
                readOnly: page.readOnly || page.loading
                onCursorRectangleChanged: editorView.follow(cursorRectangle)
                onTextChanged: if (page.dirty) autoSave.restart()
                // Clicking elsewhere saves at once.
                onActiveFocusChanged: if (!activeFocus && page.view === "note") page.saveNote(null)
                Keys.onEscapePressed: page.closeNote()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) { page.saveNote(null); event.accepted = true; }
                }
            }
        }
    }
}
