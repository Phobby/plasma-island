/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The BetterNotes folder is watched, so that a note edited in the app shows
    on the island at once. Listing the notes changes that folder too (SQLite
    makes its -wal beside the database and takes it away again): a listing
    must not call for the next one, or `betternotes list` runs for ever. Only
    a change of the database itself is listed again, and once.
    The real notes backend, with tests/fake-betternotes standing in for the
    command. Needs the native module (skipped when it is not built).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 100
    height: 100

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
    NotesBackend {
        id: backend
        core: nativeCore
        betterNotesName: root.here + "/fake-betternotes"
        betterNotesData: root.record
        enabled: false
        sourcesJson: JSON.stringify([{ id: "bn-1", type: "betternotes", name: "BetterNotes", server: "", user: "" }])
    }

    TestCase {
        name: "NotesWatch"
        when: windowShown

        // how often the command was asked for its list
        function lists() { return root.local.readTextFile(root.record + "/calls", 1000000).split("\n").filter(line => line === "list").length; }
        function database(script) {
            let made = null;
            root.local.run("python3", ["-c", "import sqlite3,sys\nc=sqlite3.connect(sys.argv[1])\n" + script + "\nc.commit()", root.record + "/notes.sqlite3"],
                           (code, out, err) => made = [code, err]);
            tryVerify(() => made !== null, 10000);
            compare(made[0], 0, made[1]);
        }

        function initTestCase() {
            if (root.local === null) skip("the native module is not built: ./install.sh");
            root.local.removeFile(root.record + "/calls");
            root.local.removeFile(root.record + "/notes.sqlite3");
            database("c.execute('create table notes(id integer, updated_at integer, is_locked integer)')\n"
                     + "c.execute('create table reminders(note_id integer, remind_at integer, dismissed integer)')\n"
                     + "c.executemany('insert into notes values(?,?,?)',[(3,100,0),(7,200,1)])");
            backend.enabled = true;
            backend.refresh();
            tryVerify(() => backend.loaded && backend.notes.length === 2, 5000);
        }

        function test_1_a_listing_does_not_call_for_the_next() {
            wait(1500);                 // what making the database and the first listing stirred up
            const before = lists();
            verify(before >= 1);
            wait(3500);                 // (a listing for every change of the folder came every 0.8 s)
            compare(lists(), before);
        }

        function test_2_a_change_of_the_database_is_listed_once() {
            const before = lists();
            database("c.execute('update notes set updated_at = 300 where id = 3')");
            tryVerify(() => lists() === before + 1, 5000);
            tryVerify(() => backend.notes.some(n => n.id === "3" && n.updated === 300), 3000);
            wait(3000);
            compare(lists(), before + 1);
        }

        function test_3_the_regular_refresh_does_not_start_it_either() {
            const before = lists();
            backend.refresh();
            tryVerify(() => lists() === before + 1, 5000);
            wait(3000);
            compare(lists(), before + 1);
        }
    }
}
