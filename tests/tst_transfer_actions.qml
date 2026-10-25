/* SPDX-License-Identifier: GPL-2.0-or-later
   Completion actions outlive their transfers, including time spent queued.
   Record external-open requests instead of launching a real file manager. */
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/providers"

Item {
    id: root
    width: 600
    height: 100
    property var opened: []
    property int destroyed: 0
    Theme { id: theme; follow: false }
    ActivityManager { id: manager; eventDuration: 10000; maxEventAge: 60000 }
    TransferHub {
        id: hub
        manager: manager
        theme: theme
        openExternal: url => { root.opened = root.opened.concat([String(url)]); return true; }
    }
    EventBanner {
        id: banner
        anchors.fill: parent
        theme: theme
        event: manager.currentEvent
        onActivated: manager.activateEvent()
        onDismissed: manager.closeEvent()
    }
    Component {
        id: transferComponent
        TransferActivity { Component.onDestruction: root.destroyed++ }
    }
    QtObject {
        id: core
        property bool downloadsEnabled: true
        signal downloadStarted(string id, string fileName, string application)
        signal downloadFinished(string id, string finalPath, string outcome, real bytes, string host)
    }
    QtObject {
        id: jobs
        property var jobs: []
        signal jobFinished(var info)
    }
    BrowserDownloadProvider { id: browser; hub: hub; jobs: jobs; core: core }
    CommandTransferProvider { id: commands; hub: hub; enabled: false; minSeconds: 0; minBytes: 0 }

    TestCase {
        name: "TransferActions"
        when: windowShown

        function initTestCase() { Lang.setting = "en"; manager.warm = true; wait(50); }
        function init() { root.opened = []; }
        function cleanup() {
            manager.queue = [];
            manager.dismissEvent();
            manager.holdEvents = false;
            jobs.jobs = [];
        }
        function clickAction(expected) {
            tryVerify(() => manager.currentEvent !== null);
            compare(manager.currentEvent.trailing.text, "Open folder");
            wait(400); // let the banner's appearance animation settle
            mouseClick(banner, banner.width - 65, banner.height / 2);
            compare(root.opened, [expected]);
            compare(manager.currentEvent, null);
        }
        function completion(url, folder) {
            const t = transferComponent.createObject(root, {
                transferId: "test", kind: "download", state: "done",
                openUrl: url, openIsFolder: folder
            });
            hub.finish(t);
            return t;
        }

        function test_click_after_transfer_destroyed() {
            const before = root.destroyed;
            const t = completion("file:///tmp/downloads", true);
            // The completion must retain the URL that was announced.
            t.openUrl = "file:///tmp/another-download";
            t.destroy(1000);
            tryCompare(root, "destroyed", before + 1, 3000);
            clickAction("file:///tmp/downloads");
        }
        function test_queued_completion_outlives_transfer() {
            manager.holdEvents = true;
            const before = root.destroyed;
            const t = completion("file:///tmp/queued", true);
            t.destroy(1000);
            tryCompare(root, "destroyed", before + 1, 3000);
            compare(manager.currentEvent, null);
            compare(manager.queue.length, 1);
            manager.holdEvents = false;
            clickAction("file:///tmp/queued");
        }
        function test_download_watcher_special_characters() {
            core.downloadStarted("watcher", "name.bin", "firefox");
            core.downloadFinished("watcher", "/tmp/İndirilenler # %20/name.bin", "done", 42, "");
            wait(1100); // BrowserDownloadProvider destroys the transfer after 1 s.
            clickAction("file:///tmp/%C4%B0ndirilenler%20%23%20%2520");
        }
        function test_browser_integration_uses_destination_url() {
            const info = {
                id: "job", app: "Firefox", destUrl: "file:///tmp/Downloads%20%23%25/name.bin",
                label1: "Source", value1: "https://example.org/name.bin",
                label2: "Destination", value2: "/tmp/stale %/name.bin",
                total: 42, processed: 42, percentage: 100, speed: 0,
                suspended: false, error: false, cancelled: false, errorText: ""
            };
            jobs.jobs = [info];
            tryCompare(hub, "count", 1);
            jobs.jobFinished(info);
            jobs.jobs = [];
            wait(1100);
            clickAction("file:///tmp/Downloads%20%23%25");
        }
        function test_command_download_folder() {
            commands.begin("c1", { kind: "download", source: "curl" });
            commands.end("c1", "done", 42, "/tmp/Belgeler çğş # %");
            wait(1100);
            clickAction("file:///tmp/Belgeler%20%C3%A7%C4%9F%C5%9F%20%23%20%25");
        }
        function test_without_target_has_no_action() {
            const t = completion("", true);
            tryVerify(() => manager.currentEvent !== null);
            compare(manager.currentEvent.trailing, null);
            compare(typeof manager.currentEvent.activate, "undefined");
            manager.activateEvent();
            compare(root.opened, []);
            t.destroy();
        }
        function test_file_open_keeps_its_label() {
            const t = completion("file:///tmp/name.bin", false);
            t.destroy();
            wait(50);
            tryVerify(() => manager.currentEvent !== null);
            compare(manager.currentEvent.trailing.text, "Open");
            manager.activateEvent();
            compare(root.opened, ["file:///tmp/name.bin"]);
        }
    }
}
