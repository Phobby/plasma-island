/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Suggestions on the island (providers/SuggestionProvider.qml on the real
    ActivityManager, with stand-ins for Do Not Disturb, the media, the power
    profile, the calendar…): a card with its answers and its "Why?"; learning
    to do it by itself and undoing that; learning from what is done by hand;
    whose a change is and what is taken back when its cause ends; when
    nothing interrupts; a moment that passes; cards a day and a rule's wait;
    several things on one card; what is kept across a restart, and the first
    version's data. The clock is the test's own (`moment`).
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
        property var sink: ({ formFactor: "", ports: [], activePortIndex: -1 })
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
    property bool fullscreenNow: false
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
            fullscreen: root.fullscreenNow
        }
    }

    TestCase {
        name: "Suggestions"
        when: windowShown

        readonly property real minute: 60000
        readonly property real hour: 3600000
        readonly property real day: 86400000
        property var p: null

        function start() { p = providerComponent.createObject(root); verify(p !== null); wait(10); return p; }
        // (an object that is destroyed lives until the event loop comes round)
        function stop() { if (p !== null) { p.destroy(); p = null; wait(10); } }
        function restart() { stop(); return start(); }
        function later(ms) { root.moment += ms; }
        function event() { return activities.currentEvent; }
        function asked() { return event() !== null && event().key === "suggestion"; }
        function offered() { return event() !== null && event().key === "suggestion-offer"; }
        function nothing() { wait(60); return event() === null && activities.queue.length === 0; }
        function press(label) {
            const i = event().buttons.findIndex(b => b.text === label);
            verify(i >= 0, "a button " + label);
            activities.chooseEvent(i);
            wait(20);
        }
        function clear() { while (event() !== null) { activities.dismissEvent(); wait(250); } activities.queue = []; }
        function state() { return Suggestions.parse(settings.suggestionsData); }
        function signals(id) { return state().events.filter(e => e.r === id).map(e => e.s); }
        function record(on) { nativeCore.screenCastApps = on ? [{ name: "obs" }] : []; wait(20); }
        function mic(on) { nativeCore.microphoneApps = on ? [{ name: "meet" }] : []; wait(20); }
        function round(on) { pomodoroTimer.phase = on ? "work" : "break"; wait(20); }
        function meeting(key, minutes, more) {
            agenda.pinned = Object.assign({ key: key, title: "Stand-up", start: root.moment + 5 * minute, end: root.moment + (5 + minutes) * minute, calendar: "Work", link: "" }, more || {});
            agenda.phase = "upcoming"; wait(20);
        }
        function meetingOver() { agenda.phase = ""; agenda.pinned = null; wait(20); }

        function initTestCase() { Lang.setting = "en"; activities.warm = true; }
        function init() {
            settings.suggestionsData = ""; settings.suggestionsAvailable = "";
            root.moment = new Date(2026, 9, 5, 9, 0).getTime(); root.withDnd = true; root.fullscreenNow = false;
            media.isPlaying = false; media.isPaused = true; media.hasBattery = true; media.batteryPluggedIn = false; media.batteryPercent = 80;
            media.sink = ({ formFactor: "", ports: [], activePortIndex: -1 });
            quiet.active = false; quiet.until = null; profiles.profile = "balanced";
            nativeCore.screenCastApps = []; nativeCore.microphoneApps = []; pomodoroTimer.phase = ""; agenda.phase = ""; agenda.pinned = null; radio.connectedDevices = [];
            start();
        }
        function cleanup() { stop(); clear(); }

        function test_01_a_card_with_its_answers_and_its_why() {
            compare(settings.suggestionsAvailable, "meeting,meeting-media,recording,call,pomodoro,battery,disconnect,headphones");
            record(true);
            tryVerify(asked);
            compare(event().title, "The screen is being recorded. Hide notifications while it lasts?");
            compare(event().subtitle, "Why? This is the moment the rule is for; I am still learning.");
            compare(event().buttons.map(b => b.text + (b.more ? "*" : "")), ["Yes", "Always", "No", "Not now*", "Turn this rule off*"]);
            compare(signals("recording"), ["shown"]);
            press("Yes");
            compare([quiet.active, signals("recording"), p.owned.dnd.id], [true, ["shown", "yes"], "recording"]);
            // its cause ends: what it switched on is taken back
            record(false);
            compare([quiet.active, p.owned.dnd], [false, undefined]);
            verify(nothing());
            // only coarse buckets are kept: no title, no application
            compare(state().events.map(e => e.c), ["wd|am", "wd|am"]);
            verify(settings.suggestionsData.indexOf("obs") < 0);
        }

        function test_02_it_learns_to_do_it_by_itself_and_an_undo_takes_that_back() {
            for (let i = 0; i < 4; ++i) {
                round(true); tryVerify(asked); press("Yes"); compare(quiet.active, true);
                round(false); compare(quiet.active, false);
                if (i < 3) { clear(); later(day); }
            }
            // sure enough now, on different days: asked once whether to do it by itself
            tryVerify(offered);
            compare(event().subtitle, "Do Not Disturb in a focus round · Weekdays · morning");
            press("Yes"); clear();
            later(day);
            round(true);
            compare([quiet.active, asked()], [true, false], "done without asking");
            tryVerify(() => event() !== null && event().key === "dnd");
            compare([event().title, event().subtitle, event().trailing.text], ["Do Not Disturb is on", "Done automatically", "Undo"]);
            compare(state().log.length, 1);
            // Undo: taken back, and it asks again here
            activities.activateEvent(); wait(20);
            compare([quiet.active, state().log[0].undone, Suggestions.status(state(), "pomodoro", "wd|am", root.moment)], [false, 1, "ask"]);
            clear(); round(false); later(3 * day);      // (over the weekend: the same kind of day)
            round(true); tryVerify(asked);
            // "Always": automatic at once; a second undo closes the rule here, said once
            press("Always"); clear(); round(false); later(day);
            round(true); compare(quiet.active, true);
            tryVerify(() => event() !== null && event().key === "dnd");
            activities.activateEvent(); wait(20);
            tryVerify(() => event() !== null && event().title === "I will not do this here any more");
            compare(Suggestions.status(state(), "pomodoro", "wd|am", root.moment), "off");
            clear(); round(false); later(day);
            round(true); verify(nothing()); compare(quiet.active, false);
            // …but only here: in the evening it still asks
            round(false); later(10 * hour);
            round(true); tryVerify(asked);
        }

        function test_03_done_by_hand_at_its_moment_it_learns_without_asking() {
            // four times: Do Not Disturb by hand just before the focus round
            for (let i = 0; i < 4; ++i) {
                quiet.setActive(true); wait(20); later(minute);
                round(true);
                compare(asked(), false);
                if (i < 3) verify(nothing());
                round(false); compare(quiet.active, true, "the user's own is not switched off");
                quiet.setActive(false); wait(20);
                if (i < 3) { clear(); later(day); }
            }
            compare(signals("pomodoro"), ["implicit", "implicit", "implicit", "implicit"]);
            // …and one question: shall I?
            tryVerify(offered);
            press("No, keep asking"); clear(); later(day);
            quiet.setActive(true); wait(20); round(true);
            verify(nothing(), "asked once, at the fourth time");
            round(false); quiet.setActive(false); wait(20);
            compare(state().rules.pomodoro.offered["wd|am"], 1);
        }
        function test_03b_the_question_after_four_times_by_hand() {
            for (let i = 0; i < 4; ++i) {
                // by hand shortly after the moment, while its card is out: the card goes away
                round(true); tryVerify(asked);
                later(minute); quiet.setActive(true); wait(30);
                if (i < 3) { verify(!asked()); verify(nothing()); }
                round(false); quiet.setActive(false); wait(20);
                if (i < 3) { clear(); later(day); }
            }
            tryVerify(offered);
            compare(event().title, "You did this by hand the last 4 times: Do Not Disturb. Shall I do it by myself?");
            press("No, keep asking"); clear(); later(day);
            for (let i = 0; i < 2; ++i) { quiet.setActive(true); wait(20); round(true); wait(30); round(false); quiet.setActive(false); wait(20); later(day); }
            verify(nothing(), "it does not ask that again");
        }

        function test_04_whose_it_is() {
            // the user's own Do Not Disturb: nothing is suggested, nothing is switched off
            quiet.setActive(true); wait(20); later(10 * minute);
            record(true); verify(nothing());
            record(false); compare(quiet.active, true);
            quiet.setActive(false); wait(20); later(hour);
            // ours, but the user switched it off in between: left alone afterwards
            record(true); tryVerify(asked); press("Yes"); compare(quiet.active, true);
            later(minute); quiet.setActive(false); wait(20);
            compare(p.owned.dnd, undefined);
            later(minute); quiet.setActive(true); wait(20);
            record(false);
            compare(quiet.active, true, "switched on again by the user: theirs");
            quiet.setActive(false); wait(20); clear(); later(day);
            // an event's Do Not Disturb runs until the event ends, and its running out is nobody's doing
            meeting("m1", 30); tryVerify(asked); press("Yes");
            compare([quiet.active, quiet.until.getTime()], [true, agenda.pinned.end]);
            later(36 * minute); meetingOver(); quiet.setActive(false); wait(20);
            compare(signals("meeting").indexOf("undo"), -1);
            clear(); later(day);
            // the media paused for a call plays again when the call ends, unless the user did something
            media.isPlaying = true; media.isPaused = false; wait(20);
            mic(true); tryVerify(asked); press("Yes"); compare(media.isPaused, true);
            mic(false); compare(media.isPlaying, true);
        }

        function test_05_nothing_interrupts() {
            // full screen: no card, no mark; it waits in the open island
            root.fullscreenNow = true;
            round(true); verify(nothing());
            compare([p.pending.map(x => x.id), p.hint], [["pomodoro"], false]);
            root.fullscreenNow = false;
            // the moment passes: gone, and nothing was learned
            round(false);
            compare([p.pending.length, signals("pomodoro")], [0, []]);
            later(hour);
            // Do Not Disturb on, the screen recorded, a call: the same
            record(true); tryVerify(asked); press("No"); clear();
            media.isPlaying = true; media.isPaused = false; wait(20);
            mic(true); verify(nothing());
            compare(p.pending.map(x => x.id), ["call"]);
            // answered in the open island
            p.answerPending("call", "yes");
            compare([media.isPaused, p.pending.length, signals("call")], [true, 0, ["yes"]]);
            mic(false); record(false);
        }

        function test_06_a_moment_that_passes_teaches_nothing() {
            meeting("m1", 60); tryVerify(asked);
            compare(event().title, "“Stand-up” starts soon. Turn on Do Not Disturb until it ends?");
            meetingOver();
            verify(nothing(), "the card is gone");
            compare(signals("meeting"), ["shown"]);
            compare(Math.round(Suggestions.estimate(state(), "meeting", "wd|am|cal:Work|dur:mid", root.moment).confidence * 100), 50);
            verify(settings.suggestionsData.indexOf("Stand-up") < 0, "an event's title is never kept");
            // no answer in time is a weak signal, not a no
            later(hour); meeting("m2", 60); tryVerify(asked);
            activities.expireEvent(); wait(20);
            compare(signals("meeting"), ["shown", "shown", "timeout"]);
            compare(Suggestions.status(state(), "meeting", "wd|am|cal:Work|dur:mid", root.moment), "ask");
        }

        function test_07_a_rules_wait_and_the_cards_of_a_day() {
            record(true); tryVerify(asked); press("No"); record(false); clear();
            // within its wait (20 min, doubled by the no): kept quietly (no mark while the screen is recorded)
            later(30 * minute);
            record(true); verify(nothing());
            compare([p.pending.map(x => x.id), p.hint], [["recording"], false]);
            record(false); later(15 * minute);
            record(true); tryVerify(asked); press("Yes"); record(false); clear();
            // another rule waits only for the pause between two cards
            later(2 * minute); round(true); verify(nothing()); round(false);
            later(4 * minute); round(true); tryVerify(asked); press("Yes"); round(false); clear();
            // the cards of a day
            p.dailyCards = 4;
            later(2 * hour); round(true); tryVerify(asked); press("Yes"); round(false); clear();
            later(2 * hour); round(true); verify(nothing(), "the day's cards are used up");
            compare(p.pending.length, 1);
            round(false); later(day);
            round(true); tryVerify(asked);
        }

        function test_08_several_things_for_one_moment_on_one_card() {
            media.isPlaying = true; media.isPaused = false; wait(20);
            meeting("m1", 30, { link: "https://meet.example/x" });
            tryVerify(asked);
            compare([event().title, event().checks.map(c => c.text + ":" + c.checked)], ["“Stand-up” starts soon.", ["Do Not Disturb:true", "Pause the media:true"]]);
            // one of them unticked: each learns by itself
            event().checks[1].checked = false;
            press("Yes");
            compare([quiet.active, media.isPlaying], [true, true]);
            compare([signals("meeting"), signals("meeting-media")], [["shown", "yes"], ["shown", "no"]]);
            compare(state().events[0].c, "wd|am|cal:Work|dur:short|video");
        }

        function test_09_low_battery_and_the_headphones() {
            // not over within minutes: no card; it waits, with a mark
            media.batteryPercent = 15; wait(20);
            verify(nothing());
            compare([p.pending.map(x => x.id), p.hint, p.pending[0].title], [["battery"], true, "The battery is low (15%). Switch to the power saving profile?"]);
            p.answerPending("battery", "yes");
            compare([profiles.profile, p.owned.profile.before], ["power-saver", "balanced"]);
            // on the charger again: the profile it had
            media.batteryPluggedIn = true; wait(20);
            compare(profiles.profile, "balanced");
            // the headphones go away while something plays
            media.sink = ({ formFactor: "headphone", ports: [], activePortIndex: -1 }); wait(20);
            media.isPlaying = true; media.isPaused = false; wait(20);
            later(hour);
            media.sink = ({ formFactor: "", ports: [{ name: "analog-output-speaker" }], activePortIndex: 0 }); wait(20);
            tryVerify(asked);
            compare(event().title, "The headphones are gone. Pause the media?");
            press("Yes"); compare(media.isPaused, true);
            // "headphones connected: play" guesses: off until it is switched on
            clear(); later(hour);
            media.sink = ({ formFactor: "headset", ports: [], activePortIndex: -1 }); wait(20);
            verify(nothing());
            compare(Suggestions.rule(state(), "headphones").why, "experimental");
        }

        function test_10_kept_across_a_restart_and_the_first_versions_data() {
            record(true); tryVerify(asked); press("Always"); record(false); clear();
            restart(); later(day);
            record(true);
            compare([quiet.active, asked()], [true, false], "automatic after the restart");
            record(false); clear(); stop();
            // what the first version kept
            settings.suggestionsData = JSON.stringify({ v: 1, last: 0, rules: { pomodoro: { mode: "auto", yes: 6, later: 0, yesRow: 6, laterRow: 0, last: 0, asked: 1, told: 0 },
                                                                                 recording: { mode: "off", why: "never", yes: 0, later: 3, yesRow: 0, laterRow: 3, last: 0, asked: 0, told: 0 } } });
            start(); later(day);
            round(true); compare(quiet.active, true);
            round(false); clear();
            record(true); verify(nothing());
            compare([state().v, state().rules.recording.why], [2, "never"]);
        }

        function test_11_off_and_turned_off() {
            record(true); tryVerify(asked); press("Turn this rule off"); record(false); clear();
            compare([state().rules.recording.mode, state().rules.recording.why], ["off", "never"]);
            later(day); record(true); verify(nothing()); record(false);
            p.enabled = false;
            round(true); verify(nothing());
            compare([p.pending.length, quiet.active], [0, false]);
        }
    }
}
