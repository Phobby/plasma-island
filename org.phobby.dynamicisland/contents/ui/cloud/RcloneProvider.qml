/*
    SPDX-License-Identifier: GPL-2.0-or-later

    A cloud reached through the `rclone` command: Google Drive, OneDrive,
    Dropbox, Nextcloud/WebDAV, a server of one's own, whatever the user set up
    with `rclone config`. The island only runs the command (without a shell,
    see Rclone.js for the arguments) and reads what it prints; rclone's
    configuration file, its tokens and passwords are never opened here.

    Short questions (a listing, the room left) are asked with a time limit; a
    copy runs in a helper of its own, reports its progress line by line and
    can be cancelled. Needs the native module.
*/
import QtQuick
import "Rclone.js" as Rclone

CloudProvider {
    id: provider

    property string command: ""             // the full path of rclone
    property string remote: ""              // a name `rclone listremotes` gave
    // Put before every command's arguments (the tests name a configuration of their own).
    property var extra: []
    // Where a copy's helper runs: a folder of the island's own.
    property string workFolder: ""
    readonly property var local: core !== null ? core.local : null

    function ask(args: var, milliseconds: int, done: var): void {
        if (local === null || command.length === 0) { done(-1, "", ""); return; }
        if (typeof local.runFor === "function") local.runFor(milliseconds, command, extra.concat(args), done);
        else local.run(command, extra.concat(args), done);
    }
    function list(path: string, done: var): void {
        ask(Rclone.listArguments(remote, path), 90000, (code, out, err) => {
            const listing = code === 0 ? Rclone.parseList(out) : null;
            if (listing !== null) done({ ok: true, entries: listing.entries, more: listing.more, problem: null });
            else done({ ok: false, entries: [], more: false, problem: Rclone.problem(code, err) });
        });
    }
    function about(done: var): void {
        ask(Rclone.aboutArguments(remote), 90000, (code, out, err) => {
            // (a cloud that cannot say how full it is answers with a notice and nothing else)
            if (code === 0 || /doesn't support about/i.test(err)) done({ ok: true, about: code === 0 ? Rclone.parseAbout(out) : null, problem: null });
            else done({ ok: false, about: null, problem: Rclone.problem(code, err) });
        });
    }
    function size(path: string, done: var): void {
        ask(Rclone.sizeArguments(remote, path), 120000, (code, out, err) => {
            const size = code === 0 ? Rclone.parseSize(out) : null;
            if (size !== null) done({ ok: true, count: size.count, bytes: size.bytes, problem: null });
            else done({ ok: false, count: 0, bytes: 0, problem: Rclone.problem(code, err) });
        });
    }

    // ---- copies ----------------------------------------------------------------------
    readonly property Component jobMaker: Component {
        QtObject {
            id: job
            property var stream: null
            property var progress: null
            property var done: null
            property string said: ""
            property bool cancelled: false
            function cancel(): void { cancelled = true; if (stream !== null) stream.stop(); }
            readonly property Connections watch: Connections {
                target: job.stream
                function onLines(lines) {
                    for (const line of lines) {
                        const p = Rclone.parseProgress(line);
                        if (p !== null) { if (job.progress) job.progress(p); continue; }
                        const message = Rclone.logMessage(line);
                        if (message.length > 0) job.said = (job.said + message + "\n").slice(-4000);
                    }
                }
                function onFinished(exitCode, errorOutput) {
                    const result = job.cancelled ? { ok: false, cancelled: true, problem: null }
                                 : exitCode === 0 ? { ok: true, cancelled: false, problem: null }
                                 : { ok: false, cancelled: false, problem: Rclone.problem(exitCode, job.said + errorOutput) };
                    const then = job.done;
                    job.done = null;
                    job.stream.destroy();
                    job.destroy();
                    if (then) then(result);
                }
            }
        }
    }
    function copy(args: var, progress: var, done: var): var {
        const stream = core !== null && typeof core.newStream === "function" ? core.newStream(provider) : null;
        if (stream === null || command.length === 0) { done({ ok: false, cancelled: false, problem: { kind: "missing", detail: "" } }); return null; }
        stream.mergeErrors = true;
        const job = jobMaker.createObject(provider, { stream: stream, progress: progress, done: done });
        if (!stream.start(command, extra.concat(args), "", workFolder)) {
            job.done = null; stream.destroy(); job.destroy();
            done({ ok: false, cancelled: false, problem: { kind: "missing", detail: "" } });
            return null;
        }
        return job;
    }
    function download(path: string, local: string, folder: bool, progress: var, done: var): var {
        return copy(Rclone.downloadArguments(remote, path, local, folder), progress, done);
    }
    // Into the island's own cache: there a newer file of the cloud replaces the older copy.
    function fetch(path: string, local: string, progress: var, done: var): var {
        return copy(Rclone.downloadArguments(remote, path, local, false).filter(a => a !== "--ignore-existing"), progress, done);
    }
    function upload(local: string, path: string, folder: bool, overwrite: bool, progress: var, done: var): var {
        return copy(Rclone.uploadArguments(local, remote, path, folder, overwrite), progress, done);
    }
}
