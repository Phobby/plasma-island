/*
    SPDX-License-Identifier: GPL-2.0-or-later

    A locked BetterNotes note opened with its password right on the island:
    the real Notes page and the real notes backend, with tests/fake-betternotes
    standing in for the command (0.1.15: `--password-stdin`). The password
    goes to the command's standard input and nowhere else; a wrong one is
    said; what the note says never enters the list, the search, a draft or
    the settings; leaving the note forgets the password. With an older
    BetterNotes the page only offers to open the note there.
    Needs the native module (skipped when it is not built).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 400
    height: 135

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string record: here + "/.run/fake-betternotes"
    QtObject {
        id: nativeCore
        readonly property var local: root.local
        property bool secretsAvailable: false
        function existingPaths(paths) { return []; }
        function startDetached() { return true; }
    }
    Theme { id: islandTheme; follow: false }
    NotesBackend {
        id: backend
        core: nativeCore
        betterNotesName: root.here + "/fake-betternotes"
        // (its database: only which note is locked is read from it; never the user's own)
        betterNotesData: root.record
        enabled: false
        sourcesJson: JSON.stringify([{ id: "bn-1", type: "betternotes", name: "BetterNotes", server: "", user: "" }])
    }
    property string lastOpen: ""
    Component {
        id: pageComponent
        NotesPage { anchors.fill: parent; theme: islandTheme; notes: backend; lastOpen: root.lastOpen; onLastOpenEdited: json => root.lastOpen = json }
    }

    TestCase {
        name: "NotesLocked"
        when: windowShown

        property var page: null
        function open() { page = pageComponent.createObject(root); wait(30); return page; }
        function close() { page.destroy(); page = null; wait(30); }
        function named(name) { let f = null; (function walk(i) { if (i.objectName === name) f = i; for (const c of i.children) walk(c); })(page); return f; }
        function editor() { let f = null; (function walk(i) { if (f === null && i.wrapMode === TextEdit.Wrap && typeof i.cursorPosition === "number" && typeof i.selectByMouse === "boolean" && i.visible) f = i; for (const c of i.children) walk(c); })(page); return f; }
        function recorded(name) { return root.local.readTextFile(root.record + "/" + name); }
        function locked() { return backend.notes.find(n => n.id === "7"); }

        function initTestCase() {
            if (root.local === null) skip("the native module is not built: ./install.sh");
            Lang.setting = "en";
            root.local.removeFile(root.record + "/secret");
            root.local.removeFile(root.record + "/notes.sqlite3");
            let made = null;
            root.local.run("python3", ["-c", "import sqlite3,sys\nc=sqlite3.connect(sys.argv[1])\nc.execute('create table notes(id integer, updated_at integer, is_locked integer)')\nc.execute('create table reminders(note_id integer, remind_at integer, dismissed integer)')\nc.executemany('insert into notes values(?,?,?)',[(3,100,0),(7,200,1)])\nc.commit()", root.record + "/notes.sqlite3"], (code, out, err) => made = [code, err]);
            tryVerify(() => made !== null, 10000);
            compare(made[0], 0, made[1]);
            backend.enabled = true;
            backend.checkBetterNotes();
            tryCompare(backend, "betterNotesVersion", "BetterNotes 0.1.15");
            backend.refresh();
            tryVerify(() => backend.loaded && backend.notes.length === 2, 5000);
        }
        function cleanup() { if (page !== null) close(); }

        function test_1_the_password_is_asked_here() {
            compare([backend.betterNotesUnlocks, locked().locked, locked().readOnly, locked().text], [true, true, false, "Secret title"]);
            const p = open();
            p.open(locked());
            compare([p.view, p.current, p.interacting, named("notePassword").visible, named("noteUnlock").visible], ["locked", null, true, true, true]);
            // a wrong one is said, and nothing is shown
            named("notePassword").text = "letmein";
            p.unlock();
            tryCompare(p, "lockError", "The password is wrong.", 5000);
            compare([p.view, p.password, named("notePassword").text, recorded("args")], ["locked", "", "", "show\n7\n--password-stdin\n"]);
            verify(recorded("args").indexOf("letmein") < 0, "the password is in no argument");
            // the right one: the note opens in the editor
            named("notePassword").text = "hunter2";
            p.unlock();
            tryCompare(p, "view", "note", 5000);
            compare([p.current.id, p.readOnly, editor().text, p.password], ["7", false, "the secret text", "hunter2"]);
            // not in the list, the search, a draft or the settings
            compare([locked().text, locked().loaded === true, JSON.stringify(backend.drafts)], ["Secret title", false, "{}"]);
            verify(JSON.stringify(backend.notes).indexOf("secret text") < 0 && root.lastOpen.indexOf("hunter2") < 0 && root.lastOpen.indexOf("secret") < 0);
        }

        function test_2_saved_with_the_password_and_forgotten_when_left() {
            const p = open();
            p.open(locked());
            named("notePassword").text = "hunter2";
            p.unlock();
            tryCompare(p, "view", "note", 5000);
            editor().text = "a new secret\nsecond line";
            let saved = false;
            p.saveNote(() => saved = true);
            tryVerify(() => saved, 5000);
            compare([recorded("args"), recorded("secret")], ["update\n7\n--password-stdin\n--body\n-\n", "a new secret\nsecond line"]);
            verify(recorded("args").indexOf("hunter2") < 0);
            compare([locked().text, JSON.stringify(backend.notes).indexOf("new secret"), JSON.stringify(backend.drafts)], ["Secret title", -1, "{}"]);
            // left with something typed and not saved: no draft of it is kept
            editor().text = "typed and left";
            p.leaveNote();
            compare([p.view, p.password, JSON.stringify(backend.drafts)], ["list", "", "{}"]);
            // the island closes on the open note and comes back: the password is asked again
            p.open(locked());
            named("notePassword").text = "hunter2";
            p.unlock();
            tryCompare(p, "view", "note", 5000);
            compare(editor().text, "a new secret\nsecond line");
            close();
            const again = open();
            tryCompare(again, "view", "locked", 5000);
            compare([again.password, again.current, named("notePassword").text], ["", null, ""]);
            again.leaveLocked();
            compare(again.view, "list");
            // a note that is not locked is as before
            again.open(backend.notes.find(n => n.id === "3"));
            tryVerify(() => again.view === "note" && !again.loading, 5000);
            compare([editor().text, again.password], ["milk", ""]);
            again.leaveNote();
        }

        function test_3_an_older_betternotes_can_only_open_it_there() {
            backend.betterNotesVersion = "BetterNotes 0.1.14";
            const p = open();
            p.open(locked());
            compare([p.view, backend.betterNotesUnlocks, named("notePassword").visible, named("noteUnlock").visible, p.interacting], ["locked", false, false, false, false]);
            let error = null;
            backend.loadText(locked(), e => error = e, "hunter2");
            compare(error, "locked", "no password is handed to a command that cannot take one");
            p.leaveLocked();
            backend.betterNotesVersion = "BetterNotes 0.1.15";
        }
    }
}
