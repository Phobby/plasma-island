/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Cloud tab on the small island (providers/CloudActivityProvider.qml on
    the real ActivityManager, with a stand-in for the backend): a cloud while
    something syncs, below every other activity, with its colours; "Synced";
    alerts as events that open the tab and go away when their cause does;
    nothing when the indicator is off. And the small island opening the tab
    when files are dragged onto it.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/providers"

Item {
    id: root
    width: 760
    height: 300

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    PlasmaBackend { id: plasma }
    QtObject {
        id: backend
        property bool indicator: true
        property bool syncing: false
        property real syncProgress: -1
        property bool syncError: false
        property bool storageWarning: false
        signal synced(string name)
        signal alert(string id, string kind, string title, string text)
        signal alertEnded(string id, string kind)
    }
    property string opened: "-"
    CloudActivityProvider { id: onTheIsland; manager: activities; theme: islandTheme; cloud: backend; onOpened: id => root.opened = id }
    Activity { id: stopwatch; activityId: "stopwatch"; category: "timer"; icon: "chronometer"; title: "Stopwatch"; Component.onCompleted: activities.register(this) }
    Component { id: otherPage; Item {} }
    Island {
        id: island
        anchors.fill: parent
        theme: islandTheme
        backend: plasma
        manager: activities
        showMediaModule: false
        showSystemModule: false
        showNotificationModule: false
        pageOrder: "cloud,other"
        extraPages: [{ key: "cloud", icon: "folder-cloud", title: "Cloud", component: otherPage, visible: true }, { key: "other", icon: "chronometer", title: "Other", component: otherPage, visible: true }]
    }

    TestCase {
        name: "CloudIsland"
        when: windowShown

        function find(test) { let found = null; const walk = item => { if (found === null && test(item)) found = item; for (const c of item.children) walk(c); }; walk(island); return found; }
        function initTestCase() { Lang.setting = "en"; activities.warm = true; }
        function cleanup() { backend.syncing = false; backend.indicator = true; stopwatch.active = false; activities.queue = []; if (activities.currentEvent) activities.dismissEvent(); island.expanded = false; wait(50); }

        function test_1_a_cloud_while_something_syncs() {
            compare(activities.liveCount, 0);
            backend.syncing = true; backend.syncProgress = 0.4;
            tryCompare(activities, "liveCount", 1);
            const a = activities.primary;
            compare([a.activityId, a.title, a.progress, Qt.colorEqual(a.color, islandTheme.blue), island.mode], ["cloud-sync", "Syncing", 0.4, true, "live"]);
            backend.syncProgress = -1;
            compare(a.progress, -2, "no percentage known: it only turns");
            backend.storageWarning = true;
            verify(Qt.colorEqual(a.color, islandTheme.orange));
            backend.syncError = true;
            verify(Qt.colorEqual(a.color, islandTheme.red));
            backend.syncError = false; backend.storageWarning = false;
            // whatever else is going on comes first; the split island is as it was
            stopwatch.active = true;
            tryCompare(activities, "liveCount", 2);
            compare([activities.primary.activityId, activities.secondary.activityId, island.mode], ["stopwatch", "cloud-sync", "split"]);
            stopwatch.active = false;
            // done: a short "Synced", then nothing
            backend.syncing = false;
            backend.synced("Dropbox");
            tryCompare(activities, "liveCount", 0);
            tryVerify(() => activities.currentEvent !== null, 3000);
            compare([activities.currentEvent.title, activities.currentEvent.subtitle], ["Synced", "Dropbox"]);
            activities.dismissEvent();
            // the indicator switched off: neither
            backend.indicator = false;
            backend.syncing = true;
            wait(200);
            compare(activities.liveCount, 0);
            backend.synced("Dropbox");
            wait(300);
            compare([activities.currentEvent, activities.queue.length], [null, 0]);
        }

        function test_2_alerts_open_the_tab_and_end_with_their_cause() {
            backend.alert("drive", "storage", "Drive is nearly full", "91% of 15 GB used");
            tryVerify(() => activities.currentEvent !== null, 3000);
            compare([activities.currentEvent.title, activities.currentEvent.subtitle, activities.currentEvent.trailing.text, Qt.colorEqual(activities.currentEvent.color, islandTheme.orange)],
                    ["Drive is nearly full", "91% of 15 GB used", "Open", true]);
            activities.activateEvent();
            compare(root.opened, "drive");
            // one that is still on the island goes when its cause does
            backend.alert("drive", "auth", "Drive: sign-in has run out", "");
            tryVerify(() => activities.currentEvent !== null && activities.currentEvent.title.indexOf("sign-in") > 0, 3000);
            verify(Qt.colorEqual(activities.currentEvent.color, islandTheme.red));
            backend.alertEnded("drive", "auth");
            compare(activities.currentEvent, null);
            // the tab is off: nothing of it on the island
            onTheIsland.enabled = false;
            backend.alert("drive", "full", "Drive is full", "");
            wait(300);
            compare([activities.currentEvent, activities.queue.length], [null, 0]);
            onTheIsland.enabled = true;
        }

        function test_3_the_small_island_takes_no_drop_unless_the_tab_is_on() {
            const drop = find(item => item.objectName === "islandDrop");
            verify(drop !== null);
            compare([island.dropPage, drop.enabled], ["", false]);
            island.dropPage = "cloud";
            compare(drop.enabled, true);
            // files dragged onto it: the island opens on the tab (the page under the pointer takes the drop)
            island.filesOver();
            compare(island.expanded, true);
            tryVerify(() => find(item => item.objectName === "expandedContent").currentKey === "cloud");
            compare(drop.enabled, false, "once open, the page has the drop");
            island.dropPage = "";
        }
    }
}
