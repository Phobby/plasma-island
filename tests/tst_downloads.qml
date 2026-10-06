/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Browser downloads as the download folder shows them (native
    DownloadWatcher, providers/BrowserDownloadProvider.qml), replayed in a
    folder of the test's own with the file events that were recorded from the
    real browsers:

      Zen 1.22 / Firefox 157   "name.bin" (empty) and "J-w3DTrx.bin.part";
                               80 ms later the latter is renamed to
                               "name.p6NHCVxw.bin.part", grows, and is renamed
                               to "name.bin" at the end
      Chromium                 "Unconfirmed 123456.crdownload", renamed to
                               "movie.mkv.crdownload", then to "movie.mkv"

    The watcher used to take the first rename for the end of the download and,
    finding no file of the name it had guessed, said "Failed" for a download
    that went well. Here: one download, its real name, "Downloaded", and no
    "Failed". Also: a cancelled one, a final file written anew as "name (1)",
    two at once, one that stands still, and one too short to be shown.
    Needs the native module (skipped when it is not built).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/providers"

Item {
    id: root
    width: 200
    height: 100

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    Loader { id: watch; source: "../org.phobby.dynamicisland/contents/ui/DownloadBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property var watcher: watch.status === Loader.Ready ? watch.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string dir: here + "/.run/downloads-" + Math.floor(Math.random() * 1e9).toString(36)

    // What the watcher said, in order.
    property var log: []
    Connections {
        target: root.watcher
        function onStarted(id, name, app) { root.log = root.log.concat(["start " + id + " [" + name + "]"]); core.downloadStarted(id, name, app); }
        function onRenamed(id, name) { root.log = root.log.concat(["name " + id + " [" + name + "]"]); core.downloadRenamed(id, name); }
        function onProgress(id, bytes, speed, stalled) { root.sizes[id] = bytes; root.stalls[id] = stalled; core.downloadProgress(id, bytes, speed, stalled); }
        function onFinished(id, path, outcome, bytes, host) {
            root.log = root.log.concat([outcome + " " + id + " [" + path.replace(root.dir + "/", "") + "] " + bytes]);
            core.downloadFinished(id, path, outcome, bytes, host);
        }
    }
    property var sizes: ({})
    property var stalls: ({})

    // The provider on top of it, with the island's own hub; the events it sends are kept.
    QtObject {
        id: core
        property bool downloadsEnabled: true
        signal downloadStarted(string id, string fileName, string application)
        signal downloadRenamed(string id, string fileName)
        signal downloadProgress(string id, real bytes, real speed, int stalled)
        signal downloadFinished(string id, string finalPath, string outcome, real bytes, string host)
    }
    Theme { id: islandTheme; follow: false }
    ActivityManager {
        id: activities
        property var flashed: []
        function flash(ev) { flashed = flashed.concat([ev]); }
    }
    TransferHub { id: hub; manager: activities; theme: islandTheme }
    BrowserDownloadProvider { id: provider; jobs: null; hub: hub; core: core; minSeconds: 0.3 }

    TestCase {
        name: "Downloads"
        when: windowShown

        function sh(script) { let out = null; root.local.runIn(root.dir, "sh", ["-c", script], (code, text) => out = text); tryVerify(() => out !== null, 10000); return out.trim(); }
        function ended() { return root.log.filter(l => /^(done|cancelled)/.test(l)); }
        function titles() { return activities.flashed.map(e => e.title); }

        function initTestCase() {
            if (root.local === null || root.watcher === null) skip("the native module is not built: ./install.sh");
            Lang.setting = "en";
            root.local.run("mkdir", ["-p", root.dir], () => {});
            tryVerify(() => root.local.listFiles(root.here + "/.run").length >= 0);
            wait(200);
            root.watcher.sampleInterval = 100;
            root.watcher.settleTime = 700;
            root.watcher.directories = [root.dir];
            tryCompare(root.watcher, "watchedDirectories", [root.dir]);
        }
        function init() { root.log = []; root.sizes = {}; root.stalls = {}; activities.flashed = []; }
        function cleanup() { sh("rm -rf ./* 2>/dev/null; true"); tryCompare(root.watcher, "count", 0, 5000); tryCompare(hub, "count", 0); }
        function cleanupTestCase() { if (root.local !== null) root.local.run("rm", ["-rf", root.dir], () => {}); }

        function test_1_firefox_one_download_and_no_failure() {
            // (the names and their order as Zen wrote them)
            sh(": > name.bin; head -c 32768 /dev/zero > J-w3DTrx.bin.part");
            wait(80);
            sh("mv J-w3DTrx.bin.part name.p6NHCVxw.bin.part");
            for (let i = 0; i < 6; ++i) { sh("head -c 400000 /dev/zero >> name.p6NHCVxw.bin.part"); wait(150); }
            tryCompare(hub, "count", 1, 3000);
            const t = hub.transfers[0];
            compare([t.fileName, t.kind, t.state, t.percent < 0, t.totalKnown], ["name.bin", "download", "running", true, false], "its name is known while it runs; its size is not");
            tryVerify(() => t.processedBytes >= 2000000 && t.speed > 0, 3000);
            compare(ended(), [], "the rename of the partial file is not an end");
            sh("mv name.p6NHCVxw.bin.part name.bin");
            tryVerify(() => ended().length === 1, 3000);
            compare(ended(), ["done 1 [name.bin] 2432768".replace("1", root.log[0].split(" ")[1])]);
            compare(root.log.filter(l => /^start/.test(l)).length, 1, "one download, not two");
            tryCompare(hub, "count", 0);
            compare(titles(), ["Downloaded"], "and no \"Failed\"");
            const said = activities.flashed[0];
            compare([said.color, said.trailing.text, said.subtitle.indexOf("name.bin") >= 0, said.subtitle.indexOf("2.3 MB") >= 0], [islandTheme.live, "Open folder", true, true]);
        }

        function test_2_chromium_unconfirmed_then_its_name() {
            sh("head -c 1000 /dev/zero > 'Unconfirmed 123456.crdownload'");
            tryVerify(() => root.log.length === 1);
            verify(/^start \d+ \[\]$/.test(root.log[0]), "no name yet: " + root.log[0]);
            sh("mv 'Unconfirmed 123456.crdownload' movie.mkv.crdownload");
            tryVerify(() => root.log.some(l => /name \d+ \[movie.mkv\]/.test(l)), 3000);
            for (let i = 0; i < 4; ++i) { sh("head -c 300000 /dev/zero >> movie.mkv.crdownload"); wait(150); }
            tryCompare(hub, "count", 1, 3000);
            compare(hub.transfers[0].fileName, "movie.mkv");
            sh("mv movie.mkv.crdownload movie.mkv");
            tryVerify(() => ended().length === 1, 3000);
            verify(/^done \d+ \[movie.mkv\] 1201000$/.test(ended()[0]), ended()[0]);
            compare(titles(), ["Downloaded"]);
        }

        function test_3_cancelled_is_not_a_failure() {
            sh(": > big.iso; head -c 500000 /dev/zero > big.Ab3dEf9h.iso.part");
            tryCompare(hub, "count", 1, 3000);
            sh("rm big.Ab3dEf9h.iso.part big.iso");
            wait(300);
            compare(ended(), [], "waited for under its final name first");
            tryVerify(() => ended().length === 1, 3000);
            verify(/^cancelled \d+ \[\] 500000$/.test(ended()[0]), ended()[0]);
            compare([titles(), activities.flashed[0].color === islandTheme.red], [["Cancelled"], false]);
        }

        function test_4_written_anew_under_another_name() {
            // (a file of that name is there already: the browser saves as "report (1).pdf")
            sh("echo old > report.pdf; : > 'report (1).pdf'; head -c 300000 /dev/zero > 'report (1).Qw3rTy8u.pdf.part'");
            tryCompare(hub, "count", 1, 3000);
            compare(hub.transfers[0].fileName, "report (1).pdf");
            sh("cat 'report (1).Qw3rTy8u.pdf.part' > 'report (1).pdf'; rm 'report (1).Qw3rTy8u.pdf.part'");
            tryVerify(() => ended().length === 1, 3000);
            verify(/^done \d+ \[report \(1\)\.pdf\] 300000$/.test(ended()[0]), ended()[0]);
            compare(titles(), ["Downloaded"]);
        }

        function test_5_two_at_once_each_by_itself() {
            sh(": > a.zip; : > b.zip; head -c 100000 /dev/zero > a.AAAAAAA1.zip.part; head -c 200000 /dev/zero > b.BBBBBBB2.zip.part");
            tryCompare(hub, "count", 2, 3000);
            compare(hub.transfers.map(t => t.fileName).sort(), ["a.zip", "b.zip"]);
            sh("mv a.AAAAAAA1.zip.part a.zip");
            tryVerify(() => ended().length === 1, 3000);
            compare([hub.count, hub.transfers[0].fileName, hub.transfers[0].state], [1, "b.zip", "running"]);
            sh("rm b.BBBBBBB2.zip.part b.zip");
            tryVerify(() => ended().length === 2, 3000);
            compare(titles(), ["Downloaded", "Cancelled"]);
        }

        function test_6_standing_still_and_too_short_to_show() {
            sh(": > slow.bin; head -c 100000 /dev/zero > slow.CCCCCCC3.bin.part");
            tryCompare(hub, "count", 1, 3000);
            tryVerify(() => hub.transfers[0].stalled >= 1, 4000, "it says for how long nothing came");
            compare(hub.transfers[0].speed, 0);
            sh("mv slow.CCCCCCC3.bin.part slow.bin");
            tryVerify(() => ended().length === 1, 3000);

            // there and done at once: never a live activity, only its end
            init();
            sh(": > tiny.txt; echo hi > tiny.DDDDDDD4.txt.part; sleep 0.2; mv tiny.DDDDDDD4.txt.part tiny.txt");
            tryVerify(() => ended().length === 1, 3000);
            compare([hub.count, titles()], [0, ["Downloaded"]]);
            // a partial file that comes and goes and leaves nothing: not a word
            init();
            sh("echo hi > gone.EEEEEEE5.txt.part; sleep 0.15; rm gone.EEEEEEE5.txt.part");
            wait(1500);       // (seen and waited for, or never seen at all)
            compare([hub.count, titles(), ended().filter(l => /^done/.test(l))], [0, [], []]);
        }

        function test_7_only_the_host_of_where_it_came_from() {
            if (sh("command -v setfattr >/dev/null && echo yes || python3 -c 'import os; print(\"yes\")'") !== "yes") skip("no way to set an attribute");
            sh(": > doc.pdf; head -c 5000 /dev/zero > doc.FFFFFFF6.pdf.part");
            sh("python3 -c \"import os; os.setxattr('doc.FFFFFFF6.pdf.part', 'user.xdg.origin.url', b'https://bob:SECRET-TOKEN@files.example.org/private/doc.pdf?token=SECRET-TOKEN')\"");
            if (sh("python3 -c \"import os; print(len(os.listxattr('doc.FFFFFFF6.pdf.part')))\"") !== "1") skip("this folder keeps no attributes");
            wait(400);
            sh("mv doc.FFFFFFF6.pdf.part doc.pdf");
            tryVerify(() => activities.flashed.length === 1, 3000);
            const said = JSON.stringify(activities.flashed[0]);
            verify(said.indexOf("files.example.org") > 0, said);
            verify(said.indexOf("SECRET") < 0 && said.indexOf("private") < 0 && said.indexOf("bob") < 0, "nothing but the host: " + said);
            compare(root.watcher.originHost(root.dir + "/doc.pdf"), "files.example.org");
        }
    }
}
