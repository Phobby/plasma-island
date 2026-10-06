/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The wheel on a real page of the expanded island, the Weather page: it
    turns the pages, but not over a list that has more than fits. The places
    a search found and a day's hours are such lists: a list lets the wheel
    through at its end, and turning the page there would close the search (or
    the day) in the middle of scrolling it. The rules themselves, on pages
    made for them: tests/tst_scroll.qml.

    The real ExpandedContent with the real Weather page beside a second page.
    The hours need the forecast of tests/fixtures, read with the native module
    (skipped when it is not built); nothing is asked of the network.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 520
    height: 240

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    PlasmaBackend { id: plasma }
    WeatherBackend {
        id: backend
        // the fixture is made up for a place three hours ahead of UTC (its figures began as an answer of Open-Meteo): 4 October 2026, 03:30 there
        clock: () => Date.UTC(2026, 9, 4, 0, 30)
        forecastBase: "http://127.0.0.1:1/none"
        searchBase: "http://127.0.0.1:1/none"
    }
    Component { id: weatherPage; WeatherPage { theme: islandTheme; weather: backend } }
    Component { id: otherPage; Item {} }

    ExpandedContent {
        id: expanded
        anchors.centerIn: parent
        width: islandTheme.expandedWidth - 2 * islandTheme.padding
        height: islandTheme.expandedHeight - 1.7 * islandTheme.padding
        theme: islandTheme
        backend: plasma
        manager: activities
        showMediaModule: false
        showSystemModule: false
        showNotificationModule: false
        pageOrder: "weather,other"
        extraPages: [
            { key: "weather", icon: "weather-clear", title: "Weather", component: weatherPage, visible: true },
            { key: "other", icon: "chronometer", title: "Other", component: otherPage, visible: true }
        ]
    }

    TestCase {
        name: "Wheel"
        when: windowShown

        function find(test) {
            let found = null;
            const walk = item => { if (found === null && test(item)) found = item; for (const c of item.children) walk(c); };
            walk(expanded);
            return found;
        }
        function page() { return find(item => typeof item.openSearch === "function"); }
        // the list that is shown now
        function list() { return find(item => typeof item.positionViewAtIndex === "function" && item.visible && item.count > 0); }
        // One notch of the wheel (down: -1, up: 1) at the middle of `item`, as a scroll of its own.
        function notch(item, direction) {
            const at = item.mapToItem(root, item.width / 2, item.height / 2);
            mouseWheel(root, at.x, at.y, 0, 120 * direction);
            wait(ScrollGesture.gestureGap + 100);
        }
        // Several in one scroll.
        function spin(item, direction, notches) {
            const at = item.mapToItem(root, item.width / 2, item.height / 2);
            for (let i = 0; i < notches; ++i) { mouseWheel(root, at.x, at.y, 0, 120 * direction); wait(40); }
            wait(ScrollGesture.gestureGap + 100);
        }
        // the pages slide (320 ms)
        function settle() { wait(450); }

        function initTestCase() {
            Lang.setting = "en";
            activities.warm = true;
            expanded.active = true;
            expanded.jumpTo("weather");
            tryVerify(() => page() !== null);
        }

        function test_1_the_wheel_turns_the_page() {
            const p = page();
            compare([expanded.currentKey, p.view], ["weather", "now"]);
            notch(p, -1);
            compare(expanded.currentKey, "other");
            settle();
            notch(expanded, 1);
            compare(expanded.currentKey, "weather");
            settle();
        }

        function test_2_not_while_a_place_is_searched() {
            const p = page();
            p.openSearch();
            const places = [];
            for (let i = 0; i < 8; ++i) places.push({ name: "Place " + i, admin: "Region", country: "Country", latitude: 38 + i, longitude: 27 });
            p.found = places;
            const l = list();
            verify(l !== null && l.count === 8);
            verify(l.contentHeight > l.height, "more places than fit: " + l.contentHeight + " in " + l.height);
            compare(l.atYBeginning, true);

            // down to the last place, and on: the list scrolls, the search stays
            spin(l, -1, 12);
            tryCompare(l, "atYEnd", true);
            verify(l.contentY > 0);
            compare([expanded.currentKey, p.view, p.found.length, p.typing], ["weather", "search", 8, true]);
            // a new scroll from the end
            notch(l, -1);
            compare([expanded.currentKey, p.view], ["weather", "search"]);
            // and back up, past the first one
            spin(l, 1, 12);
            tryCompare(l, "atYBeginning", true);
            notch(l, 1);
            compare([expanded.currentKey, p.view, p.found.length], ["weather", "search", 8]);

            // a place is chosen: the wheel turns the page again
            p.pick(p.found[7]);
            compare(p.view, "now");
            notch(p, -1);
            compare(expanded.currentKey, "other");
            settle();
            notch(expanded, 1);
            compare(expanded.currentKey, "weather");
            settle();
        }

        function test_3_not_while_a_days_hours_are_shown() {
            if (root.local === null) skip("the native module is not built: ./install.sh");
            const p = page();
            backend.location = JSON.stringify({ name: "Tëstwick", admin: "Tëstwick", country: "Exampleland", latitude: 12.34567, longitude: 45.67891 });
            backend.raw = root.local.readTextFile(root.here + "/fixtures/open-meteo-forecast.json", 200000);
            backend.retime();
            verify(backend.ready);
            p.shownDay = 1;
            wait(500);
            const l = list();
            verify(l !== null && l.count === 24);
            spin(l, -1, 20);
            tryCompare(l, "atYEnd", true);
            notch(l, -1);
            compare([expanded.currentKey, p.shownDay], ["weather", 1]);
            spin(l, 1, 20);
            tryCompare(l, "atYBeginning", true);
            notch(l, 1);
            compare([expanded.currentKey, p.shownDay], ["weather", 1]);
            // the tabs above the hours turn the page all the same
            const header = expanded.mapToItem(root, expanded.width / 2, 8);
            mouseWheel(root, header.x, header.y, 0, -120);
            compare(expanded.currentKey, "other");
            settle();
            expanded.jumpTo("weather");

            // back to the days: the wheel turns the page again
            p.shownDay = -1;
            wait(ScrollGesture.gestureGap + 100);
            notch(p, -1);
            compare(expanded.currentKey, "other");
            settle();
        }
    }
}
