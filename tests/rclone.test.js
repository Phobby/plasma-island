#!/usr/bin/env node
// rclone as the Cloud tab uses it (contents/ui/cloud/Rclone.js): the commands'
// arguments, names that try to be options, what its answers and errors mean.
// Run by tools/run-tests; tests/tst_cloud.qml runs the real command.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const R = load(path.join(UI, "cloud", "Rclone.js"));

let failed = 0, checked = 0;
function check(what, got, want) {
    ++checked;
    const g = JSON.stringify(got), w = JSON.stringify(want);
    if (g === w) return;
    ++failed;
    console.log("    FAILED: " + what + "\n      got  " + g + "\n      want " + w);
}
function test(name, body) {
    const before = failed;
    body();
    console.log((failed === before ? "  ok    " : "  FAIL  ") + name);
}

test("remotes: only what rclone named, only names that are names", () => {
    const remotes = R.parseRemotes('[{"name":"drive","type":"drive"},{"name":"my box","type":"alias"},{"name":"-rf","type":"x"},{"name":"a:b","type":"x"},{"name":"","type":"x"},{"nope":1}]');
    check("parsed", remotes, [{ name: "drive", type: "drive" }, { name: "my box", type: "alias" }]);
    check("known", ["drive", "my box", "other", "-rf", "drive:", "dri ve;rm", "--config"].map(n => R.known(n, remotes)), [true, true, false, false, false, false, false]);
    check("not JSON", R.parseRemotes("drive:\n"), []);
});

test("arguments: one argument for remote and path, after --", () => {
    const list = R.listArguments("drive", "Belgeler çğş/-rf");
    check("list", list.slice(-2), ["--", "drive:Belgeler çğş/-rf"]);
    check("list is one level", [list[0], list.indexOf("-R"), list.indexOf("--recursive")], ["lsjson", -1, -1]);
    check("a path cannot leave the remote", R.target("drive", "../../etc//./passwd/"), "drive:etc/passwd");
    check("a name like an option stays a path", R.listArguments("drive", "--config=/x").slice(-1), ["drive:--config=/x"]);
    check("about", R.aboutArguments("drive").slice(-2), ["--", "drive:"]);
    const down = R.downloadArguments("drive", "a/-x.txt", "/home/u/.cache/-x.txt", false);
    check("download a file", [down[0], down[1], down.slice(-3)], ["copyto", "--ignore-existing", ["--", "drive:a/-x.txt", "/home/u/.cache/-x.txt"]]);
    check("download a folder", R.downloadArguments("drive", "a", "/tmp/a", true)[0], "copy");
    const up = R.uploadArguments("/home/u/$(rm -rf ~);.txt", "drive", "a/$(rm -rf ~);.txt", false, false);
    check("upload", [up[0], up.indexOf("--ignore-existing") > 0, up.slice(-3)], ["copyto", true, ["--", "/home/u/$(rm -rf ~);.txt", "drive:a/$(rm -rf ~);.txt"]]);
    check("upload over an existing file, only when said", R.uploadArguments("/a", "drive", "a", false, true).indexOf("--ignore-existing"), -1);
    for (const args of [list, down, up, R.uploadArguments("/d", "drive", "d", true, true), R.sizeArguments("drive", "x"), R.aboutArguments("drive")]) {
        check("only reading and copying: " + args[0], ["lsjson", "about", "size", "copy", "copyto"].indexOf(args[0]) >= 0, true);
        for (const never of ["move", "moveto", "sync", "delete", "purge", "rmdir", "rmdirs", "deletefile", "--delete-after", "--config", "--rc"])
            check(args[0] + " never " + never, args.indexOf(never), -1);
        check(args[0] + ": no prompt", args.indexOf("--ask-password=false") > 0, true);
    }
    check("reconnect", R.reconnectCommand("my drive"), "rclone config reconnect my drive:");
});

test("a listing: names as plain text, one level, a limit", () => {
    const json = JSON.stringify([
        { Path: "b.txt", Name: "b.txt", Size: 6, ModTime: "2026-10-04T17:33:57.5+03:00", IsDir: false },
        { Path: "Belgeler çğş", Name: "Belgeler çğş", Size: -1, ModTime: "2026-10-01T10:00:00Z", IsDir: true },
        { Path: "x", Name: "a\u0007b\u202egnp.exe", Size: 1, ModTime: "", IsDir: false },
        { Path: "x/y", Name: "x/y", Size: 1, IsDir: false }, { Name: "" }, null]);
    const got = R.parseList(json);
    check("count", [got.entries.length, got.more], [3, false]);
    check("a folder", got.entries[1], { name: "Belgeler çğş", shown: "Belgeler çğş", dir: true, size: -1, modified: Date.parse("2026-10-01T10:00:00Z") });
    check("control and direction characters are not shown", got.entries[2].shown, "a\ufffdb\ufffdgnp.exe");
    check("the name itself is kept for the command", got.entries[2].name, "a\u0007b\u202egnp.exe");
    check("a long name is cut", [R.display("x".repeat(500)).length, R.display("<b>&amp;")], [151, "<b>&amp;"]);
    check("not JSON", R.parseList("NOTICE: nope"), null);
    const many = JSON.stringify(Array.from({ length: 2100 }, (_, i) => ({ Name: "f" + i, Size: 1, IsDir: false })));
    check("the limit", [R.parseList(many).entries.length, R.parseList(many).more], [2000, true]);

    const e = (name, dir, size, modified) => ({ name: name, shown: name, dir: dir, size: size, modified: modified });
    const list = [e("b10.txt", false, 5, 30), e("Zeta", true, -1, 10), e("b2.txt", false, 50, 20), e("alpha", true, -1, 40), e("Çay.txt", false, 1, 5)];
    check("by name, folders first", R.sorted(list, "name", false).map(x => x.name), ["alpha", "Zeta", "b2.txt", "b10.txt", "Çay.txt"]);
    check("by size, largest first", R.sorted(list, "size", true).map(x => x.name), ["alpha", "Zeta", "b2.txt", "b10.txt", "Çay.txt"]);
    check("by date, newest first", R.sorted(list, "date", true).map(x => x.name), ["alpha", "Zeta", "b10.txt", "b2.txt", "Çay.txt"]);
    check("search in the open folder", R.filtered(list, " B1 ").map(x => x.name), ["b10.txt"]);
    check("icons by the name only", [R.icon(e("a", true)), R.icon(e("a.PDF", false)), R.icon(e("a.tar.gz", false)), R.icon(e("noext", false))],
          ["folder", "application-pdf", "package-x-generic", "text-x-generic"]);
});

test("storage", () => {
    check("all three", R.parseAbout('{"total":100,"used":91,"free":9}'), { used: 91, total: 100, free: 9 });
    check("no total: used + free", R.parseAbout('{"used":30,"free":70}').total, 100);
    check("only used (Google Photos-like)", R.parseAbout('{"used":30}'), { used: 30, total: -1, free: -1 });
    check("nothing", [R.parseAbout("{}"), R.parseAbout("NOTICE: doesn't support about")], [null, null]);
    check("fullness", [R.fullness({ used: 91, total: 100 }), R.fullness({ used: 30, total: -1 }), R.fullness(null)], [91, -1, -1]);
    check("levels", [89.9, 90, 97.9, 98, 100].map(u => R.storageLevel({ used: u, total: 100 }, 90, 98)), ["ok", "warning", "warning", "critical", "critical"]);
    check("no total, no level", R.storageLevel({ used: 5, total: -1 }, 90, 98), "unknown");
    check("size", R.parseSize('{"count":4,"bytes":3000010,"sizeless":0}'), { count: 4, bytes: 3000010 });
    check("an alert's pause", [R.due(0, 1000, 6), R.due(1000, 1000 + 5 * 3600000, 6), R.due(1000, 1000 + 6 * 3600000, 6)], [true, false, true]);
});

test("a copy's progress", () => {
    const line = JSON.stringify({ level: "notice", msg: "Transferred…", stats: { bytes: 750000, totalBytes: 3000000, speed: 1000000, eta: 2, errors: 0 } });
    check("numbers", R.parseProgress(line), { bytes: 750000, total: 3000000, speed: 1000000, eta: 2, percent: 25 });
    check("no total yet", R.parseProgress(JSON.stringify({ stats: { bytes: 0, totalBytes: 0, speed: 0, eta: null } })), { bytes: 0, total: 0, speed: 0, eta: -1, percent: -1 });
    check("another line", [R.parseProgress('{"level":"error","msg":"x"}'), R.parseProgress("plain")], [null, null]);
});

test("what went wrong", () => {
    const p = (code, text) => R.problem(code, text).kind;
    check("unreachable", p(5, '2026/10/04 17:34:52 NOTICE: Failed to lsjson with 2 errors: last error was: error in ListJSON: couldn\'t list files: Propfind "http://127.0.0.1:9/dav/": dial tcp 127.0.0.1:9: connect: connection refused'), "network");
    check("no such host", p(1, "NOTICE: … dial tcp: lookup no-such-host.invalid on 127.0.0.53:53: no such host"), "network");
    check("not a remote", p(1, '2026/10/04 17:34:52 CRITICAL: Failed to create file system for "nosuch:": didn\'t find section in config file ("nosuch")'), "remote");
    check("gone", p(3, "2026/10/04 17:34:52 NOTICE: Failed to lsjson with 2 errors: last error was: error in ListJSON: directory not found"), "notfound");
    check("not allowed", p(6, '2026/10/04 17:34:52 NOTICE: Failed to lsjson: failed to open directory "": open /home/u/x: permission denied'), "denied");
    check("sign-in ran out", p(1, 'CRITICAL: Failed to create file system for "drive:": couldn\'t find root directory ID: Get "https://www.googleapis.com/…": couldn\'t fetch token: invalid_grant: maybe token expired? - try refreshing with "rclone config reconnect drive:"'), "auth");
    check("401", p(1, "NOTICE: Failed to lsjson: 401 Unauthorized"), "auth");
    check("no room", p(1, "ERROR : big.bin: Failed to copy: googleapi: Error 403: The user's Drive storage quota has been exceeded., storageQuotaExceeded"), "full");
    check("no answer in time", R.problem(-1, ""), { kind: "timeout", detail: "" });
    check("a JSON log line", p(1, '{"level":"error","msg":"Failed to copy: dial tcp: i/o timeout","source":"x"}'), "network");
    const odd = R.problem(1, "2026/10/04 17:34:52 ERROR : Something odd happened with /home/user/.config/rclone/rclone.conf and \"/tmp/secret file\"");
    check("anything else: rclone's words, no path of this computer", odd, { kind: "unknown", detail: "Something odd happened with … and \"… file\"" });
});

test("names on this computer", () => {
    check("free", R.uniqueName("a.txt", ["b.txt"]), "a.txt");
    check("taken", R.uniqueName("a.txt", ["a.txt", "a (1).txt"]), "a (2).txt");
    check("no ending", R.uniqueName("Makefile", ["Makefile"]), "Makefile (1)");
    check("a dot file", R.uniqueName(".env", [".env"]), ".env (1)");
    check("a dropped address", R.localPath("file:///home/u/Belgeler%20%C3%A7/a%23b.txt"), "/home/u/Belgeler ç/a#b.txt");
    check("not a local file", [R.localPath("https://example.org/a"), R.localPath("smb://x/y"), R.localPath("")], ["", "", ""]);
    check("base name", [R.baseName("/a/b/c.txt"), R.baseName("/a/b/dir/")], ["c.txt", "dir"]);
    check("back to an address", R.fileUrl("/home/u/Belgeler ç/a#b.txt"), "file:///home/u/Belgeler%20%C3%A7/a%23b.txt");
});

test("sync states of the sources", () => {
    check("Syncthing", [R.syncthingState(100, false, 0, true).state, R.syncthingState(42.5, false, 0, true), R.syncthingState(50, true, 0, true).state,
                        R.syncthingState(50, false, 2, true).state, R.syncthingState(100, false, 0, false).state, R.syncthingState(undefined, false, 0, true).state],
          ["synced", { state: "syncing", progress: 0.425 }, "paused", "error", "offline", "unknown"]);
    check("Dropbox", ["Up to date", "Syncing 3 files • 2 secs", "Syncing paused", "Dropbox isn't running!", "Can't sync \"x\" (access denied)", "Connecting...", "", "Something new"]
          .map(t => R.dropboxState(0, t).state), ["synced", "syncing", "paused", "offline", "error", "offline", "unknown", "unknown"]);
    check("Dropbox: the command failed", R.dropboxState(1, "Up to date").state, "unknown");
    check("rclone mounts", R.mounts("tmpfs /run tmpfs rw 0 0\ndrive: /home/u/Drive fuse.rclone rw,nosuid 0 0\nbox:docs /mnt/My\\040Box fuse.rclone rw 0 0\nportal /run/user/1000/doc fuse.portal rw 0 0"),
          [{ remote: "drive", path: "/home/u/Drive" }, { remote: "box", path: "/mnt/My Box" }]);
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
