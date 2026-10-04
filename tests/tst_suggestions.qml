/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The suggestion provider with the real ActivityManager and stand-ins for
    the parts it watches and acts on (Do Not Disturb, power profiles, media,
    screen casts, the microphone, Pomodoro, the calendar, Bluetooth). The
    provider is handed its time (`clock`); the system's clock is never read
    or changed. "The shell restarts" is a new provider on what the old one
    stored.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/providers"
import "../org.phobby.dynamicisland/contents/ui/Suggestions.js" as Suggestions

Item {
    id: root
    width: 400
    height: 140

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }

    QtObject {
        id: settings
        property string suggestionsAvailable: ""
        property string suggestionsData: ""
    }
    QtObject {
        id: media
        property bool hasBattery: true
        property bool batteryPluggedIn: false
        property int batteryPercent: 80
        property bool hasMedia: true
        property bool isPlaying: false
        property bool isPaused: true
        property bool hasSink: true
        property string sinkName: "Speakers"
        function playPause() { isPlaying = !isPlaying; isPaused = !isPlaying; }
    }
    QtObject {
        id: quiet
        property bool active: false
        property var until: null
        function setActive(on) { active = on; until = null; }
        function setActiveUntil(date) { until = date; active = true; }
    }
    QtObject {
        id: profiles
        property bool profilesAvailable: true
        property var profiles: ["power-saver", "balanced", "performance"]
        property string profile: "balanced"
        function setProfile(p) { profile = p; }
    }
    QtObject {
        id: nativeCore
        property var screenCastApps: []
        property var microphoneApps: []
        property var local: null
    }
    QtObject { id: pomodoroTimer; property string phase: "" }
    QtObject { id: agenda; property string phase: ""; property var pinned: null }
    QtObject {
        id: radio
        property var connectedDevices: []
        function iconFor(d) { return d.icon; }
    }

    // Monday 5 October 2026, 09:00
    property real moment: new Date(2026, 9, 5, 9, 0).getTime()
    property bool withDnd: true
    Component {
        id: providerComponent
        SuggestionProvider {
            manager: activities
            theme: islandTheme
            cfg: settings
            backend: media
            core: nativeCore
            dnd: root.withDnd ? quiet : null
            power: profiles
            bluetooth: radio
            pomodoro: pomodoroTimer
            calendar: agenda
            clock: () => root.moment
        }
    }

    TestCase {
        name: "Suggestions"
        when: windowShown

        readonly property real minute: 60000
        readonly property real hour: 3600000
        property var p: null

        function start() {
            p = providerComponent.createObject(root);
            verify(p !== null);
            wait(10);
            return p;
        }
        // (an object that is destroyed lives until the event loop comes round)
        function stop() { if (p !== null) { p.destroy(); p = null; wait(10); } }
        function restart() { stop(); return start(); }
        function later(ms) { root.moment += ms; }
        function event() { return activities.currentEvent; }
        function asked() { return event() !== null && event().key === "suggestion" && Array.isArray(event().buttons); }
        function quietNow() { wait(60); return event() === null && activities.queue.length === 0; }
        // the recording starts (and with it the rule's moment), or stops
        function record(on) { nativeCore.screenCastApps = on ? ["OBS Studio"] : []; }
        // one round of the recording's question, answered: "yes" | "later" | "never" | "timeout" | "closed"
        function round(what) {
            record(true);
            tryVerify(asked, 2000, "the question for: " + what);
            if (what === "timeout") activities.expireEvent();
            else if (what === "closed") activities.closeEvent();
            else activities.chooseEvent(what === "yes" ? 0 : what === "later" ? 1 : 2);
            wait(10);
        }
        function mode(id) { return Suggestions.rule(p.store.read(), id).mode; }

        function init() {
            Lang.setting = "en";
            activities.warm = true;
            activities.dismissEvent();
            activities.queue = [];
            settings.suggestionsData = "";
            settings.suggestionsAvailable = "";
            nativeCore.screenCastApps = []; nativeCore.microphoneApps = []; nativeCore.local = null;
            quiet.active = false; quiet.until = null;
            profiles.profile = "balanced";
            media.batteryPercent = 80; media.batteryPluggedIn = false; media.isPlaying = false; media.isPaused = true; media.hasMedia = true; media.sinkName = "Speakers";
            pomodoroTimer.phase = ""; agenda.phase = ""; agenda.pinned = null; radio.connectedDevices = [];
            root.withDnd = true;
            root.moment = new Date(2026, 9, 5, 9, 0).getTime();
            start();
        }
        function cleanup() { stop(); }

        function test_a_question_with_three_answers() {
            record(true);
            tryVerify(asked);
            const e = event();
            compare(e.title, "The screen is being recorded. Hide notifications while it lasts?");
            compare(e.buttons.map(b => b.text), ["Yes", "Not now", "Never suggest this"]);
            compare([e.duration, e.height, e.buttons[0].primary], [10000, islandTheme.questionHeight, true]);
            compare(Suggestions.rule(p.store.read(), "recording").last, root.moment, "counted as suggested once it is shown");
            // Yes: hidden while the recording lasts
            activities.chooseEvent(0);
            compare([quiet.active, p.held, event()], [true, "recording", null]);
            compare(Suggestions.rule(p.store.read(), "recording").yes, 1);
            record(false);
            compare([quiet.active, p.held], [false, ""], "and back when it is over");
        }

        function test_not_now_three_times_then_less_often() {
            for (let i = 0; i < 3; ++i) {
                round("later");
                compare(quiet.active, false);
                record(false);
                later(10 * minute);
            }
            compare(Suggestions.rule(p.store.read(), "recording").laterRow, 3);
            // ten minutes after the third: not asked; neither 59 minutes after it
            record(true);
            verify(quietNow(), "waits longer now");
            record(false);
            later(49 * minute);
            record(true);
            verify(quietNow());
            record(false);
            later(1 * minute);                                  // an hour after the third
            record(true);
            tryVerify(asked);
            activities.chooseEvent(1);
            record(false);
            // the fourth: two hours
            later(119 * minute);
            record(true);
            verify(quietNow());
            record(false);
            later(1 * minute);
            record(true);
            tryVerify(asked);
        }

        function test_never_is_kept_across_a_restart() {
            round("never");
            compare([mode("recording"), quiet.active], ["off", false]);
            record(false);
            later(3 * hour);
            record(true);
            verify(quietNow());
            record(false);
            // plasmashell restarts: a new provider on what was stored
            restart();
            later(24 * hour);
            record(true);
            verify(quietNow(), "still off after the restart");
            compare(Suggestions.rule(p.store.read(), "recording").why, "never");
            // the other rules are not touched
            record(false);
            media.batteryPercent = 15;
            tryVerify(asked);
            compare(event().title, "The battery is low (15%). Switch to the power saving profile?");
        }

        function test_learning_is_a_file_that_outlives_the_shell() {
            if (tools.status !== Loader.Ready || typeof tools.item.writeTextFile !== "function") skip("the native module is not built: ./install.sh");
            const file = decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")) + ".run/suggestions-" + Math.floor(Math.random() * 1e9).toString(36) + ".json";
            nativeCore.local = tools.item;
            restart();
            p.store.path = file;
            verify(p.store.inFile);
            for (let i = 0; i < 2; ++i) { round("yes"); record(false); later(10 * minute); }
            round("later");
            record(false);
            const text = tools.item.readTextFile(file);
            compare(JSON.parse(text).rules.recording, { mode: "suggest", why: "", yes: 2, later: 1, yesRow: 0, laterRow: 1, last: root.moment, asked: 0, told: 0 });
            compare(settings.suggestionsData, "", "not in the settings when there is the file");
            // the shell restarts
            restart();
            p.store.path = file;
            compare(Suggestions.rule(p.store.read(), "recording").yes, 2);
            compare(Suggestions.text(p.store.read()), text);
            tools.item.removeFile(file);
        }

        function test_no_answer_five_times_switches_it_off_and_says_so_once() {
            for (let i = 1; i <= 5; ++i) {
                round(i % 2 ? "timeout" : "closed");
                record(false);
                if (i < 5) { compare(mode("recording"), "suggest"); verify(quietNow()); }
                later(5 * hour);
            }
            compare(mode("recording"), "off");
            tryVerify(() => event() !== null && event().key === "suggestion-note");
            compare([event().title, event().subtitle], ["I will not show this suggestion any more", "You can switch it on again in Settings → Suggestions"]);
            activities.dismissEvent();
            record(true);
            verify(quietNow(), "not suggested any more");
        }

        function test_yes_three_times_then_automatic_with_undo() {
            for (let i = 1; i <= 3; ++i) {
                round("yes");
                compare(quiet.active, true);
                if (i < 3) { record(false); later(10 * minute); verify(quietNow(), "no offer after " + i); }
            }
            // the third yes: asked once whether to do it automatically
            tryVerify(asked);
            compare([event().title, event().subtitle], ["Shall I do this automatically from now on?", "Hide notifications while the screen is recorded"]);
            compare(event().buttons.map(b => b.text), ["Yes", "No, keep asking"]);
            activities.chooseEvent(0);
            compare(mode("recording"), "auto");
            tryVerify(() => event() !== null && event().title === "Automatic from now on");
            activities.dismissEvent();
            record(false);
            compare(quiet.active, false);

            // from now on: done without asking, said with an Undo
            later(1 * minute);                                  // also within the pause between suggestions
            record(true);
            compare([quiet.active, p.held], [true, "recording"], "done at once");
            tryVerify(() => event() !== null && event().key === "dnd");
            compare([event().title, event().subtitle, event().trailing.type, event().trailing.text], ["Do Not Disturb is on", "Done automatically", "button", "Undo"]);
            verify(!Array.isArray(event().buttons), "no question");
            // Undo: taken back, and the rule asks again
            activities.activateEvent();
            compare([quiet.active, mode("recording")], [false, "suggest"]);
            tryVerify(() => event() !== null && event().title === "Undone");
            activities.dismissEvent();
            record(false);
            later(10 * minute);
            record(true);
            tryVerify(asked, 2000, "asks again after the undo");
            compare(event().buttons.length, 3);
        }

        function test_declining_the_offer_keeps_asking() {
            for (let i = 1; i <= 3; ++i) { round("yes"); if (i < 3) { record(false); later(10 * minute); } }
            tryVerify(asked);
            activities.chooseEvent(1);                          // "No, keep asking"
            compare(mode("recording"), "suggest");
            record(false);
            for (let i = 0; i < 3; ++i) {
                later(10 * minute);
                round("yes");
                record(false);
                verify(quietNow(), "the offer is made once");
            }
        }

        function test_not_while_do_not_disturb_or_a_recording_and_not_too_often() {
            // Do Not Disturb is on: nothing is suggested
            quiet.active = true;
            media.batteryPercent = 15;
            record(true);
            verify(quietNow());
            quiet.active = false;
            record(false);
            media.batteryPercent = 80;
            // the screen is recorded: no other rule's question (its own came at the start)
            round("later");
            later(30 * minute);
            media.batteryPercent = 12;
            verify(quietNow(), "not into a recording");
            record(false);
            media.batteryPercent = 80;
            // two rules, two minutes apart: the second waits for the pause
            later(30 * minute);
            media.batteryPercent = 15;
            tryVerify(asked);
            activities.chooseEvent(1);
            later(2 * minute);
            pomodoroTimer.phase = "work";
            verify(quietNow(), "within five minutes of the last one");
            pomodoroTimer.phase = "break";
            later(3 * minute);
            pomodoroTimer.phase = "work";
            tryVerify(asked);
            compare(event().title, "A focus round has started. Turn on Do Not Disturb until the break?");
            // the pause is a setting
            activities.chooseEvent(1);
            p.gapMinutes = 30;
            later(10 * minute);
            media.batteryPercent = 80; media.batteryPercent = 15;
            verify(quietNow());
        }

        function test_a_rule_whose_part_is_missing_never_comes_up() {
            compare(settings.suggestionsAvailable, "meeting,recording,call,battery,pomodoro,headphones");
            stop();
            root.withDnd = false;                               // no Do Not Disturb on this system
            profiles.profilesAvailable = false;
            start();
            compare(settings.suggestionsAvailable, "call,headphones");
            record(true);
            pomodoroTimer.phase = "work";
            media.batteryPercent = 5;
            agenda.pinned = { key: "e1", title: "Stand-up", end: root.moment + hour }; agenda.phase = "upcoming";
            verify(quietNow());
            profiles.profilesAvailable = true;
            // a part that is switched off in the settings
            p.recordingWatched = false; p.mediaWatched = false;
            compare(settings.suggestionsAvailable, "battery");
            // the whole thing switched off
            stop();
            root.withDnd = true;
            start();
            p.enabled = false;
            record(true);
            verify(quietNow());
        }

        function test_what_is_there_at_the_start_is_not_news() {
            stop();
            nativeCore.screenCastApps = ["OBS Studio"];
            media.batteryPercent = 10;
            pomodoroTimer.phase = "work";
            start();
            verify(quietNow());
        }

        function test_every_rule_does_its_thing_and_can_take_it_back() {
            // an event is about to start: Do Not Disturb until it ends
            const end = root.moment + 45 * minute;
            agenda.pinned = { key: "e1", title: "Stand-up", end: end };
            agenda.phase = "upcoming";
            tryVerify(asked);
            compare(event().title, "“Stand-up” starts soon. Turn on Do Not Disturb until it ends?");
            activities.chooseEvent(0);
            compare([quiet.active, quiet.until.getTime(), p.held], [true, end, ""]);
            p.undo("meeting");
            compare(quiet.active, false);
            agenda.phase = ""; agenda.pinned = null;

            // the microphone is taken into use while something plays: pause
            later(10 * minute);
            media.isPlaying = true; media.isPaused = false;
            nativeCore.microphoneApps = ["Meet"];
            tryVerify(asked);
            compare(event().title, "The microphone is in use. Pause the media?");
            activities.chooseEvent(0);
            compare([media.isPlaying, media.isPaused], [false, true]);
            p.undo("call");
            compare(media.isPlaying, true);
            nativeCore.microphoneApps = [];
            // …and nothing to pause, nothing to ask
            later(10 * minute);
            media.isPlaying = false; media.isPaused = true;
            nativeCore.microphoneApps = ["Meet"];
            verify(quietNow());
            nativeCore.microphoneApps = [];

            // the battery is low: the power saving profile
            later(10 * minute);
            profiles.profile = "performance";
            media.batteryPercent = 20;
            tryVerify(asked);
            activities.chooseEvent(0);
            compare(profiles.profile, "power-saver");
            p.undo("battery");
            compare(profiles.profile, "performance", "back to what it was");
            // on the charger, or already saving: nothing to ask
            later(10 * minute);
            media.batteryPercent = 80; media.batteryPluggedIn = true; media.batteryPercent = 10;
            verify(quietNow());
            media.batteryPluggedIn = false; media.batteryPercent = 80;

            // a focus round: Do Not Disturb until its break
            later(10 * minute);
            pomodoroTimer.phase = "work";
            tryVerify(asked);
            activities.chooseEvent(0);
            compare([quiet.active, p.held], [true, "pomodoro"]);
            pomodoroTimer.phase = "break";
            compare([quiet.active, p.held], [false, ""]);
            // switched off by hand meanwhile: it is the user's again, the break changes nothing
            later(10 * minute);
            pomodoroTimer.phase = "work";
            tryVerify(asked);
            activities.chooseEvent(0);
            quiet.setActive(false);
            quiet.setActive(true);
            compare(p.held, "");
            pomodoroTimer.phase = "break";
            compare(quiet.active, true);
            quiet.setActive(false);
            pomodoroTimer.phase = "";

            // headphones while the media is paused: play
            later(10 * minute);
            radio.connectedDevices = [{ address: "AA:BB", name: "Buds", icon: "audio-headset-symbolic" }];
            tryVerify(asked);
            compare(event().title, "Headphones are connected. Carry on playing?");
            activities.chooseEvent(0);
            compare(media.isPlaying, true);
            p.undo("headphones");
            compare(media.isPaused, true);
            // a keyboard is no headphones; the output becoming headphones is
            later(10 * minute);
            radio.connectedDevices = [{ address: "AA:BB", name: "Buds", icon: "audio-headset-symbolic" }, { address: "CC:DD", name: "Keys", icon: "input-keyboard-symbolic" }];
            verify(quietNow());
            media.sinkName = "Headphones";
            tryVerify(asked);
        }
    }
}
