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
            sh("rm -rf '" + root.home + "' && mkdir -p '" + node + "/v9.11.0/bin' '" + node + "/v22.3.0/bin' '" + node + "/v18.20.1/bin' '"
               + root.home + "/.bun/bin' '" + root.home + "/.tools/bin' '" + root.home + "/.local/bin'\n"
               // a script that needs the interpreter installed beside it, as npm's commands do
               + "printf '#!/usr/bin/env islandtestnode\\n' > '" + node + "/v22.3.0/bin/claude'\n"
               + "printf '#!/bin/sh\\necho \"node 22 ran $1\"\\n' > '" + node + "/v22.3.0/bin/islandtestnode'\n"
               + "printf '#!/bin/sh\\necho old\\n' > '" + node + "/v9.11.0/bin/claude'\n"
               + "printf '#!/bin/sh\\necho agy\\n' > '" + root.home + "/.tools/bin/agy'\n"
               + "printf 'registry=https://example.invalid/\\nprefix=~/.tools\\n' > '" + root.home + "/.npmrc'\n"
               + "chmod +x '" + node + "'/*/bin/* '" + root.home + "/.tools/bin/agy'\n"
               // not a command: a file that cannot be run, and a folder of that name
               + "printf 'x' > '" + root.home + "/.bun/bin/claude'; mkdir '" + root.home + "/.local/bin/claude'");
        }

        function test_the_newest_node_of_nvm() {
            compare(root.local.findExecutable("claude", root.home), root.home + "/.nvm/versions/node/v22.3.0/bin/claude");
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
