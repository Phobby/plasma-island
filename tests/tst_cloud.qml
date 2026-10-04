/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Cloud tab's backend with the real `rclone` command, on remotes made
    for the test in a configuration file of its own (never the user's): a
    folder of this computer as a cloud, a WebDAV address nobody answers at,
    and one whose sign-in has run out (tests/ai-server.py). Listing, odd
    names that try to be options or commands, how full, alerts and their
    pause, fetching for dragging, downloading without overwriting, uploading
    with its three answers to "it is there already", and sync state from
    stand-ins for Syncthing and Dropbox.

    Needs the native module and rclone (on the PATH, or tests/.run/rclone);
    skipped without them. Everything is written under tests/.run/.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 200
    height: 100

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string run: here + "/.run/cloud-" + Math.floor(Math.random() * 1e9).toString(36)
    readonly property string box: run + "/data"
    readonly property string conf: run + "/rclone.conf"

    readonly property Component streamMaker: Qt.createComponent("../org.phobby.dynamicisland/contents/ui/StreamBridge.qml")
    QtObject {
        id: nativeCore
        readonly property var local: root.local
        property bool secretsAvailable: false
        function newStream(owner) { return root.streamMaker.status === Component.Ready ? root.streamMaker.createObject(owner) : null; }
    }
    ActivityManager { id: activities }
    Theme { id: islandTheme; follow: false }
    TransferHub { id: transferHub; manager: activities; theme: islandTheme }
    Component { id: backendComponent; CloudBackend { core: nativeCore; enabled: true; hub: transferHub } }
    SignalSpy { id: alertSpy; signalName: "alert" }
    SignalSpy { id: endedSpy; signalName: "alertEnded" }
    SignalSpy { id: uploadedSpy; signalName: "uploaded" }

    TestCase {
        name: "Cloud"
        when: windowShown

        property string rclone: ""
        property var cloud: null
        property int port: 0
        function sh(program, args) {
            let out = null;
            root.local.run(program, args, (code, text, err) => out = { code: code, out: text, err: err });
            tryVerify(() => out !== null, 20000);
            return out;
        }
        function wait_(fn, ms) { let r = null; fn(x => r = x === undefined ? true : x); tryVerify(() => r !== null, ms || 20000); return r; }
        function list(id, path, fresh) { return wait_(done => cloud.list(id, path, fresh === true, done)); }
        function fresh(settings) {
            if (cloud !== null) cloud.destroy();
            cloud = backendComponent.createObject(root, Object.assign({ commandName: rclone, extra: ["--config", root.conf], downloadsFolder: root.run + "/Downloads", cacheFolder: root.run + "/cache" }, settings || {}));
            alertSpy.target = cloud; endedSpy.target = cloud; uploadedSpy.target = cloud;
            alertSpy.clear(); endedSpy.clear(); uploadedSpy.clear();
            wait_(done => cloud.detect(done));
            return cloud;
        }

        function initTestCase() {
            if (root.local === null) skip("the native module is not built: ./install.sh");
            Lang.setting = "en";
            activities.warm = true;
            rclone = root.local.fileSize(root.here + "/.run/rclone") > 0 ? root.here + "/.run/rclone" : root.local.findExecutable("rclone");
            if (rclone.length === 0) skip("rclone is not installed (and there is no tests/.run/rclone)");
            // the test's cloud: a folder, with names that try to be something else
            const names = ["a.txt", "-rf", "--config=x", "Türkçe adı çğş İı.txt", "two  spaces .txt", "q\"uo'te.txt", "$(touch PWNED);`touch PWNED2`.txt", "x".repeat(200) + ".txt"];
            for (const n of names) verify(root.local.writeTextFile(root.box + "/" + n, "content of " + n.slice(0, 20)));
            verify(root.local.writeTextFile(root.box + "/Belgeler çğş/inner.txt", "inner"));
            verify(root.local.writeTextFile(root.box + "/Belgeler çğş/deep/deeper.txt", "deeper"));
            sh("mkdir", ["-p", root.run + "/Downloads", root.run + "/drop"]);
            let answer = null;
            root.local.run("python3", [root.here + "/ai-server.py", "--log", root.run + "/server.log", "--key", "st-key", "--lifetime", "120"], (code, out) => answer = out);
            tryVerify(() => answer !== null, 10000);
            port = Number(answer.trim());
            verify(port > 0);
            const make = args => compare(sh(rclone, ["--config", root.conf, "config", "create"].concat(args)).code, 0);
            make(["box", "alias", "remote=" + root.box]);
            make(["dead", "webdav", "url=http://127.0.0.1:9/dav", "vendor=other"]);
            make(["expired", "webdav", "url=http://127.0.0.1:" + port + "/dav401", "vendor=other"]);
            make(["mem", "memory"]);
        }
        function cleanupTestCase() {
            if (cloud !== null) cloud.destroy();
            if (port > 0) { const x = new XMLHttpRequest(); x.open("GET", "http://127.0.0.1:" + port + "/__quit"); x.send(); wait(200); }
        }

        function test_01_found_or_not() {
            fresh({ commandName: "no-such-rclone-xyz" });
            compare([cloud.looked, cloud.command, cloud.clouds.length], [true, "", 0]);
            compare(list("box", "").problem.kind, "missing");
            fresh({ hiddenJson: JSON.stringify(["mem"]), aliasesJson: JSON.stringify({ box: "My Box" }) });
            compare(cloud.clouds, [{ id: "box", name: "My Box", type: "alias" }, { id: "dead", name: "dead", type: "webdav" }, { id: "expired", name: "expired", type: "webdav" }]);
            // only a remote rclone itself named is ever put into a command
            for (const id of ["nosuch", "box:", "-rf", "--config", "box; touch PWNED"]) compare([id, cloud.provider(id), list(id, "").ok], [id, null, false]);
        }

        function test_02_listing_one_level_names_as_they_are() {
            fresh();
            const top = list("box", "");
            compare([top.ok, top.more, top.entries.length], [true, false, 9]);
            const names = top.entries.map(e => e.name);
            for (const n of ["-rf", "--config=x", "Türkçe adı çğş İı.txt", "two  spaces .txt", "q\"uo'te.txt", "$(touch PWNED);`touch PWNED2`.txt", "Belgeler çğş"]) verify(names.indexOf(n) >= 0, n);
            compare(names.indexOf("inner.txt"), -1, "one level only");
            const folder = top.entries.find(e => e.name === "Belgeler çğş"), file = top.entries.find(e => e.name === "a.txt");
            compare([folder.dir, file.dir, file.size, file.modified > 0], [true, false, 16, true]);
            verify(top.entries.find(e => e.name.length > 200).shown.length < 160, "a long name is cut for showing");
            compare(list("box", "Belgeler çğş").entries.map(e => e.name).sort(), ["deep", "inner.txt"]);
            compare(list("box", "Belgeler çğş/deep").entries.map(e => e.name), ["deeper.txt"]);
            compare(list("box", "../../..").entries.length, 9, "a path cannot leave the remote");
            compare(list("box", "nowhere").problem.kind, "notfound");
            // kept for a minute, unless asked afresh
            verify(root.local.writeTextFile(root.box + "/new.txt", "new"));
            compare([list("box", "").entries.length, list("box", "", true).entries.length], [9, 10]);
            root.local.removeFile(root.box + "/new.txt");
            compare(root.local.fileSize(root.box + "/PWNED") + root.local.fileSize(root.here + "/PWNED") + root.local.fileSize(root.run + "/PWNED"), -3, "no name was run as a command");
        }

        function test_03_unreachable_and_sign_in_run_out() {
            fresh();
            const dead = list("dead", "");
            compare([dead.ok, dead.problem.kind, cloud.syncOf("dead").state], [false, "network", "offline"]);
            compare(cloud.problemText(dead.problem, "dead"), "dead cannot be reached. Is there a connection?");
            tryCompare(alertSpy, "count", 1);
            compare([alertSpy.signalArguments[0][0], alertSpy.signalArguments[0][1], alertSpy.signalArguments[0][2]], ["dead", "unreachable", "dead cannot be reached"]);
            const gone = list("expired", "");
            compare([gone.ok, gone.problem.kind], [false, "auth"]);
            compare([cloud.problemText(gone.problem, "expired"), cloud.reconnectCommand("expired")],
                    ["The sign-in of expired has run out. Connect it again in your own terminal:", "rclone config reconnect expired:"]);
            compare([alertSpy.count, alertSpy.signalArguments[1][1]], [2, "auth"]);
            // asked again: the same alert is not said twice
            list("expired", "", true); list("dead", "", true);
            compare(alertSpy.count, 2);
            verify(JSON.stringify(cloud.troubles).indexOf("127.0.0.1") < 0 && cloud.alertedJson.indexOf("expired:auth") > 0);
        }

        function test_04_how_full_and_the_alerts_pause() {
            fresh({ warnPercent: 101, criticalPercent: 101 });
            cloud.refreshStorage();
            tryVerify(() => cloud.abouts["box"] !== undefined && cloud.abouts["mem"] !== undefined, 20000);
            const about = cloud.abouts["box"];
            verify(about.total > 0 && about.used >= 0 && about.free >= 0);
            compare([cloud.abouts["mem"], cloud.level("mem"), cloud.level("box")], [null, "unknown", "ok"], "a cloud that cannot say how full it is has no level");
            alertSpy.clear();
            // the thresholds lowered under what is used: a warning, then full
            cloud.warnPercent = 0;
            compare([cloud.level("box"), cloud.storageWarning, alertSpy.count], ["warning", true, 1]);
            compare([alertSpy.signalArguments[0][1], alertSpy.signalArguments[0][2]], ["storage", "box is nearly full"]);
            cloud.criticalPercent = 0;
            compare([cloud.level("box"), alertSpy.signalArguments[1][1], alertSpy.signalArguments[1][2]], ["critical", "full", "box is full"]);
            // back to room enough: the alert ends by itself
            endedSpy.clear();
            cloud.warnPercent = 101; cloud.criticalPercent = 101;
            compare([cloud.level("box"), cloud.storageWarning], ["ok", false]);
            verify(endedSpy.count >= 1);
            // full again within the pause: it stands, but is not said again
            const said = alertSpy.count;
            cloud.warnPercent = 0;
            compare([cloud.standing["box:storage"], alertSpy.count], [true, said]);
            // after the pause it is said again
            cloud.warnPercent = 101;
            const old = JSON.parse(cloud.alertedJson); old["box:storage"] = Date.now() - 7 * 3600000;
            cloud.alertedJson = JSON.stringify(old);
            cloud.warnPercent = 0;
            compare(alertSpy.count, said + 1);
            // alerts switched off: known, not said
            cloud.warnPercent = 101; cloud.alerts = false; cloud.alertedJson = "{}";
            cloud.warnPercent = 0;
            compare([cloud.storageWarning, alertSpy.count], [true, said + 1]);
        }

        function test_05_fetched_for_dragging_and_downloaded_without_overwriting() {
            fresh();
            const top = list("box", ""), entry = top.entries.find(e => e.name === "Türkçe adı çğş İı.txt"), dash = top.entries.find(e => e.name === "-rf");
            compare(cloud.readyPath("box", entry.name, entry), "");
            const local = wait_(done => cloud.fetch("box", entry.name, entry, true, done));
            compare([local, cloud.readyPath("box", entry.name, entry)], [cloud.cachePath("box", entry.name), local]);
            verify(local.indexOf(root.run + "/cache/box/") === 0);
            verify(backendComponent.createObject(root).cacheFolder.endsWith("/.cache/dynamicisland/cloud"), "the real one is under the user's cache");
            compare(root.local.readTextFile(local), "content of " + entry.name.slice(0, 20));
            compare(transferHub.count, 0, "fetched because the pointer rested on it: no transfer on the island");
            // the cloud's file changed: the copy does not count any more
            compare(cloud.readyPath("box", entry.name, Object.assign({}, entry, { size: entry.size + 1 })), "");

            // "Download": to the Downloads folder, shown as a transfer, never over a file that is there
            const first = wait_(done => cloud.download("box", "-rf", dash, done));
            compare([first, root.local.readTextFile(first)], [root.run + "/Downloads/-rf", "content of -rf"]);
            root.local.writeTextFile(first, "mine now");
            const second = wait_(done => cloud.download("box", "-rf", dash, done));
            compare([second, root.local.readTextFile(first), root.local.readTextFile(second)], [root.run + "/Downloads/-rf (1)", "mine now", "content of -rf"]);
            tryVerify(() => activities.currentEvent !== null || activities.queue.length > 0, 3000);
            // a folder is measured first, then comes whole
            const folder = top.entries.find(e => e.name === "Belgeler çğş");
            const size = wait_(done => cloud.measure("box", folder.name, done));
            compare([size.ok, size.count, size.bytes], [true, 2, 11]);
            const dir = wait_(done => cloud.download("box", folder.name, folder, done));
            compare([root.local.readTextFile(dir + "/inner.txt"), root.local.readTextFile(dir + "/deep/deeper.txt")], ["inner", "deeper"]);
            for (const f of [local]) root.local.removeFile(f);
        }

        function test_06_uploading_only_copies_and_asks_before_writing_over() {
            fresh();
            const drop = root.run + "/drop";
            root.local.writeTextFile(drop + "/a.txt", "the new a");
            root.local.writeTextFile(drop + "/-n new;$(touch PWNED).txt", "odd");
            root.local.writeTextFile(drop + "/folder ç/one.txt", "1");
            root.local.writeTextFile(drop + "/folder ç/sub/two.txt", "22");
            const urls = ["a.txt", "-n new;$(touch PWNED).txt", "folder ç"].map(n => "file://" + (drop + "/" + n).split("/").map(encodeURIComponent).join("/"));
            const plan = wait_(done => cloud.plan(urls.concat(["https://example.org/x", "file:///nowhere/at-all"]), "box", "", done), 30000);
            compare(plan.items.map(i => [i.name, i.folder, i.bytes, i.count, i.exists]).sort((a, b) => a[0] < b[0] ? -1 : 1),
                    [["-n new;$(touch PWNED).txt", false, 3, 1, false], ["a.txt", false, 9, 1, true], ["folder ç", true, 3, 2, false]], "only local files; what is there already is said");
            compare([plan.bytes, plan.count, plan.big], [15, 4, false]);

            const send = choice => { uploadedSpy.clear(); cloud.upload(plan.items, "box", "", choice); tryCompare(uploadedSpy, "count", 1, 30000); };
            // "Skip": what is there stays as it is
            send("skip");
            compare([root.local.readTextFile(root.box + "/a.txt"), root.local.readTextFile(root.box + "/-n new;$(touch PWNED).txt"), root.local.readTextFile(root.box + "/folder ç/sub/two.txt")],
                    ["content of a.txt", "odd", "22"]);
            // "Keep both": a new name
            const again = wait_(done => cloud.plan([urls[0]], "box", "", done));
            uploadedSpy.clear(); cloud.upload(again.items, "box", "", "both"); tryCompare(uploadedSpy, "count", 1, 30000);
            compare([root.local.readTextFile(root.box + "/a.txt"), root.local.readTextFile(root.box + "/a (1).txt")], ["content of a.txt", "the new a"]);
            // "Overwrite": only now
            uploadedSpy.clear(); cloud.upload(again.items, "box", "", "overwrite"); tryCompare(uploadedSpy, "count", 1, 30000);
            compare(root.local.readTextFile(root.box + "/a.txt"), "the new a");
            // what was dropped is still there, untouched
            compare([root.local.readTextFile(drop + "/a.txt"), root.local.readTextFile(drop + "/folder ç/one.txt"), root.local.fileSize(drop + "/-n new;$(touch PWNED).txt")], ["the new a", "1", 3]);
            compare(root.local.fileSize(root.box + "/PWNED") + root.local.fileSize(drop + "/PWNED") + root.local.fileSize(root.here + "/PWNED"), -3);
            compare(cloud.lastTarget, "box:");
            verify(list("box", "").entries.some(e => e.name === "a (1).txt"), "the listing is asked afresh after an upload");
            // into a folder
            const inner = wait_(done => cloud.plan([urls[0]], "box", "Belgeler çğş/deep", done));
            compare(inner.items[0].exists, false);
            uploadedSpy.clear(); cloud.upload(inner.items, "box", "Belgeler çğş/deep", "skip"); tryCompare(uploadedSpy, "count", 1, 30000);
            compare([root.local.readTextFile(root.box + "/Belgeler çğş/deep/a.txt"), cloud.lastTarget], ["the new a", "box:Belgeler çğş/deep"]);
        }

        // The native helper that drags a file out: only a file that is there (the drag itself needs a hand on the mouse).
        function test_065_only_a_real_file_is_dragged() {
            const maker = Qt.createComponent("../org.phobby.dynamicisland/contents/ui/DragBridge.qml");
            compare(maker.status, Component.Ready, maker.errorString());
            const drag = maker.createObject(root);
            compare([drag.active, drag.start(root, root.run + "/nothing-here.txt"), drag.start(root, root.box), drag.start(null, root.box + "/a.txt"), drag.active], [false, false, false, false, false]);
            drag.destroy();
        }

        function test_07_sync_state_only_from_what_says_it() {
            fresh();
            const s = cloud.syncOf("box");
            compare([s.state, s.source], ["unknown", ""]);
            verify(s.note.indexOf("keeps no sync state") > 0, "unknown, and why");
            compare([cloud.hasSources, cloud.syncTimer.running, cloud.syncing], [false, false, false], "no source: nothing is asked");

            // Syncthing's interface (a stand-in): its key is needed
            const st = cloud.syncthingStatus;
            const ask = scene => { st.server = "http://127.0.0.1:" + port + "/st-" + scene; return wait_(done => st.status(done)); };
            compare(wait_(done => { st.server = "http://127.0.0.1:" + port + "/st-synced"; st.detect(done); }).running, true);
            compare(ask("synced"), { state: "unknown", progress: -1, problem: "key" });
            st.secret = "st-key";
            compare([ask("synced").state, ask("syncing"), ask("paused").state, ask("error").state],
                    ["synced", { state: "syncing", progress: 0.425, problem: "" }, "paused", "error"]);
            st.server = "http://127.0.0.1:9";
            compare(wait_(done => st.status(done)).state, "offline");

            // Dropbox's own command (a stand-in) for a remote of that kind
            cloud.dropboxStatus.commandName = root.here + "/fake-dropbox";
            cloud.remotes = cloud.remotes.concat([{ name: "db", type: "dropbox" }]);
            const say = text => { root.local.writeTextFile(root.here + "/.run/fake-dropbox/status", text); cloud.sourcesFound = { Dropbox: { found: true } }; cloud.pollSources(); };
            say("Syncing 3 files • 2 secs");
            tryVerify(() => cloud.sync["Dropbox"] !== undefined && cloud.sync["Dropbox"].state === "syncing", 5000);
            compare([cloud.syncOf("db").state, cloud.syncOf("db").source, cloud.syncing, cloud.syncOf("box").state, cloud.syncTimer.running], ["syncing", "Dropbox", true, "unknown", true]);
            let done = 0;
            cloud.synced.connect(() => ++done);
            say("Up to date");
            tryVerify(() => cloud.sync["Dropbox"].state === "synced", 5000);
            compare([done, cloud.syncing], [1, false]);
            alertSpy.clear();
            say("Can't sync \"x\" (access denied)");
            tryCompare(alertSpy, "count", 1, 5000);
            compare([alertSpy.signalArguments[0][1], cloud.syncError], ["sync", true]);
            // neither the page nor the indicator wants it: nothing is asked
            cloud.indicator = false;
            compare(cloud.syncTimer.running, false);
            cloud.enabled = false;
            compare([cloud.syncTimer.running, cloud.storageTimer.running], [false, false]);
        }
    }
}
