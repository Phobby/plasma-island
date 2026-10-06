/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Downloads made by commands (native CommandWatcher,
    providers/CommandTransferProvider.qml) with a made-up /proc and /var in a
    folder of the test's own, so that apt under sudo, its children and its
    records can be played without being root, and without a network:

      * which processes are taken for a download (apt update, not apt list;
        git clone, not git's helpers; a script by its own name), and which
        are left out (no terminal: a background job);
      * what is read out of a command line: the sub-command, the host and the
        repository's name. A token or a password in it appears in no signal,
        no transfer and no event;
      * apt's stages from its children, the bytes from the packages that have
        arrived, and how it ended from its own records (done, failed, unknown);
      * git clone: the bytes of the pack, done with .git/HEAD, failed with the
        folder gone;
      * wget/curl: the bytes written; too small or too short is not shown.
    Needs the native module (skipped when it is not built).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/providers"
import "../org.phobby.dynamicisland/contents/ui/TransferFormat.js" as Fmt

Item {
    id: root
    width: 420
    height: 300

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    Loader { id: watch; source: "../org.phobby.dynamicisland/contents/ui/CommandBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property var watcher: watch.status === Loader.Ready ? watch.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string dir: here + "/.run/commands-" + Math.floor(Math.random() * 1e9).toString(36)

    // Everything the watcher ever says, as text: searched for what must never be in it.
    property string said: ""
    property var log: []
    Connections {
        target: root.watcher
        function onStarted(id, info) { root.said += JSON.stringify(info) + "\n"; root.log = root.log.concat(["start " + info.name + " " + info.kind + " [" + info.action + "] " + info.host + " " + info.repo + (info.background ? " bg" : "")]); }
        function onProgress(id, bytes, speed, stage) { root.said += stage + "\n"; root.last = { bytes: bytes, speed: speed, stage: stage }; }
        function onFinished(id, outcome, bytes, path) { root.said += outcome + path + "\n"; root.log = root.log.concat(["end " + outcome + " " + bytes + " " + path.replace(root.dir, "")]); }
    }
    property var last: ({})

    // The provider with the island's hub; the clock is the test's.
    property real time: 1000000
    QtObject {
        id: core
        function commandWatcher() { return root.watcher; }
        function packageKitWatcher() { return null; }
    }
    Theme { id: islandTheme; follow: false }
    ActivityManager {
        id: activities
        property var flashed: []
        function flash(ev) { flashed = flashed.concat([ev]); }
    }
    TransferHub { id: hub; manager: activities; theme: islandTheme; clock: () => root.time }
    CommandTransferProvider { id: provider; hub: hub; core: core; enabled: false; minSeconds: 1; minBytes: 1048576 }
    Loader {
        id: card
        width: 400
        active: hub.count > 0
        sourceComponent: TransfersCard { activity: QtObject { property var transfers: hub.transfers; property color color: "#0a84ff" } theme: islandTheme; width: 400 }
    }

    TestCase {
        name: "Commands"
        when: windowShown

        function sh(script) { let out = null; root.local.runIn(root.dir, "sh", ["-c", script], (code, text) => out = text); tryVerify(() => out !== null, 10000); return out.trim(); }
        // A process of the made-up /proc: its name, its arguments (separated by "|"), its parent, its terminal (0 = none).
        function process(pid, name, args, parent, tty, written) {
            sh("mkdir -p proc/" + pid + " && printf '%s\\n' '" + name + "' > proc/" + pid + "/comm"
               + " && printf '%s' '" + args + "' | tr '|' '\\000' > proc/" + pid + "/cmdline"
               + " && echo '" + pid + " (" + name + ") S " + (parent || 1) + " " + pid + " " + pid + " " + (tty === undefined ? 34816 : tty)
               + " -1 4194304 1 0 0 0 0 0 0 0 20 0 1 0 " + (5000 + pid) + " 1000 100' > proc/" + pid + "/stat"
               + " && ln -sfn '" + root.dir + "/work' proc/" + pid + "/cwd"
               + " && printf 'rchar: 10\\nwchar: " + (written || 0) + "\\n' > proc/" + pid + "/io");
        }
        function gone(pid) { sh("rm -rf proc/" + pid); }
        function look() { root.watcher.scan(); }
        function pass(seconds) { root.time += seconds * 1000; wait(300); }
        function titles() { return activities.flashed.map(e => e.title); }
        function text(name) { let found = null; const walk = i => { if (found === null && i.objectName === name) found = i; for (const c of i.children) walk(c); }; walk(card.item); return found ? found.text : ""; }

        function initTestCase() {
            if (root.local === null || root.watcher === null) skip("the native module is not built: ./install.sh");
            Lang.setting = "en";
            root.local.run("mkdir", ["-p", root.dir + "/proc", root.dir + "/work", root.dir + "/sys/var/cache/apt/archives", root.dir + "/sys/var/log/apt", root.dir + "/sys/var/lib/apt/periodic"], () => {});
            wait(300);
            root.watcher.procRoot = root.dir + "/proc";
            root.watcher.systemRoot = root.dir + "/sys";
            root.watcher.idleInterval = 600000;
            root.watcher.activeInterval = 600000;
            sh(": > sys/var/log/apt/history.log; : > sys/var/lib/apt/periodic/update-success-stamp; : > sys/var/cache/apt/archives/old_1.0_amd64.deb");
            provider.enabled = true;
            tryCompare(root.watcher, "enabled", true);
            compare(root.watcher.commands.length, Fmt.COMMANDS.length);
        }
        function init() { root.log = []; root.last = {}; activities.flashed = []; }
        function cleanup() { sh("rm -rf proc/* work/*"); look(); tryCompare(root.watcher, "count", 0); tryCompare(hub, "count", 0); }
        function cleanupTestCase() { if (root.local !== null) root.local.run("rm", ["-rf", root.dir], () => {}); }

        function test_1_what_counts_as_a_download() {
            process(10, "bash", "bash");
            process(11, "apt", "apt|list|--upgradable", 10);
            process(12, "git", "git|status", 10);
            process(13, "git", "git|index-pack|--stdin|--fix-thin", 10);
            process(14, "git-remote-http", "git-remote-https|origin|https://example.org/a/b", 10);
            process(15, "pip", "/usr/bin/python3|/usr/bin/pip|--version", 10);
            process(16, "apt", "apt|update", 1, 0);                 // no terminal: a background job
            process(17, "unattended-upgr", "/usr/bin/python3|/usr/bin/unattended-upgrade", 1, 0);
            look();
            compare([root.log, root.watcher.count], [[], 0]);

            process(20, "apt", "apt|update", 10);
            process(21, "apt-get", "apt-get|-y|install|hello", 10);
            process(22, "node", "node|/usr/lib/node_modules/npm/bin/npm-cli.js|install|left-pad", 10);
            process(23, "python3", "/usr/bin/python3|/usr/bin/pip|install|requests", 10);
            process(25, "pip3", "/usr/bin/python3|/usr/bin/pip3|download|numpy", 10);
            process(24, "wget", "wget|-q|https://files.example.org/big.iso", 10);
            look();
            compare(root.log.sort(), ["start apt packages [update]  ", "start apt-get packages [install]  ", "start npm download [install]  ",
                                      "start pip download [install]  ", "start pip3 download [download]  ", "start wget download [] files.example.org "]);
            // background jobs too, when asked for
            root.log = [];
            gone(16); gone(17);
            provider.background = true;
            tryCompare(root.watcher, "showBackground", true);
            process(30, "apt", "apt|update", 1, 0);
            look();
            compare(root.log, ["start apt packages [update]   bg"]);
            provider.background = false;
            tryCompare(root.watcher, "showBackground", false);
        }

        // A command line may hold a token or a password: nothing of it but the host and the repository's name gets out.
        function test_2_nothing_secret_leaves_the_command_line() {
            root.said = "";
            process(40, "git", "git|-c|http.extraHeader=Authorization: Bearer SECRET-HEADER|clone|--depth|1|https://bob:SECRET-TOKEN@git.example.org/team/project.git?token=SECRET-QUERY|secret-folder-SECRET-DIR", 10);
            process(41, "curl", "curl|-u|bob:SECRET-PASSWORD|--password|SECRET-OPTION|-H|X-Key: SECRET-KEY|-o|out.bin|https://alice:SECRET-URL@dl.example.org/path/SECRET-PATH/file.bin?sig=SECRET-SIG", 10, 34816, 5000000);
            process(42, "git", "git|clone|git@github.com:someone/thing.git", 10);
            look();
            compare(root.log.sort(), ["start curl download [] dl.example.org ", "start git clone [clone] git.example.org team/project", "start git clone [clone] github.com someone/thing"]);
            pass(2); look(); pass(0.4);
            tryCompare(hub, "count", 3);
            gone(40); gone(41); gone(42);
            look();
            tryCompare(hub, "count", 0);
            const everything = root.said + JSON.stringify(activities.flashed) + hub.transfers.map(t => t.headline).join();
            verify(everything.indexOf("SECRET") < 0, "a secret got out: " + everything);
            for (const word of ["bob", "alice", "Bearer", "sig=", "token", "out.bin"]) verify(everything.indexOf(word) < 0, word + " got out: " + everything);
            compare(root.watcher.describeAddress("https://bob:SECRET@h.example.org:8443/a/b/c.git?x=SECRET#f"), { host: "h.example.org", name: "c", repo: "b/c" });
            compare(root.watcher.describeAddress("not an address"), {});
        }

        function test_3_apt_update_its_stage_and_its_stamp() {
            process(50, "sudo", "sudo|apt|update", 10);
            process(51, "apt", "apt|update", 50);
            look();
            compare(root.log, ["start apt packages [update]  "]);
            process(52, "https", "/usr/lib/apt/methods/https", 51, 0);
            process(53, "gpgv", "/usr/lib/apt/methods/gpgv", 51, 0);
            pass(1.2); look(); look();
            tryCompare(hub, "count", 1);
            const t = hub.transfers[0];
            compare([t.headline, t.kind, t.detail, t.percent < 0, t.totalKnown, root.last.stage], ["apt - update", "packages", "Updating package lists", true, false, "lists"],
                    "the stage is known; a size is not, and none is made up");
            compare(text("transferAmount"), "Updating package lists");
            // it goes through: apt touches its stamp
            sh("sleep 1.1; touch sys/var/lib/apt/periodic/update-success-stamp");
            gone(51); gone(52); gone(53);
            pass(3); look();
            compare([root.log[1], titles()], ["end done 0 ", ["Updated"]]);
            compare(activities.flashed[0].color, islandTheme.live);

            // the same, and no stamp: nothing says how it went
            init();
            process(54, "apt", "apt|update", 50);
            look(); pass(1.5); look();
            gone(54);
            pass(1); look();
            compare([root.log[1], titles(), activities.flashed[0].color === islandTheme.red], ["end unknown 0 ", ["Finished"], false]);
        }

        function test_4_apt_install_stages_bytes_and_its_record() {
            process(60, "apt", "apt|install|hello|cowsay", 10);
            look();
            process(61, "http", "/usr/lib/apt/methods/http", 60, 0);
            pass(1.2); look(); look();
            tryCompare(hub, "count", 1);
            compare([hub.transfers[0].detail, hub.transfers[0].processedBytes], ["Downloading packages", 0]);
            // a package has arrived (what was there before does not count)
            sh("head -c 3000000 /dev/zero > sys/var/cache/apt/archives/hello_2.10_amd64.deb");
            pass(1); look();
            compare([hub.transfers[0].processedBytes, text("transferAmount")], [3000000, "Downloading packages · 2.9 MB / unknown"]);
            verify(hub.transfers[0].speed > 0);
            gone(61);
            process(62, "dpkg", "/usr/bin/dpkg|--unpack|hello.deb", 60);
            process(63, "dpkg-deb", "dpkg-deb|--fsys-tarfile", 62);
            pass(1); look(); look();
            compare(hub.transfers[0].detail, "Installing packages");
            sh("printf 'Start-Date: 2026-10-06  10:00:00\\nCommandline: apt install hello cowsay\\nInstall: hello:amd64 (2.10)\\nEnd-Date: 2026-10-06  10:00:05\\n' >> sys/var/log/apt/history.log");
            gone(60); gone(62); gone(63);
            pass(2); look();
            compare([root.log[1], titles()], ["end done 3000000 ", ["Installed"]]);
            verify(activities.flashed[0].subtitle.indexOf("apt - install") === 0 && activities.flashed[0].subtitle.indexOf("2.9 MB") > 0, activities.flashed[0].subtitle);

            // dpkg failed: apt's record says so
            init();
            process(64, "apt", "apt|install|broken", 10);
            look(); pass(1.5); look();
            sh("printf 'Start-Date: 2026-10-06  10:01:00\\nCommandline: apt install broken\\nError: Sub-process /usr/bin/dpkg returned an error code (1)\\nEnd-Date: 2026-10-06  10:01:02\\n' >> sys/var/log/apt/history.log");
            gone(64);
            pass(1); look();
            compare([root.log[1].split(" ").slice(0, 2).join(" "), titles(), activities.flashed[0].color], ["end failed", ["Failed"], islandTheme.red]);

            // over at once and no record (nothing to do, or "n" at the question): not a word
            init();
            process(65, "apt", "apt|install|hello", 10);
            look(); gone(65); pass(0.3); look();
            compare([root.log[1].split(" ").slice(0, 2).join(" "), titles()], ["end unknown", []]);
        }

        function test_5_git_clone_bytes_and_how_it_ended() {
            process(70, "git", "git|clone|https://github.com/pallets/flask", 10);
            look();
            sh("mkdir -p work/flask/.git/objects/pack && head -c 2500000 /dev/zero > work/flask/.git/objects/pack/tmp_pack_Vpgyl3");
            pass(1.2); look(); look();
            tryCompare(hub, "count", 1);
            const t = hub.transfers[0];
            compare([t.headline, t.kind, t.detail, t.processedBytes, t.totalKnown], ["github.com - pallets/flask", "clone", "Downloading", 2500000, false]);
            sh("head -c 10000000 /dev/zero >> work/flask/.git/objects/pack/tmp_pack_Vpgyl3");
            pass(1); look();
            compare(t.processedBytes, 12500000);
            verify(t.speed > 0 && t.remaining < 0, "a speed, and no remaining time without a size");
            sh("mv work/flask/.git/objects/pack/tmp_pack_Vpgyl3 work/flask/.git/objects/pack/pack-b1c1.pack; echo 'ref: refs/heads/main' > work/flask/.git/HEAD");
            gone(70);
            pass(1); look();
            compare([root.log[1], titles(), activities.flashed[0].trailing.text], ["end done 12500000 /work/flask", ["Downloaded"], "Open folder"]);

            // a repository that is not there, or Ctrl+C: git removes the folder
            init();
            process(71, "git", "git|clone|https://github.com/pallets/nope|elsewhere", 10);
            look();
            sh("mkdir -p work/elsewhere/.git");
            pass(1.5); look();
            sh("rm -rf work/elsewhere");
            gone(71);
            pass(1); look();
            compare([root.log[1], titles()], ["end failed 0 ", ["Failed"]]);
        }

        function test_6_plain_downloaders_bytes_and_what_is_too_small() {
            process(80, "wget", "wget|https://files.example.org/big.iso", 10, 34816, 0);
            look(); pass(1.5);
            compare(hub.count, 0, "long enough, but nothing fetched yet");
            process(80, "wget", "wget|https://files.example.org/big.iso", 10, 34816, 4000000);
            look(); pass(0.4);
            tryCompare(hub, "count", 1);
            compare([hub.transfers[0].headline, hub.transfers[0].processedBytes], ["wget - files.example.org", 4000000]);
            process(80, "wget", "wget|https://files.example.org/big.iso", 10, 34816, 9000000);
            pass(1); look();
            compare(text("transferAmount"), "Downloading · 8.6 MB / unknown");
            verify(/^\d[\d.]* [KM]B\/s/.test(text("transferPace")), text("transferPace"));
            Lang.setting = "tr";
            look();
            compare(text("transferAmount"), "İndiriliyor · 8,6 MB / bilinmiyor");
            Lang.setting = "en";
            look();
            gone(80);
            pass(1); look();
            // how a command ended cannot be seen from outside: neither a success nor a failure is claimed
            compare([root.log[1], titles(), activities.flashed[0].color === islandTheme.red, activities.flashed[0].color === islandTheme.live], ["end unknown 9000000 ", ["Finished"], false, false]);

            // a script's small request: nothing at all
            init();
            process(81, "curl", "curl|-s|https://api.example.org/v1/status", 10, 34816, 900);
            look(); pass(3); look();
            compare(hub.count, 0);
            gone(81); look(); pass(0.3);
            compare([root.log.length, titles()], [2, []]);
        }

        // A process that has ended and is not buried yet (a zombie), or one that ends while it is
        // looked at, has a name and no command line: there is nothing to read, and nothing breaks.
        function test_6b_a_process_without_a_command_line() {
            process(80, "wget", "", 10);
            process(81, "git", "", 10);
            process(82, "apt", "", 10);
            process(83, "python3", "", 10);
            look();
            look();
            compare([root.log, root.watcher.count], [[], 0]);
            // the watcher still works
            process(84, "wget", "wget|-q|https://files.example.org/big.iso", 10);
            look();
            compare(root.log, ["start wget download [] files.example.org "]);
        }

        function test_7_switched_off_nothing_is_looked_at() {
            provider.tools = false; provider.clones = false;
            tryVerify(() => root.watcher.commands.every(c => c.kind === "packages"));
            process(90, "wget", "wget|https://files.example.org/big.iso", 10, 34816, 9000000);
            process(91, "git", "git|clone|https://github.com/a/b", 10);
            look();
            compare(root.log, []);
            provider.removedCommands = "apt\napt-get";
            tryVerify(() => !root.watcher.commands.some(c => c.name === "apt"));
            process(92, "apt", "apt|update", 10);
            look();
            compare(root.log, []);
            gone(90); gone(91); gone(92);
            provider.enabled = false;
            tryCompare(root.watcher, "enabled", false);
            provider.removedCommands = ""; provider.tools = true; provider.clones = true; provider.addedCommands = "rsync\nnot a name!";
            provider.enabled = true;
            tryCompare(root.watcher, "enabled", true);
            compare(root.watcher.commands.length, Fmt.COMMANDS.length + 1);
            process(93, "rsync", "rsync|-a|host:/x|.", 10, 34816, 5000000);
            look();
            compare(root.log, ["start rsync download []  "]);
            provider.addedCommands = "";
        }
    }
}
