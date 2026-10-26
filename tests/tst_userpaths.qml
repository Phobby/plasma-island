/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Where a command is looked for (native/core/userpaths.h). The desktop shell
    does not have a terminal's PATH: Claude Code installed with npm under nvm,
    or with a prefix of npm's own, is there in every terminal and was "not
    found" on the island. A made-up home folder in tests/.run stands in for
    the user's. Needs the native module (skipped when it is not built).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 100
    height: 100

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string home: here + "/.run/userpaths"

    TestCase {
        name: "UserPaths"
        when: windowShown

        function sh(script) {
            let result = null;
            root.local.run("sh", ["-c", script], (code, out, err) => result = [code, out, err]);
            tryVerify(() => result !== null, 10000);
            compare(result[0], 0, result[2]);
            return result[1];
        }
        function initTestCase() {
            if (root.local === null) skip("the native module is not built: ./install.sh");
            const node = root.home + "/.nvm/versions/node";
            sh("rm -rf '" + root.home + "' && mkdir -p '" + node + "/v9.11.0/bin' '" + node + "/v22.10.0/bin' '" + node + "/v18.20.1/bin' '" + node + "/v22.9.0/bin' '"
               + root.home + "/.bun/bin' '" + root.home + "/.tools/bin' '" + root.home + "/.local/bin'\n"
               // a script that needs the interpreter installed beside it, as npm's commands do
               + "printf '#!/usr/bin/env islandtestnode\\n' > '" + node + "/v22.10.0/bin/claude'\n"
               + "printf '#!/bin/sh\\necho \"node 22 ran $1\"\\n' > '" + node + "/v22.10.0/bin/islandtestnode'\n"
               + "printf '#!/bin/sh\\necho older-minor\\n' > '" + node + "/v22.9.0/bin/claude'\n"
               + "printf '#!/bin/sh\\necho old\\n' > '" + node + "/v9.11.0/bin/claude'\n"
               + "printf '#!/bin/sh\\necho agy\\n' > '" + root.home + "/.tools/bin/agy'\n"
               + "printf 'registry=https://example.invalid/\\nprefix=~/.tools\\n' > '" + root.home + "/.npmrc'\n"
               + "chmod +x '" + node + "'/*/bin/* '" + root.home + "/.tools/bin/agy'\n"
               // not a command: a file that cannot be run, and a folder of that name
               + "printf 'x' > '" + root.home + "/.bun/bin/claude'; mkdir '" + root.home + "/.local/bin/claude'\n"
               // AppImages kept where they usually are: the newest name first, case not looked at, not a longer name
               + "mkdir -p '" + root.home + "/Applications' '" + root.home + "/Elsewhere'\n"
               + "printf '#!/bin/sh\\necho image\\n' > '" + root.home + "/Applications/Islandtestimage-1.2-x86_64.AppImage'\n"
               + "printf '#!/bin/sh\\n' > '" + root.home + "/Applications/islandtestimagery.AppImage'\n"
               + "printf '#!/bin/sh\\necho given\\n' > '" + root.home + "/Elsewhere/given-tool'\n"
               + "chmod +x '" + root.home + "'/Applications/* '" + root.home + "/Elsewhere/given-tool'");
        }
        function cleanup() { if (root.local !== null && root.local.commandPaths !== undefined) root.local.commandPaths = ({}); }

        function test_an_appimage() {
            compare(root.local.findExecutable("islandtestimage", root.home), root.home + "/Applications/Islandtestimage-1.2-x86_64.AppImage");
            compare(root.local.findExecutable("islandtest", root.home), "", "not a part of a longer name");
        }
        // A path given by hand (Settings › Diagnostics) comes first, for finding and for running.
        function test_a_path_given_by_hand() {
            if (root.local.commandPaths === undefined) skip("a native module from before commandPaths");
            const given = root.home + "/Elsewhere/given-tool";
            compare(root.local.findExecutable("islandtestgiven"), "");
            root.local.commandPaths = { islandtestgiven: given };
            compare(root.local.findExecutable("islandtestgiven"), given);
            const where = root.local.locate("islandtestgiven", "", false);
            compare([where.path, where.via, where.givenUsable], [given, "setting", true]);
            let result = null;
            root.local.run("islandtestgiven", [], (code, out) => result = [code, out.trim()]);
            tryVerify(() => result !== null, 10000);
            compare(result, [0, "given"], "run by its name: the path given is what runs");
            // a path that is not a program: looked for as usual, and said so
            const wrong = root.local.locate("sh", root.home + "/Elsewhere/nothing", true);
            compare([wrong.givenUsable, wrong.via, wrong.path.length > 0], [false, "path", true]);
            root.local.commandPaths = ({});
            compare(root.local.findExecutable("islandtestgiven"), "");
        }
        function test_where_it_looks() {
            if (typeof root.local.searchedDirectories !== "function") skip("a native module from before searchedDirectories");
            const dirs = root.local.searchedDirectories();
            verify(dirs.indexOf("/usr/bin") >= 0, "the PATH");
            const info = root.local.systemInfo();
            verify(String(info.qt).length > 0 && String(info.home).length > 0);
        }

        function test_the_newest_node_of_nvm() {
            compare(root.local.findExecutable("claude", root.home), root.home + "/.nvm/versions/node/v22.10.0/bin/claude");
        }
        function test_the_prefix_npm_was_given() {
            compare(root.local.findExecutable("agy", root.home), root.home + "/.tools/bin/agy");
        }
        function test_not_there() {
            compare(root.local.findExecutable("islandtestnothing", root.home), "");
            compare(root.local.findExecutable("islandtestnothing"), "");
            compare(root.local.findExecutable(""), "");
        }
        function test_the_path_and_a_full_path_as_before() {
            verify(root.local.findExecutable("sh").length > 0);
            const full = root.home + "/.tools/bin/agy";
            compare(root.local.findExecutable(full), full);
            compare(root.local.findExecutable(root.home + "/.bun/bin/claude"), "");
        }
        // The command is started with its own folder on the PATH: its interpreter is found.
        function test_a_script_finds_the_interpreter_beside_it() {
            const command = root.local.findExecutable("claude", root.home);
            let result = null;
            root.local.run(command, ["--version"], (code, out) => result = [code, out.trim()]);
            tryVerify(() => result !== null, 10000);
            compare(result, [0, "node 22 ran " + command]);
        }
    }
}
