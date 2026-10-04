/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Cloud page inside the real expanded island, with the real backend and
    the real `rclone` on a folder of this computer as its cloud (its own
    configuration, never the user's): the page without rclone, the folder
    list, going in and back, search and order, a sign-in that ran out with
    the command to renew it, a file's actions, and an upload with its
    question. Needs the native module and rclone (on the PATH, or
    tests/.run/rclone); skipped without them.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 470
    height: 400

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string run: here + "/.run/cloudpage-" + Math.floor(Math.random() * 1e9).toString(36)
    readonly property Component streamMaker: Qt.createComponent("../org.phobby.dynamicisland/contents/ui/StreamBridge.qml")
    QtObject {
        id: nativeCore
        readonly property var local: root.local
        property bool secretsAvailable: false
        function newStream(owner) { return root.streamMaker.status === Component.Ready ? root.streamMaker.createObject(owner) : null; }
        function call() {}
    }
    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    PlasmaBackend { id: plasma }
    TransferHub { id: transferHub; manager: activities; theme: islandTheme }
    CloudBackend {
        id: backend
        core: nativeCore
        hub: transferHub
        enabled: true
        extra: ["--config", root.run + "/rclone.conf"]
        downloadsFolder: root.run + "/Downloads"
        cacheFolder: root.run + "/cache"
        commandName: "no-such-rclone-xyz"
    }
    Component { id: cloudPage; CloudPage { theme: islandTheme; cloud: backend } }
    Component { id: otherPage; Item {} }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: islandTheme.expandedWidth
        height: expanded.tall ? islandTheme.tallHeight : islandTheme.expandedHeight
        radius: 28
        color: islandTheme.surface
        ExpandedContent {
            id: expanded
            anchors.fill: parent
            anchors.margins: islandTheme.padding
            anchors.topMargin: islandTheme.padding * 0.7
            theme: islandTheme
            backend: plasma
            manager: activities
            showMediaModule: false
            showSystemModule: false
            showNotificationModule: false
            pageOrder: "cloud,other"
            extraPages: [
                { key: "cloud", icon: "folder-cloud", title: "Cloud", component: cloudPage, visible: true },
                { key: "other", icon: "chronometer", title: "Other", component: otherPage, visible: true }
            ]
        }
    }

    TestCase {
        name: "CloudPage"
        when: windowShown

        property string rclone: ""
        function find(test) {
            let found = null;
            const walk = item => { if (found === null && test(item)) found = item; for (const c of item.children) walk(c); };
            walk(expanded);
            return found;
        }
        function named(name) { return find(item => item.objectName === name); }
        function page() { return find(item => typeof item.dropped === "function" && typeof item.askFolder === "function"); }
        function shown(...texts) {
            for (const text of texts)
                tryVerify(() => find(item => item.visible === true && typeof item.text === "string" && item.text.indexOf(text) >= 0 && item.width > 0) !== null, 5000, "shown: " + text);
        }
        function click(item) { mouseClick(item, item.width / 2, item.height / 2); }
        function open() {
            expanded.active = true;
            expanded.jumpTo("cloud");
            tryVerify(() => page() !== null);
            return page();
        }
        function close() { expanded.active = false; tryVerify(() => page() === null); }
        function names() { const l = named("entries"); const out = []; for (let i = 0; i < l.count; ++i) out.push(l.model[i].name); return out; }
        function sh(program, args) { let out = null; root.local.run(program, args, (code, text) => out = { code: code, out: text }); tryVerify(() => out !== null, 20000); return out; }

        function initTestCase() {
            if (root.local === null) skip("the native module is not built: ./install.sh");
            Lang.setting = "en";
            activities.warm = true;
            rclone = root.local.fileSize(root.here + "/.run/rclone") > 0 ? root.here + "/.run/rclone" : root.local.findExecutable("rclone");
            if (rclone.length === 0) skip("rclone is not installed (and there is no tests/.run/rclone)");
            for (const n of ["b10.txt", "b2.txt", "<b>bold<b> &amp; [link](x).md", "Zeta.pdf"]) root.local.writeTextFile(root.run + "/data/" + n, n);
            root.local.writeTextFile(root.run + "/data/Belgeler çğş/inner.txt", "inner");
            sh("mkdir", ["-p", root.run + "/Downloads", root.run + "/data/empty"]);
            compare(sh(rclone, ["--config", root.run + "/rclone.conf", "config", "create", "box", "alias", "remote=" + root.run + "/data"]).code, 0);
        }
        function cleanup() { if (expanded.active) close(); }

        function test_1_without_rclone_the_command_to_get_it() {
            const p = open();
            tryCompare(p, "view", "missing");
            compare([p.tall, backend.clouds.length], [false, 0]);
            shown("rclone was not found", "sudo -v ; curl https://rclone.org/install.sh | sudo bash");
            // it is installed meanwhile, but knows no cloud yet
            backend.commandName = rclone;
            backend.extra = ["--config", root.run + "/none.conf"];
            let done = false;
            backend.detect(() => done = true);
            tryVerify(() => done, 20000);
            p.settle();
            compare(p.view, "empty");
            shown("No cloud is set up yet", "rclone config");
            backend.extra = ["--config", root.run + "/rclone.conf"];
            done = false;
            backend.detect(() => done = true);
            tryVerify(() => done, 20000);
            tryCompare(p, "view", "browse");
        }

        function test_2_the_folder_names_only() {
            const p = open();
            tryVerify(() => named("entries").count === 6, 20000);
            compare([p.current, p.path, p.tall, expanded.tall, p.keepsWheel], ["box", "", true, true, true]);
            compare(names(), ["Belgeler çğş", "empty", "<b>bold<b> &amp; [link](x).md", "b2.txt", "b10.txt", "Zeta.pdf"], "folders first, then by name");
            shown("<b>bold<b> &amp; [link](x).md", "Sync state unknown · why: Settings → Cloud");
            verify(find(item => item.textFormat !== undefined && item.textFormat !== Text.PlainText && String(item.text).indexOf("<b>") >= 0) === null, "a name is never read as markup");
            // the order, and the search in this folder
            click(named("order"));
            compare([p.order, p.descending, names().slice(0, 3)], ["name", true, ["empty", "Belgeler çğş", "Zeta.pdf"]]);
            click(named("order"));
            compare([p.order, p.descending], ["date", true]);
            click(named("order")); click(named("order"));
            compare([p.order, p.descending], ["size", true]);
            p.order = "name"; p.descending = false;
            p.query = "B1";
            compare(names(), ["b10.txt"]);
            p.query = "";
            // into a folder and back by the path on top
            p.choose(p.shown[0]);
            tryVerify(() => named("entries").count === 1 && p.path === "Belgeler çğş", 20000);
            compare(names(), ["inner.txt"]);
            p.up(1);
            tryVerify(() => named("entries").count === 6);
            p.choose(p.shown[1]);
            shown("This folder is empty");
            p.up(1);
            tryVerify(() => named("entries").count === 6);
            // how full: said where the cloud says it
            backend.refreshStorage();
            tryVerify(() => named("storageText").visible, 20000);
        }

        function test_3_a_file_download_and_fetch() {
            const p = open();
            tryVerify(() => named("entries").count === 6, 20000);
            const entry = p.shown.find(e => e.name === "b2.txt");
            p.choose(entry);
            compare([p.view, named("fileShow").visible, named("fileFetch").visible], ["file", false, true]);
            click(named("fileDownload"));
            tryVerify(() => p.saved.length > 0, 20000);
            compare([p.saved, root.local.readTextFile(p.saved), named("fileShow").visible, named("fileCopyPath").visible], [root.run + "/Downloads/b2.txt", "b2.txt", true, true]);
            // fetched into the cache: now it can be dragged from the list
            click(named("fileFetch"));
            tryVerify(() => backend.readyPath("box", "b2.txt", entry).length > 0, 20000);
            compare(root.local.readTextFile(backend.readyPath("box", "b2.txt", entry)), "b2.txt");
            p.view = "browse";
            shown("drag");
            // the pointer resting on a small file fetches it quietly; a large one waits to be asked
            p.rest(p.shown.find(e => e.name === "b10.txt"));
            tryVerify(() => backend.readyPath("box", "b10.txt", p.shown.find(e => e.name === "b10.txt")).length > 0, 20000);
            backend.autoFetchMB = 0;
            p.rest(p.shown.find(e => e.name === "Zeta.pdf"));
            wait(400);
            compare(backend.readyPath("box", "Zeta.pdf", p.shown.find(e => e.name === "Zeta.pdf")), "");
            backend.autoFetchMB = 25;
            // a folder is measured first
            p.askFolder(p.shown[0]);
            compare(p.view, "folder");
            shown("5 B in 1 file. Download the whole folder to the Downloads folder?");
            click(named("folderDownload"));
            tryVerify(() => root.local.readTextFile(root.run + "/Downloads/Belgeler çğş/inner.txt") === "inner", 20000);
        }

        function test_4_dropped_files_are_asked_about_then_copied() {
            const p = open();
            tryVerify(() => named("entries").count === 6, 20000);
            root.local.writeTextFile(root.run + "/drop/new file.txt", "new");
            root.local.writeTextFile(root.run + "/drop/b2.txt", "another b2");
            const url = n => "file://" + (root.run + "/drop/" + n).split("/").map(encodeURIComponent).join("/");
            p.dropped([url("new file.txt")]);
            tryCompare(p, "view", "upload", 20000);
            shown("1 item, 3 B → box. Upload?", "nothing on this computer is changed");
            compare([named("uploadGo").visible, named("uploadOver").visible, p.holdOpen], [true, false, true]);
            click(named("uploadGo"));
            tryVerify(() => p.view === "browse" && named("entries").count === 7, 20000);
            compare(root.local.readTextFile(root.run + "/data/new file.txt"), "new");
            // one that is there already: three answers, none of them silent
            p.dropped([url("b2.txt")]);
            tryCompare(p, "view", "upload", 20000);
            shown("1 of them is there already: b2.txt");
            compare([named("uploadGo").visible, named("uploadBoth").visible, named("uploadSkip").visible, named("uploadOver").visible], [false, true, true, true]);
            click(named("uploadBoth"));
            tryVerify(() => p.view === "browse" && named("entries").count === 8, 20000, "view " + p.view + ", names " + names().join("|"));
            compare([root.local.readTextFile(root.run + "/data/b2.txt"), root.local.readTextFile(root.run + "/data/b2 (1).txt"), root.local.readTextFile(root.run + "/drop/b2.txt")],
                    ["b2.txt", "another b2", "another b2"]);
            // not a file of this computer: nothing is asked of the cloud
            p.dropped(["https://example.org/file.txt"]);
            shown("Only files of this computer can be uploaded.");
            compare(p.view, "browse");
        }

        function test_5_the_cloud_is_gone_or_its_sign_in_ran_out() {
            const p = open();
            tryVerify(() => named("entries").count > 0, 20000);
            p.trouble = { kind: "auth", detail: "" };
            shown("The sign-in of box has run out. Connect it again in your own terminal:", "rclone config reconnect box:");
            compare(named("drop").enabled, false, "nothing is uploaded to a cloud that does not answer");
            p.open("box", "nowhere", true);
            tryVerify(() => p.trouble !== null && p.trouble.kind === "notfound", 20000);
            shown("This folder is not there any more.");
        }
    }
}
