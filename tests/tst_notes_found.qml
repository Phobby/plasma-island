/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Where BetterNotes is looked for, and how it is started from there: its
    command, an AppImage that only has a menu entry, the Flatpak. Without the
    island's native module nothing can be looked for, which is not the same as
    "not installed". The native module is stood in for: nothing here runs.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 100
    height: 100

    property var onPath: ({})           // name → path
    property var files: ({})            // path → text
    property var ran: []                // [program, args]
    QtObject {
        id: tools
        property var watchedPaths: []
        signal pathChanged()
        function findExecutable(name) { return root.onPath[name] || ""; }
        function readTextFile(path) { return root.files[path] || ""; }
        function dataHome() { return "/home/someone/.local/share"; }
        function environment(name) { return name === "HOME" ? "/home/someone" : ""; }
        function run(program, args, done) { root.ran = root.ran.concat([[program, args]]); done(0, "", ""); }
        function sqliteQuery() { return []; }
    }
    QtObject {
        id: nativeCore
        readonly property var local: tools
        property bool secretsAvailable: false
        function existingPaths(paths) { return paths.filter(p => root.files[p] !== undefined); }
    }
    NotesBackend { id: backend; core: nativeCore; enabled: false }
    NotesBackend { id: bare; core: null; enabled: false }

    TestCase {
        name: "NotesFound"
        readonly property string entry: "/org.betternotes.BetterNotes.desktop"

        function init() { root.onPath = {}; root.files = {}; root.ran = []; backend.betterNotesSandboxed = false; }

        function test_not_installed() {
            compare(backend.betterNotesLaunch(), null);
            compare(backend.betterNotesCommand(), "");
            verify(backend.canLookForApps);
        }
        function test_its_command() {
            root.onPath = { betternotes: "/usr/bin/betternotes" };
            compare(backend.betterNotesLaunch(), { program: "/usr/bin/betternotes", args: [], flatpak: false });
        }
        function test_an_appimage_that_only_has_a_menu_entry() {
            const image = "/home/someone/Apps/Better Notes.AppImage";
            root.files = { [image]: "", ["~/.local/share/applications" + entry]: "[Desktop Entry]\nName=BetterNotes\nExec=\"" + image + "\" --open %F\n" };
            compare(backend.betterNotesLaunch(), { program: image, args: [], flatpak: false });
            // an entry left behind by an AppImage that was deleted is not BetterNotes
            root.files = { ["~/.local/share/applications" + entry]: "Exec=\"" + image + "\" --open %F\n" };
            compare(backend.betterNotesLaunch(), null);
        }
        function test_the_flatpak() {
            root.onPath = { flatpak: "/usr/bin/flatpak" };
            for (const dir of ["~/.local/share/flatpak/exports/share/applications", "/var/lib/flatpak/exports/share/applications"]) {
                for (const exec of ["/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=betternotes org.betternotes.BetterNotes --open @@ %F @@",
                                    "flatpak run org.betternotes.BetterNotes"]) {
                    root.files = { "/usr/bin/flatpak": "", [dir + entry]: "[Desktop Entry]\nExec=" + exec + "\n" };
                    compare(backend.betterNotesLaunch(), { program: "/usr/bin/flatpak", args: ["run", "org.betternotes.BetterNotes"], flatpak: true }, dir + ": " + exec);
                }
            }
            // started with `flatpak run`, and its notes are the sandbox's
            root.ran = [];
            backend.runBetterNotes(["list"], null, () => {});
            compare(root.ran, [["/usr/bin/flatpak", ["run", "org.betternotes.BetterNotes", "list"]]]);
            compare(backend.betterNotesFolder, "/home/someone/.var/app/org.betternotes.BetterNotes/data/betternotes");
        }
        function test_its_own_notes_folder_otherwise() {
            root.onPath = { betternotes: "/usr/bin/betternotes" };
            backend.runBetterNotes(["list"], null, () => {});
            compare(root.ran, [["/usr/bin/betternotes", ["list"]]]);
            compare(backend.betterNotesFolder, "/home/someone/.local/share/betternotes");
        }
        function test_without_the_native_module_nothing_can_be_looked_for() {
            compare(bare.canLookForApps, false);
            compare(bare.betterNotesLaunch(), null);
        }
    }
}
