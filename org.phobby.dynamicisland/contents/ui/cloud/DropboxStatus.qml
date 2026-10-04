/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Sync state from the Dropbox client of this computer: its own `dropbox
    status` command says it in a few words. Asked only while the Cloud tab or
    its indicator wants it. Needs the native module.
*/
import QtQuick
import "Rclone.js" as Rclone

QtObject {
    id: source

    property var core: null
    property string commandName: "dropbox"
    readonly property string name: "Dropbox"
    readonly property bool needsKey: false
    readonly property var local: core !== null ? core.local : null

    function detect(done: var): void {
        const found = local !== null && local.findExecutable(commandName).length > 0;
        done({ found: found, installed: found, running: found });
    }
    function status(done: var): void {
        if (local === null) { done({ state: "unknown", progress: -1, problem: "" }); return; }
        const command = local.findExecutable(commandName);
        if (command.length === 0) { done({ state: "unknown", progress: -1, problem: "" }); return; }
        local.run(command, ["status"], (code, out) => done(Object.assign(Rclone.dropboxState(code, out), { problem: "" })));
    }
}
