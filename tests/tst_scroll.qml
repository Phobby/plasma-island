/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Who a scroll belongs to (ScrollGesture, IslandScroll): what has more than
    fits keeps the wheel, at its end too, and what has nothing to scroll lets
    it turn the island's pages. The real ExpandedContent, with pages made for
    this: a long list beside empty room, a short one, a row that goes
    sideways, a list inside a list, a text and a slider.

    A mouse's wheel is QtTest's mouseWheel(); a touchpad's steps (pixels, the
    phases of a scroll, what comes after the fingers are lifted) are sent by
    tests/helper, which tools/run-tests builds: without it those are skipped.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 520
    height: 260

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    PlasmaBackend { id: plasma }

    property var sender: null
    Component.onCompleted: {
        try { sender = Qt.createQmlObject("import IslandTest; WheelSender {}", root); } catch (e) { sender = null; }
    }

    // The pages of this test, in their order. They go by keys the island knows
    // (only those can be put in an order): `shown` is the test's name for the one that is shown.
    readonly property var order: ["weather", "quicksettings", "apps", "tools", "habits", "calendar", "notes"]
    readonly property var names: ["first", "long", "short", "row", "nested", "widgets", "last"]
    readonly property string shown: names[order.indexOf(expanded.currentKey)] ?? ""

    property int longRows: 40
    property int rowChips: 30
    property real level: 0.5

    Component { id: emptyPage; Item { objectName: "emptyPage" } }
    Component {
        id: longPage
        Item {
            IslandListView {
                objectName: "longList"
                width: parent.width * 0.6
                height: parent.height
                model: root.longRows
                delegate: Rectangle { required property int index; width: ListView.view.width; height: 24; color: index % 2 ? "#333" : "#444" }
            }
            // beside the list: nothing that scrolls
            Item { objectName: "beside"; x: parent.width * 0.6; width: parent.width * 0.4; height: parent.height }
        }
    }
    Component {
        id: shortPage
        IslandListView {
            objectName: "shortList"
            model: 2
            delegate: Rectangle { required property int index; width: ListView.view.width; height: 24; color: "#345" }
        }
    }
    Component {
        id: rowPage
        Item {
            IslandFlickable {
                objectName: "chips"
                width: parent.width
                height: 24
                contentWidth: chips.implicitWidth
                Row {
                    id: chips
                    spacing: 4
                    Repeater { model: root.rowChips; Rectangle { width: 50; height: 24; color: "#543" } }
                }
            }
            IslandGridView {
                objectName: "grid"
                y: 30
                width: parent.width
                height: parent.height - 30
                cellWidth: width / 2
                cellHeight: 24
                model: 40
                delegate: Rectangle { width: GridView.view.cellWidth; height: 24; color: "#354" }
            }
        }
    }
    Component {
        id: nestedPage
        IslandFlickable {
            id: outer
            objectName: "outer"
            contentHeight: 600
            IslandListView {
                objectName: "inner"
                y: 10
                width: outer.width
                height: 80
                model: 30
                delegate: Rectangle { required property int index; width: ListView.view.width; height: 24; color: index % 2 ? "#633" : "#644" }
            }
        }
    }
    Component {
        id: widgetsPage
        Item {
            GlassSlider {
                objectName: "slider"
                width: parent.width
                value: root.level
                onMoved: value => root.level = value
            }
            IslandFlickable {
                id: textView
                objectName: "textView"
                y: 30
                width: parent.width
                height: parent.height - 30
                contentHeight: text.implicitHeight
                TextEdit {
                    id: text
                    objectName: "text"
                    width: textView.width
                    wrapMode: TextEdit.Wrap
                    color: "white"
                    text: "one line"
                }
            }
        }
    }

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
        pageOrder: root.order.join(",")
        extraPages: [
            { key: root.order[0], icon: "go-first", title: "First", component: emptyPage, visible: true },
            { key: root.order[1], icon: "view-list-details", title: "Long", component: longPage, visible: true },
            { key: root.order[2], icon: "view-list-text", title: "Short", component: shortPage, visible: true },
            { key: root.order[3], icon: "view-list-icons", title: "Row", component: rowPage, visible: true },
            { key: root.order[4], icon: "view-list-tree", title: "Nested", component: nestedPage, visible: true },
            { key: root.order[5], icon: "configure", title: "Widgets", component: widgetsPage, visible: true },
            { key: root.order[6], icon: "go-last", title: "Last", component: emptyPage, visible: true }
        ]
    }

    TestCase {
        name: "Scroll"
        when: windowShown

        readonly property int gap: ScrollGesture.gestureGap

        function find(name) {
            let found = null;
            const walk = item => {
                if (found !== null) return;
                if (item.objectName === name && item.visible) {
                    // of the page that is shown
                    let shown = true;
                    for (let p = item; p !== null && p !== expanded; p = p.parent) if (!p.visible) shown = false;
                    if (shown) { found = item; return; }
                }
                for (const c of item.children) walk(c);
                if (item.contentItem && typeof item.flick === "function") for (const c of item.contentItem.children) walk(c);
            };
            walk(expanded);
            return found;
        }
        // The gesture that runs is over, and the pages have stopped sliding.
        function rest() { wait(Math.max(gap, ScrollGesture.tabCooldown) + 120); }
        function show(key) {
            rest();
            expanded.jumpTo(root.order[root.names.indexOf(key)]);
            compare(root.shown, key);
            wait(60);
        }
        // A mouse's wheel at the middle of `item`: notches (down: negative), or eighths of a degree.
        function notch(item, notches, sideways) {
            const at = item.mapToItem(root, item.width / 2, item.height / 2);
            mouseWheel(root, at.x, at.y, sideways ? 120 * notches : 0, sideways ? 0 : 120 * notches);
        }
        function angle(item, dy) {
            const at = item.mapToItem(root, item.width / 2, item.height / 2);
            mouseWheel(root, at.x, at.y, 0, dy);
        }
        // A touchpad's step. A scroll of two fingers is a ScrollBegin, updates and a ScrollEnd
        // (the Flickable needs the first; a WheelHandler at rest is not shown it).
        function pixels(item, dx, dy, phase) {
            root.sender.send(item, item.width / 2, item.height / 2, dx, dy, dx * 12, dy * 12, phase === undefined ? Qt.ScrollUpdate : phase);
        }
        function needTouchpad() { if (root.sender === null) skip("tests/helper is not built: tools/run-tests builds it"); }
        // Scrolls `list` to its end (direction -1) or its beginning (1) in one gesture.
        function toEdge(list, direction, touchpad) {
            const there = () => direction < 0 ? list.atYEnd : list.atYBeginning;
            if (touchpad) pixels(list, 0, 0, Qt.ScrollBegin);
            for (let i = 0; i < 400 && !there(); ++i) {
                if (touchpad) pixels(list, 0, 9 * direction); else notch(list, direction);
                wait(15);
            }
            tryVerify(there, 2000, "the list reaches its edge");
        }

        function initTestCase() {
            Lang.setting = "en";
            activities.warm = true;
            expanded.active = true;
            expanded.jumpTo(root.order[1]);
            tryVerify(() => find("longList") !== null);
        }
        function init() { root.longRows = 40; root.rowChips = 30; }

        // ---- a list with more than fits keeps the wheel ----------------------------------
        function test_01_at_the_end_the_wheel_stays_with_the_list() {
            show("long");
            const list = find("longList");
            verify(list.contentHeight > list.height);
            list.contentY = 0;
            toEdge(list, -1, false);
            for (let i = 0; i < 10; ++i) { notch(list, -1); wait(15); }
            compare(root.shown, "long");
            // and a new scroll from the end, after a rest, is the list's too
            rest();
            for (let i = 0; i < 3; ++i) { notch(list, -1); wait(15); }
            rest();
            compare([root.shown, list.atYEnd], ["long", true]);
        }
        function test_02_at_the_beginning_too() {
            show("long");
            const list = find("longList");
            list.contentY = 0;
            for (let i = 0; i < 10; ++i) { notch(list, 1); wait(15); }
            rest();
            notch(list, 1);
            rest();
            compare([root.shown, list.atYBeginning], ["long", true]);
            // from the end back up to the beginning and past it, in one go
            toEdge(list, -1, false);
            toEdge(list, 1, false);
            for (let i = 0; i < 10; ++i) { notch(list, 1); wait(15); }
            compare(root.shown, "long");
        }
        function test_03_a_touchpad_at_the_end_and_what_comes_after_the_fingers() {
            needTouchpad();
            show("long");
            const list = find("longList");
            list.contentY = 0;
            toEdge(list, -1, true);
            for (let i = 0; i < 10; ++i) { pixels(list, 0, -9); wait(10); }
            pixels(list, 0, 0, Qt.ScrollEnd);
            // the fingers are up: what the scroll still had in it
            for (let i = 0; i < 20; ++i) { pixels(list, 0, -6, Qt.ScrollMomentum); wait(10); }
            compare(root.shown, "long");
            // a second swipe at the end, which says where it begins
            rest();
            pixels(list, 0, 0, Qt.ScrollBegin);
            for (let i = 0; i < 10; ++i) { pixels(list, 0, -9); wait(10); }
            pixels(list, 0, 0, Qt.ScrollEnd);
            // momentum that arrives after the gesture is forgotten begins nothing
            rest();
            for (let i = 0; i < 20; ++i) { pixels(list, 0, -9, Qt.ScrollMomentum); wait(10); }
            compare([root.shown, list.atYEnd], ["long", true]);
            // and up again
            toEdge(list, 1, true);
            for (let i = 0; i < 10; ++i) { pixels(list, 0, 9); wait(10); }
            compare(root.shown, "long");
        }
        // In the middle of a list a touchpad's first step and its last are not taken by the
        // Flickable: they are the list's all the same.
        function test_04_a_touchpad_in_the_middle_of_a_list() {
            needTouchpad();
            show("long");
            const list = find("longList");
            list.contentY = 200;
            for (let swipe = 0; swipe < 6; ++swipe) {
                pixels(list, 0, 0, Qt.ScrollBegin);
                for (let i = 0; i < 4; ++i) { pixels(list, 0, swipe % 2 ? 9 : -9); wait(10); }
                pixels(list, 0, 0, Qt.ScrollEnd);
                rest();
            }
            compare(root.shown, "long");
        }

        // ---- nothing to scroll: the pages are turned -------------------------------------
        function test_05_a_short_list_and_empty_room_turn_the_page() {
            show("short");
            const list = find("shortList");
            verify(list.contentHeight <= list.height);
            notch(list, -1);
            compare(root.shown, "row");
            show("long");
            notch(find("beside"), -1);
            compare(root.shown, "short");
            show("long");
            notch(find("beside"), 1);
            compare(root.shown, "first");
            // an empty page
            rest();
            notch(expanded, -1);
            compare(root.shown, "long");
        }
        function test_06_the_tabs_always_turn_the_page() {
            show("long");
            const list = find("longList");
            list.contentY = 100;
            // over the header (the tabs), though the page has a list
            const header = expanded.mapToItem(root, expanded.width / 2, 8);
            mouseWheel(root, header.x, header.y, 0, -120);
            compare(root.shown, "short");
            compare(list.contentY, 100);
            // and in the island's margin around its content
            show("long");
            const margin = expanded.mapToItem(root, expanded.width / 2, expanded.height + islandTheme.padding / 2);
            mouseWheel(root, margin.x, margin.y, 0, 120);
            compare(root.shown, "first");
        }
        function test_07_follows_the_content_as_it_shrinks_and_grows() {
            show("long");
            const list = find("longList");
            root.longRows = 2;
            tryVerify(() => list.contentHeight <= list.height);
            notch(list, -1);
            compare(root.shown, "short");
            show("long");
            root.longRows = 40;
            tryVerify(() => list.contentHeight > list.height);
            list.contentY = 0;
            for (let i = 0; i < 5; ++i) { notch(list, 1); wait(15); }
            compare(root.shown, "long");
        }

        // ---- one gesture, one owner -------------------------------------------------------
        function test_08_a_gesture_stays_with_the_list_it_began_over() {
            show("long");
            const list = find("longList");
            toEdge(list, -1, false);
            // 20 steps at the end, 15 ms apart
            for (let i = 0; i < 20; ++i) { notch(list, -1); wait(15); }
            compare([root.shown, ScrollGesture.owner], ["long", list]);
            // the pointer leaves the list while the wheel still turns: still the list's scroll
            const beside = find("beside");
            for (let i = 0; i < 5; ++i) { notch(beside, -1); wait(15); }
            compare(root.shown, "long");
            // a long silence: the gesture is over
            rest();
            compare(ScrollGesture.owner, null);
            // a new one at the end of the list is the list's again
            notch(list, -1);
            compare([root.shown, ScrollGesture.owner], ["long", list]);
            // and a new one beside it turns the page
            rest();
            notch(beside, -1);
            compare(root.shown, "short");
        }
        function test_09_one_gesture_turns_one_page() {
            show("first");
            for (let i = 0; i < 10; ++i) { notch(expanded, -1); wait(15); }
            compare(root.shown, "long");
            // what is left of it does not scroll the list of the page arrived at
            wait(60);
            const list = find("longList");
            list.contentY = 0;
            for (let i = 0; i < 5; ++i) { notch(list, -1); wait(15); }
            wait(150);
            compare([root.shown, list.contentY], ["long", 0]);
            // after a rest a new gesture turns one page again
            rest();
            for (let i = 0; i < 10; ++i) { notch(find("beside"), -1); wait(15); }
            compare(root.shown, "short");
        }
        function test_10_a_touchpad_swipe_turns_one_page() {
            needTouchpad();
            show("first");
            pixels(expanded, 0, 0, Qt.ScrollBegin);
            for (let i = 0; i < 30; ++i) { pixels(expanded, 0, -9); wait(8); }
            pixels(expanded, 0, 0, Qt.ScrollEnd);
            for (let i = 0; i < 20; ++i) { pixels(expanded, 0, -9, Qt.ScrollMomentum); wait(8); }
            compare(root.shown, "long");
            // Two swipes with no rest between them, each saying where it begins: two gestures,
            // but the second turns nothing before the pause is over
            show("first");
            pixels(expanded, 0, 0, Qt.ScrollBegin);
            for (let i = 0; i < 6; ++i) pixels(expanded, 0, -9);
            compare(root.shown, "long");
            const before = ScrollGesture.serial;
            wait(30);
            pixels(expanded, 0, 0, Qt.ScrollBegin);
            for (let i = 0; i < 6; ++i) pixels(expanded, 0, -9);
            compare([root.shown, ScrollGesture.serial], ["long", before + 1]);
            // it goes on: once the pause is over it turns the page, once
            for (let i = 0; i < (ScrollGesture.tabCooldown + 200) / 20; ++i) { pixels(expanded, 0, -9); wait(20); }
            compare([root.shown, ScrollGesture.serial], ["short", before + 1]);
            // sideways as well
            show("first");
            for (let i = 0; i < 10; ++i) { pixels(expanded, -9, 0); wait(8); }
            compare(root.shown, "long");
        }
        function test_11_less_than_a_notch_turns_nothing() {
            show("first");
            // three quarters of a notch
            for (let i = 0; i < 3; ++i) { angle(expanded, -30); wait(15); }
            compare(root.shown, "first");
            // it is forgotten with its gesture
            rest();
            for (let i = 0; i < 3; ++i) { angle(expanded, -30); wait(15); }
            compare(root.shown, "first");
            // the fourth makes the notch
            angle(expanded, -30);
            compare(root.shown, "long");
        }
        function test_12_fingers_resting_on_a_touchpad_turn_nothing() {
            needTouchpad();
            show("first");
            for (let i = 0; i < 12; ++i) { pixels(expanded, 0, i % 2 ? -2 : -1); wait(10); }
            compare(root.shown, "first");
            rest();
            for (let i = 0; i < 12; ++i) { pixels(expanded, 0, -2); wait(10); }
            compare(root.shown, "first");
            for (let i = 0; i < 12; ++i) { pixels(expanded, 0, -2); wait(10); }
            compare(root.shown, "long");
        }

        // ---- directions -------------------------------------------------------------------
        function test_13_a_row_takes_the_wheel_and_goes_sideways() {
            show("row");
            const row = find("chips");
            verify(row.contentWidth > row.width);
            compare(row.contentX, 0);
            // a mouse's wheel moves it, to its end and no further
            for (let i = 0; i < 60; ++i) { notch(row, -1); wait(10); }
            compare([root.shown, row.atXEnd], ["row", true]);
            rest();
            for (let i = 0; i < 60; ++i) { notch(row, 1); wait(10); }
            compare([root.shown, row.atXBeginning], ["row", true]);
            // a wheel that goes sideways
            rest();
            for (let i = 0; i < 5; ++i) { notch(row, -1, true); wait(15); }
            rest();
            verify(row.contentX > 0);
            compare(root.shown, "row");
            // a row that fits takes nothing
            root.rowChips = 2;
            tryVerify(() => row.contentWidth <= row.width);
            rest();
            notch(row, -1);
            compare(root.shown, "nested");
        }
        function test_14_a_sideways_swipe_over_a_list_turns_the_page() {
            show("row");
            const grid = find("grid");
            verify(grid.contentHeight > grid.height);
            // (the grid keeps the wheel as a list does)
            for (let i = 0; i < 5; ++i) { notch(grid, 1); wait(15); }
            compare(root.shown, "row");
            rest();
            notch(grid, -1, true);
            compare(root.shown, "nested");
        }
        function test_15_a_touchpad_over_a_row() {
            needTouchpad();
            show("row");
            const row = find("chips");
            row.contentX = 0;
            pixels(row, 0, 0, Qt.ScrollBegin);
            for (let i = 0; i < 20; ++i) { pixels(row, -9, 0); wait(10); }
            pixels(row, 0, 0, Qt.ScrollEnd);
            verify(row.contentX > 0);
            compare(root.shown, "row");
            rest();
            const x = row.contentX;
            pixels(row, 0, 0, Qt.ScrollBegin);
            for (let i = 0; i < 10; ++i) { pixels(row, 0, -9); wait(10); }
            verify(row.contentX > x, "up and down moves the row too");
            compare(root.shown, "row");
        }

        // ---- inside one another -----------------------------------------------------------
        function test_16_the_inner_list_keeps_its_scroll_from_the_outer_one() {
            show("nested");
            const outer = find("outer"), inner = find("inner");
            outer.contentY = 0;
            inner.contentY = 0;
            toEdge(inner, -1, false);
            for (let i = 0; i < 10; ++i) { notch(inner, -1); wait(15); }
            wait(200);
            compare([root.shown, outer.contentY], ["nested", 0]);
            // a new scroll from the inner one's end: still its own
            rest();
            for (let i = 0; i < 5; ++i) { notch(inner, -1); wait(15); }
            wait(200);
            compare([root.shown, outer.contentY], ["nested", 0]);
            // beside the inner one the outer one scrolls, and keeps the wheel at its end
            rest();
            const at = outer.mapToItem(root, outer.width / 2, outer.height - 10);
            for (let i = 0; i < 80 && !outer.atYEnd; ++i) { mouseWheel(root, at.x, at.y, 0, -120); wait(15); }
            tryCompare(outer, "atYEnd", true);
            for (let i = 0; i < 10; ++i) { mouseWheel(root, at.x, at.y, 0, -120); wait(15); }
            compare(root.shown, "nested");
        }
        function test_17_the_inner_list_with_a_touchpad() {
            needTouchpad();
            show("nested");
            const outer = find("outer"), inner = find("inner");
            outer.contentY = 0;
            inner.contentY = 0;
            toEdge(inner, -1, true);
            for (let i = 0; i < 10; ++i) { pixels(inner, 0, -9); wait(10); }
            pixels(inner, 0, 0, Qt.ScrollEnd);
            for (let i = 0; i < 10; ++i) { pixels(inner, 0, -9, Qt.ScrollMomentum); wait(10); }
            wait(200);
            compare([root.shown, outer.contentY], ["nested", 0]);
        }

        // ---- a text, a slider -------------------------------------------------------------
        function test_18_a_text_keeps_the_wheel_once_it_is_longer_than_its_room() {
            show("widgets");
            const view = find("textView"), text = find("text");
            text.text = "one line";
            tryVerify(() => view.contentHeight <= view.height);
            notch(view, 1);
            compare(root.shown, "nested");
            show("widgets");
            let lines = "";
            for (let i = 0; i < 40; ++i) lines += "line " + i + "\n";
            text.text = lines;
            tryVerify(() => view.contentHeight > view.height);
            toEdge(view, -1, false);
            for (let i = 0; i < 10; ++i) { notch(view, -1); wait(15); }
            rest();
            for (let i = 0; i < 10; ++i) { notch(view, 1); wait(15); }
            compare(root.shown, "widgets");
        }
        function test_19_a_slider_takes_the_wheel_and_gives_none_away() {
            show("widgets");
            const slider = find("slider");
            root.level = 0.5;
            notch(slider, 1);
            fuzzyCompare(root.level, 0.55, 0.001);
            rest();
            // to its end and on
            for (let i = 0; i < 30; ++i) { notch(slider, 1); wait(10); }
            compare([root.level, root.shown], [1, "widgets"]);
            rest();
            for (let i = 0; i < 30; ++i) { notch(slider, -1); wait(10); }
            compare([root.level, root.shown], [0, "widgets"]);
            // a list's scroll that passes under the pointer does not move it
            rest();
            root.level = 0.5;
            const view = find("textView");
            view.contentY = 0;
            notch(view, -1);
            for (let i = 0; i < 5; ++i) { notch(slider, -1); wait(15); }
            compare(root.level, 0.5);
        }
        function test_20_a_slider_under_a_touchpad() {
            needTouchpad();
            show("widgets");
            const slider = find("slider");
            root.level = 0.5;
            for (let i = 0; i < 10; ++i) { pixels(slider, 0, 4); wait(10); }
            // the end of the scroll moves nothing
            const before = root.level;
            pixels(slider, 0, 0, Qt.ScrollEnd);
            compare(root.level, before);
            fuzzyCompare(root.level, 0.5 + 40 / ScrollGesture.sliderPixels, 0.001);
            compare(root.shown, "widgets");
        }

        // A page that holds the island (e.g. while the Controls buttons are edited): no page is turned.
        function test_21_not_while_a_page_holds_the_island() {
            show("first");
            expanded.holding = true;
            notch(expanded, -1);
            compare(root.shown, "first");
            expanded.holding = false;
            rest();
            notch(expanded, -1);
            compare(root.shown, "long");
        }
    }
}
