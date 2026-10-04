/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Notes page carrying on where it was left: with a stand-in for the
    notes backend (the page's own logic is what is checked; no notes app is
    touched). The page is made anew for every "the island opens".
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 400
    height: 135

    Theme { id: islandTheme; follow: false }

    // What NotesPage uses of NotesBackend.
    QtObject {
        id: backend
        property bool available: true
        property bool loaded: true
        property bool busy: false
        property bool hasBetterNotes: true
        property bool betterNotesOpens: true
        readonly property var types: ({ joplin: { name: "Joplin", color: "#1071d3", icon: "" }, simplenote: { name: "Simplenote", color: "#3361cc", icon: "" },
                                        memos: { name: "Memos", color: "#10b981", icon: "" }, betternotes: { name: "BetterNotes", color: "#2563eb", icon: "", local: true } })
        readonly property string betterNotesInstall: ""
        property var sources: [{ id: "joplin-1", type: "joplin", name: "Joplin", server: "", user: "" }, { id: "bn-1", type: "betternotes", name: "BetterNotes", server: "", user: "" }]
        readonly property var defaultSource: sources[0]
        property var notes: []
        property var drafts: ({})
        property var errors: ({})
        // what was asked of it
        property var loads: []
        property var saves: []
        property var opened: []
        property string showError: ""
        function refreshIfStale() {}
        function detect(done) {}
        function openBetterNotes() {}
        function setDraft(key, text) { const d = Object.assign({}, drafts); if (text === null || text === undefined) delete d[key]; else d[key] = text; drafts = d; }
        function remember(key, fields) { for (const n of notes) if (n.key === key) Object.assign(n, fields); }
        function loadText(item, done) {
            loads.push(item.id);
            if (item.locked) { done("", "must never be shown"); return; }
            if (showError.length > 0) done(showError, ""); else done("", "the content of " + item.id, false);
        }
        function save(old, text, done) { saves.push([old.key, text]); done({ ok: true, note: Object.assign({}, old, { text: text, updated: 2 }), error: "" }); }
        function create(text, sourceId, done) { const n = note("joplin-1", "joplin", "new-1", text); notes = [n].concat(notes); done({ ok: true, note: n, error: "" }); }
        function openNote(item, done) { opened.push(item.id); done(""); }
        function note(source, type, id, text) { return { key: source + ":" + id, source: source, type: type, id: id, title: text.split("\n")[0], text: text, updated: 1, raw: null }; }
        function reset() {
            const secret = Object.assign(note("bn-1", "betternotes", "7", "Secret title"), { locked: true, readOnly: true, tags: [], priority: "Normal", reminder: 0 });
            const plain = Object.assign(note("bn-1", "betternotes", "3", "Shopping"), { locked: false, readOnly: false, tags: [], priority: "Normal", reminder: 0 });
            notes = [note("joplin-1", "joplin", "a1", "Meeting\nBring the slides"), plain, secret, note("joplin-1", "joplin", "b2", "Ideas\n- one")];
            drafts = ({}); errors = ({}); loads = []; saves = []; opened = []; showError = "";
            available = true; loaded = true;
        }
    }

    // The settings: what is remembered between two pages (and across a restart of the shell).
    property string lastOpen: ""
    property bool resume: true
    Component {
        id: pageComponent
        NotesPage {
            anchors.fill: parent
            theme: islandTheme
            notes: backend
            resume: root.resume
            lastOpen: root.lastOpen
            onLastOpenEdited: json => root.lastOpen = json
        }
    }

    TestCase {
        name: "Notes"
        when: windowShown

        property var page: null
        // The island opens: a new page. It closes: the page goes away.
        function open() {
            page = pageComponent.createObject(root);
            verify(page !== null);
            wait(20);
            return page;
        }
        function close() {
            if (page !== null) { page.destroy(); page = null; wait(20); }
        }
        function find(id) { return backend.notes.find(n => n.id === id); }
        function editorText(p) {
            let text = null;
            const walk = item => { if (item.textFormat !== undefined && item.readOnly !== undefined && item.cursorPosition !== undefined && item.wrapMode === TextEdit.Wrap) text = item.text; for (const c of item.children) walk(c); };
            walk(p);
            return text;
        }
        function init() { backend.reset(); root.lastOpen = ""; root.resume = true; Lang.setting = "en"; }
        function cleanup() { close(); }

        function test_comes_back_to_the_note_that_was_being_edited() {
            let p = open();
            compare(p.view, "list");
            p.open(find("a1"));
            compare([p.view, p.current.key], ["note", "joplin-1:a1"]);
            compare(JSON.parse(root.lastOpen), { source: "joplin-1", id: "a1", editing: true });
            // the island closes, and opens again
            close();
            p = open();
            compare([p.view, p.current.key, p.interacting], ["note", "joplin-1:a1", true], "straight into the editor of that note");
            compare(editorText(p), "Meeting\nBring the slides");
            // the shell restarted: nothing but the setting is left, the notes arrive a moment later
            close();
            backend.loaded = false;
            const saved = backend.notes;
            backend.notes = [];
            p = open();
            compare(p.view, "list");
            backend.notes = saved;
            backend.loaded = true;
            compare([p.view, p.current.key], ["note", "joplin-1:a1"]);
        }

        function test_a_tab_switch_keeps_the_editor() {
            const p = open();
            p.open(find("b2"));
            p.visible = false;                                   // another tab
            wait(20);
            p.visible = true;
            compare([p.view, p.current.key], ["note", "joplin-1:b2"]);
        }

        function test_back_to_the_list_stays_the_list() {
            let p = open();
            p.open(find("a1"));
            p.closeNote();
            compare(p.view, "list");
            compare(JSON.parse(root.lastOpen), { source: "joplin-1", id: "a1", editing: false });
            close();
            p = open();
            compare([p.view, p.current], ["list", null]);
        }

        function test_an_unsaved_draft_comes_back() {
            let p = open();
            p.open(find("a1"));
            backend.setDraft("joplin-1:a1", "Meeting\nBring the slides and the printouts");
            close();
            p = open();
            compare(p.view, "note");
            compare(editorText(p), "Meeting\nBring the slides and the printouts");
            compare(p.saveError, "Not saved yet.");
        }

        function test_a_betternotes_note_is_fetched_again() {
            let p = open();
            p.open(find("3"));
            compare(backend.loads, ["3"]);
            close();
            backend.reset();
            p = open();
            compare([p.view, p.current.key, backend.loads], ["note", "bn-1:3", ["3"]]);
            compare(editorText(p), "the content of 3");
        }

        function test_a_note_that_is_gone_leads_to_the_list_silently() {
            let p = open();
            p.open(find("b2"));
            close();
            backend.notes = backend.notes.filter(n => n.id !== "b2");       // deleted in its app meanwhile
            p = open();
            compare([p.view, p.current, p.status, p.saveError], ["list", null, "", ""]);
            compare(JSON.parse(root.lastOpen).editing, false, "and it is not tried again");
        }

        function test_an_app_that_cannot_be_reached_leads_to_the_list_silently() {
            let p = open();
            p.open(find("3"));
            close();
            // BetterNotes is not there to answer
            backend.reset();
            backend.showError = "BetterNotes did not answer.";
            p = open();
            compare([p.view, p.current, p.saveError, p.status], ["list", null, "", ""]);
            close();
            // its list could not be fetched at all
            backend.reset();
            root.lastOpen = JSON.stringify({ source: "joplin-1", id: "a1", editing: true });
            backend.errors = ({ "joplin-1": "Joplin is not running." });
            p = open();
            compare([p.view, p.current, p.saveError, p.status], ["list", null, "", ""]);
            close();
            // the app was disconnected
            backend.reset();
            backend.available = false;
            p = open();
            compare([p.view, p.current], ["list", null]);
        }

        function test_a_locked_note_is_never_shown() {
            let p = open();
            p.open(find("7"));
            compare([p.view, p.current, backend.loads], ["locked", null, []], "from the list: no editor, nothing fetched");
            compare(JSON.parse(root.lastOpen), { source: "bn-1", id: "7", editing: true });
            close();
            // carrying on: the same screen instead of the editor
            p = open();
            compare([p.view, p.current, p.lockedNote.id, backend.loads], ["locked", null, "7", []]);
            compare(editorText(p), "");
            compare(p.interacting, false, "no field asks for a password here");
            // "Open in BetterNotes": it asks for the password itself
            p.openLocked();
            compare([backend.opened, p.view], [["7"], "list"]);
            compare(JSON.parse(root.lastOpen).editing, false);
            // "Cancel": the list
            p.open(find("7"));
            compare(p.view, "locked");
            p.leaveLocked();
            compare([p.view, p.lockedNote, backend.loads, backend.opened], ["list", null, [], ["7"]]);
            // nothing of it is ever kept
            verify(root.lastOpen.indexOf("Secret") < 0 && root.lastOpen.indexOf("password") < 0);
            compare(Object.keys(JSON.parse(root.lastOpen)).sort(), ["editing", "id", "source"]);
        }

        function test_switched_off_in_the_settings() {
            let p = open();
            p.open(find("a1"));
            close();
            root.resume = false;
            p = open();
            compare([p.view, p.current], ["list", null]);
        }

        function test_a_new_note_is_remembered_once_it_exists() {
            let p = open();
            p.open(null);
            compare(p.view, "note");
            verify(root.lastOpen === "" || JSON.parse(root.lastOpen).editing === false, "a note without an id cannot be come back to");
            let field = null;
            const walk = item => { if (item.textFormat !== undefined && item.cursorPosition !== undefined && item.wrapMode === TextEdit.Wrap) field = item; for (const c of item.children) walk(c); };
            walk(p);
            field.text = "A brand new note";
            p.saveNote(null);
            compare(JSON.parse(root.lastOpen), { source: "joplin-1", id: "new-1", editing: true });
            close();
            p = open();
            compare([p.view, p.current.id], ["note", "new-1"]);
        }
    }
}
