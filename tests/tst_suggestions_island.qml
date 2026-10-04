/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Suggestions as the island shows them: the mark on the pill and the line
    in the open island for what waits quietly (SuggestionStrip.qml), with its
    answers and its "Why?"; a card with ticks for several things and the
    answers behind "⋯" (SuggestionBanner.qml); the dot that pulses instead
    of the mark. With a stand-in for the provider.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 760
    height: 300

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    PlasmaBackend { id: plasma }
    QtObject {
        id: source
        property var pending: []
        property bool hint: false
        property var answers: []
        function answerPending(id, what) { answers.push(id + ":" + what); pending = pending.filter(p => p.id !== id); hint = pending.length > 0; }
    }
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
        dotMode: true
        suggestions: source
        pageOrder: "other"
        extraPages: [{ key: "other", icon: "chronometer", title: "Other", component: otherPage, visible: true }]
    }

    TestCase {
        name: "SuggestionsIsland"
        when: windowShown

        function find(name) { let found = null; const walk = item => { if (found === null && item.objectName === name && item.visible) found = item; for (const c of item.children) walk(c); }; walk(island); return found; }
        function all(name) { const out = []; const walk = item => { if (item.objectName === name && item.visible) out.push(item); for (const c of item.children) walk(c); }; walk(island); return out; }
        function settled() { tryVerify(() => Math.abs(island.surfaceRect.width - island.targetWidth) < 0.001 && Math.abs(island.surfaceRect.height - island.targetHeight) < 0.001, 3000); }
        function initTestCase() { Lang.setting = "en"; activities.warm = true; }
        function cleanup() { source.pending = []; source.hint = false; source.answers = []; activities.queue = []; if (activities.currentEvent) activities.dismissEvent(); island.expanded = false; island.dot = false; wait(80); settled(); }

        function test_1_what_waits_a_mark_and_a_line_in_the_open_island() {
            verify(find("suggestionHint") === null);
            source.pending = [{ id: "battery", ctx: "wd", title: "The battery is low (15%). Switch to the power saving profile?", why: "Why? You said yes to 3 of the last 4 here.", icon: "battery-low-symbolic", color: "#32d74b", hint: true },
                              { id: "pomodoro", ctx: "wd|am", title: "A focus round has started.", why: "Why? I am still learning.", icon: "notifications-disabled-symbolic", color: "#bf5af2", hint: true }];
            source.hint = true;
            tryVerify(() => find("suggestionHint") !== null);
            grabImage(root).save("/tmp/claude-1000/suggestion-hint.png");
            island.expanded = true; settled(); wait(300);
            const strip = find("suggestionStrip");
            verify(strip !== null && strip.height > 20);
            compare(find("suggestionText").text, "The battery is low (15%). Switch to the power saving profile?  +1");
            grabImage(root).save("/tmp/claude-1000/suggestion-strip.png");
            // behind "⋯": Not now, Turn this rule off
            mouseClick(find("suggestionMore")); wait(50);
            verify(find("suggestionYes") === null);
            mouseClick(find("suggestionMore")); wait(50);
            mouseClick(find("suggestionYes")); wait(50);
            compare([source.answers, find("suggestionText").text], [["battery:yes"], "A focus round has started."]);
            mouseClick(find("suggestionNo")); wait(50);
            compare(source.answers, ["battery:yes", "pomodoro:no"]);
            verify(find("suggestionStrip") === null, "nothing waits: no line");
            compare(island.mode, "expanded", "an answer is the button's click, not the island's");
        }

        function test_2_the_dot_pulses_instead() {
            island.dot = true; settled();
            compare([island.dotPulse, island.dotColor.a], [false, 0]);
            source.hint = true;
            compare([island.dotPulse, Qt.colorEqual(island.dotColor, islandTheme.accent), find("suggestionHint")], [true, true, null]);
        }

        function test_3_a_card_with_ticks_and_more_answers() {
            let said = "";
            const checks = [{ text: "Do Not Disturb", checked: true }, { text: "Pause the media", checked: true }];
            activities.flash({ key: "suggestion", icon: "view-calendar-symbolic", color: "#bf5af2", title: "“Stand-up” starts soon.", subtitle: "Why? You said yes to 4 of the last 5 here.",
                               checks: checks, width: islandTheme.notificationWidth, height: islandTheme.questionHeight + 24, duration: 20000,
                               buttons: [{ text: "Yes", primary: true, trigger: () => said = "yes" }, { text: "Always", trigger: () => said = "always" }, { text: "No", trigger: () => said = "no" },
                                         { text: "Not now", more: true, trigger: () => said = "later" }, { text: "Turn this rule off", more: true, trigger: () => said = "never" }] });
            tryCompare(island, "mode", "event"); settled(); wait(350);
            grabImage(root).save("/tmp/claude-1000/suggestion-card.png");
            const ticks = all("suggestionCheck");
            compare(ticks.map(t => t.text), ["☑ Do Not Disturb", "☑ Pause the media"]);
            mouseClick(ticks[1]); wait(50);
            compare([checks[1].checked, all("suggestionCheck")[1].text], [false, "☐ Pause the media"]);
            mouseClick(find("suggestionMore")); wait(80);
            grabImage(root).save("/tmp/claude-1000/suggestion-card-more.png");
            mouseClick(find("suggestionMore")); wait(80);
            activities.chooseEvent(0);
            compare(said, "yes");
        }
    }
}
