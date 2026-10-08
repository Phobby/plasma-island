/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The island's own updates (providers/SelfUpdateProvider.qml): when it looks,
    what it asks, what it starts and what the island shows while that runs.
    The repository and the updater are stood in for: nothing is fetched and
    nothing is installed (the script itself: tests/island-update.test.sh).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/providers"

Item {
    id: root
    width: 100
    height: 100

    Theme { id: islandTheme }
    ActivityManager { id: activities }
    property var events: []
    Connections { target: activities; function onCurrentEventChanged() { if (activities.currentEvent) root.events = root.events.concat([activities.currentEvent]); } }

    property var asked: []              // addresses
    property var answer: [200, ""]
    property var started: []            // [program, args, directory]
    property var detached: []
    property double clock: 1000000000000

    component Stream: QtObject {
        property bool running: false
        signal lines(var lines)
        signal finished(int exitCode, string errorOutput)
        function start(program, args, input, directory) { root.started = root.started.concat([[program, args, directory]]); running = true; return true; }
        function end(code) { running = false; finished(code, ""); }
    }
    Component { id: streamMaker; Stream {} }
    QtObject {
        id: nativeCore
        readonly property var local: QtObject { function environment(name) { return name === "HOME" ? "/home/someone" : ""; } }
        function newStream(owner) { return streamMaker.createObject(owner); }
        function startDetached(program, args) { root.detached = root.detached.concat([[program, args]]); return true; }
    }
    component Updater: SelfUpdateProvider {
        manager: activities
        theme: islandTheme
        current: "0.1.0"
        script: "/there/island-update.sh"
        firstCheckAfter: 3600000
        now: () => root.clock
        request: (url, done) => { root.asked = root.asked.concat([url]); done(root.answer[0], root.answer[1]); }
        onAskedAbout: mark => asked = mark
    }
    Updater { id: updater; core: nativeCore }
    Updater { id: bare; core: null }

    TestCase {
        name: "SelfUpdate"
        when: windowShown

        function repository(version) { root.answer = [200, JSON.stringify({ KPlugin: { Id: "org.phobby.dynamicisland", Version: version } })]; }
        function activity() { return updater.activity; }
        function last() { return root.events[root.events.length - 1]; }
        function initTestCase() { activities.warm = true; }
        // (the manager shows an event a moment after it was handed in)
        function settle() { wait(40); }
        function init() {
            while (activities.currentEvent) activities.dismissEvent();
            root.events = []; root.asked = []; root.started = []; root.detached = []; root.clock += 3 * 24 * 3600 * 1000;
            for (const u of [updater, bare]) { u.mode = 1; u.asked = ""; u.latest = ""; }
            if (updater.stream && updater.stream.running) updater.stream.end(-1);
            while (activities.currentEvent) activities.dismissEvent();
            root.events = [];
        }

        function test_versions() {
            verify(updater.newer("0.2.0", "0.1.0") && updater.newer("0.10.0", "0.9.9") && updater.newer("1.0", "0.9.9") && updater.newer("0.1.0.1", "0.1.0"));
            verify(!updater.newer("0.1.0", "0.1.0") && !updater.newer("0.1", "0.1.0") && !updater.newer("0.0.9", "0.1.0"));
            verify(!updater.newer("0.2.0; rm", "0.1.0") && !updater.newer("v0.2.0", "0.1.0") && !updater.newer("", "0.1.0"));
        }
        function test_switched_off_it_asks_nobody() {
            updater.mode = 0; repository("0.2.0");
            updater.check(); settle();
            compare([root.asked.length, root.events.length], [0, 0]);
        }
        function test_nothing_newer_nothing_said() {
            for (const version of ["0.1.0", "0.0.9", "not a version"]) { repository(version); updater.check(); }
            root.answer = [404, "Not Found"]; updater.check();
            root.answer = [200, "<html>"]; updater.check();
            compare([root.asked.length, root.events.length, root.started.length], [5, 0, 0]);
        }
        function test_a_newer_one_is_asked_about_and_later_leaves_it() {
            repository("0.2.0");
            updater.check(); settle();
            compare(root.asked, [updater.source]);
            compare(root.events.length, 1);
            compare(last().title, Lang.i18n("Dynamic Island %1 is available.", "0.2.0"));
            compare(last().buttons.length, 2);
            activities.chooseEvent(1);                      // Later
            compare(root.started.length, 0);
            // the shell starts again, the day is not over: not asked again
            updater.check(); settle();
            compare(root.events.length, 1);
            // the next day it is; and a still newer one at once
            root.clock += 24 * 3600 * 1000;
            updater.check(); settle();
            compare(root.events.length, 2);
            activities.dismissEvent(); settle();
            repository("0.3.0");
            updater.check(); settle();
            compare(root.events.length, 3);
        }
        function test_update_runs_the_updater_and_the_island_shows_how_far_it_is() {
            repository("0.2.0");
            updater.check(); settle();
            activities.chooseEvent(0);                      // Update
            compare(root.started, [["sh", ["/there/island-update.sh", "0.2.0", "--restart"], "/home/someone/.cache/dynamicisland/update"]]);
            verify(activity().active);
            compare([activity().subtitle, activity().progress], [Lang.i18n("Downloading…"), -2]);
            updater.stream.lines(["STEP unpack", "something else", "STEP build"]);
            compare([activity().subtitle, activity().progress], [Lang.i18n("Building…"), -2]);
            updater.stream.lines(["PROGRESS 40"]);
            compare(activity().progress, 0.4);
            updater.stream.lines(["PROGRESS 100", "STEP install", "DONE 0.2.0", "STEP restart"]);
            compare([activity().subtitle, activity().progress], [Lang.i18n("Restarting the shell…"), -2]);
            // while it runs nothing else is started
            updater.check(); settle();
            compare(updater.install("0.2.0", true), false);
            compare(root.started.length, 1);
            const before = root.events.length;
            updater.stream.end(0); settle();
            compare(activity().active, false);
            compare(root.events.length, before, "the shell restarts: nothing more to say");
        }
        function test_it_failed() {
            repository("0.2.0");
            updater.check(); settle();
            activities.chooseEvent(0);
            updater.stream.lines(["STEP build", "ERROR the installer failed: see /x/install.log"]);
            updater.stream.end(1); settle();
            compare(activity().active, false);
            compare([last().title, last().subtitle], [Lang.i18n("The update did not work"), "the installer failed: see /x/install.log"]);
        }
        function test_by_itself_it_installs_and_asks_only_about_the_restart() {
            updater.mode = 2; repository("0.2.0");
            updater.check(); settle();
            compare(root.started, [["sh", ["/there/island-update.sh", "0.2.0"], "/home/someone/.cache/dynamicisland/update"]]);
            compare(root.events.length, 0);
            updater.stream.lines(["STEP install", "DONE 0.2.0"]);
            updater.stream.end(0); settle();
            compare(last().title, Lang.i18n("Dynamic Island %1 is installed.", "0.2.0"));
            compare(root.detached.length, 0);
            activities.chooseEvent(0);                      // Restart now
            compare(root.detached, [["sh", ["/there/island-update.sh", "--restart-only"]]]);
        }
        function test_without_the_native_module_it_only_says_so() {
            for (const mode of [1, 2]) {
                bare.mode = mode; bare.asked = ""; repository("0.2.0");
                bare.check(); settle();
                compare(last().title, Lang.i18n("Dynamic Island %1 is available.", "0.2.0"));
                verify(last().buttons === undefined);
                compare(bare.install("0.2.0", true), false);
                activities.dismissEvent();
            }
            compare(root.started.length, 0);
        }
        function test_a_new_version_says_once_that_it_runs() {
            let seen = [];
            const component = Qt.createComponent("../org.phobby.dynamicisland/contents/ui/providers/SelfUpdateProvider.qml");
            for (const [previous, said, written] of [["0.1.0", 1, ["0.2.0"]], ["0.2.0", 0, []], ["", 0, ["0.2.0"]]]) {
                seen = []; root.events = [];
                const u = component.createObject(root, { manager: activities, theme: islandTheme, mode: 0, current: "0.2.0", previous: previous, greetAfter: 10 });
                u.versionSeen.connect(v => seen.push(v));
                wait(80);
                compare([root.events.length, seen], [said, written], "before: '" + previous + "'");
                if (said) compare([last().title, last().subtitle], [Lang.i18n("Dynamic Island was updated"), Lang.i18n("Version %1", "0.2.0")]);
                while (activities.currentEvent) activities.dismissEvent();
                u.destroy();
            }
        }
    }
}
