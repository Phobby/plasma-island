/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Habits provider with the real ActivityManager, a stand-in for the
    settings and for the native core (lock screen, wake-up). The provider is
    handed its time (`clock`); the system's clock is never read or changed.
    Run by tools/habits-test:

      QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_habitsprovider.qml
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/providers"
import "../org.phobby.dynamicisland/contents/ui/Habits.js" as Habits

Item {
    id: root
    width: 400
    height: 140

    Theme { id: islandTheme }
    ActivityManager { id: activities }
    // the widget's settings
    QtObject {
        id: settings
        property string habitsData: ""
        property string habitsReviewTime: "21:30"
        property bool habitsReminder: true
        property int habitsColorSource: 0
    }
    // what NativeBridge.qml tells about the lock screen and the sleep
    QtObject {
        id: nativeCore
        property bool screenLocked: false
        signal screenUnlocked()
        signal resumed()
    }
    // the moment the provider is told
    property var moment: new Date(2026, 9, 5, 9, 0)
    Component {
        id: providerComponent
        HabitsProvider {
            manager: activities
            theme: islandTheme
            cfg: settings
            core: nativeCore
            clock: () => root.moment
        }
    }
    SignalSpy { id: openedSpy; signalName: "opened" }

    TestCase {
        name: "HabitsProvider"
        when: windowShown

        // October 2026: the 5th is a Monday.
        readonly property string mon: "2026-10-05"
        readonly property string tue: "2026-10-06"
        readonly property string wed: "2026-10-07"
        readonly property var five: ["Birinci alışkanlık", "İkinci alışkanlık", "Üçüncü alışkanlık", "Dördüncü alışkanlık", "Beşinci alışkanlık"]
        function at(day, hour, minute) { return new Date(2026, 9, day, hour, minute || 0); }

        function start() {
            const provider = createTemporaryObject(providerComponent, root);
            verify(provider !== null);
            openedSpy.target = provider;
            openedSpy.clear();
            return provider;
        }
        // The shell is told a new time, and its half-minute tick comes.
        function pass(provider, date) {
            root.moment = date;
            provider.tick();
        }
        function refOf(provider, key, name) { return Habits.items(provider.record, key).find(i => i.name === name).ref; }
        function waiting() { return activities.live.find(a => a.activityId === "habits") ?? null; }
        function shown() { return activities.currentEvent !== null && activities.currentEvent.key === "habits"; }
        function quiet() {
            wait(60);
            return activities.currentEvent === null && activities.queue.length === 0;
        }
        function settle() { wait(30); }

        function init() {
            Lang.setting = "en";
            activities.warm = true;
            activities.dismissEvent();
            activities.queue = [];
            activities.registered = [];
            activities.update();
            settings.habitsData = "";
            settings.habitsReviewTime = "21:30";
            settings.habitsReminder = true;
            nativeCore.screenLocked = false;
            root.moment = at(5, 9);
        }

        function test_asked_at_the_review_time_once() {
            const p = start();
            for (const name of five) p.addHabit(name);
            for (const name of ["İkinci alışkanlık", "Üçüncü alışkanlık", "Beşinci alışkanlık"]) p.setDone(mon, refOf(p, mon, name), true);
            compare(Habits.cell(p.record, mon).level, 3);
            pass(p, at(5, 21, 29));
            compare(p.pending, "");
            verify(quiet(), "nothing before the time");
            verify(waiting() === null);

            pass(p, at(5, 21, 30));
            compare(p.pending, mon);
            tryVerify(shown);
            compare(activities.currentEvent.title, "How was today?");
            compare(activities.currentEvent.subtitle, "3/5 checked");
            compare(activities.currentEvent.trailing.text, "Review");
            compare(p.record.told, mon);

            // ignored: the event goes, the activity waits at the lowest priority
            activities.dismissEvent();
            settle();
            verify(waiting() !== null, "the activity waits");
            compare(activities.rank(waiting().category), activities.order.length);
            compare(waiting().trailingText, "3/5");
            pass(p, at(5, 21, 31));
            pass(p, at(5, 23, 0));
            verify(quiet(), "asked once");

            // the Review button of the waiting activity
            waiting().actions[0].trigger();
            compare(openedSpy.count, 1);
            compare([p.reviewDay, p.reviewStep], [mon, 1]);
            p.continueReview();
            compare(p.reviewStep, 3);
            p.finishReview();
            compare(p.pending, "");
            settle();
            verify(waiting() === null, "the activity is gone after the review");
            compare(Habits.cell(p.record, mon).reviewed, true);
        }

        function test_shell_not_running_at_the_time_asks_at_the_next_start() {
            let p = start();
            for (const name of five) p.addHabit(name);
            for (const name of ["İkinci alışkanlık", "Üçüncü alışkanlık"]) p.setDone(mon, refOf(p, mon, name), true);
            pass(p, at(5, 20, 0));
            // plasmashell is closed before the review time…
            p.destroy();
            wait(0);
            verify(quiet());
            compare(Habits.parse(settings.habitsData).told, "");

            // …and started again on Tuesday morning.
            root.moment = at(6, 8, 10);
            p = start();
            compare(p.today, tue);
            compare(Habits.items(p.record, tue).length, 5, "Tuesday's list was made at the start");
            compare(p.pending, mon);
            tryVerify(shown);
            compare(activities.currentEvent.title, "How was yesterday?");
            compare(activities.currentEvent.subtitle, "2/5 checked");

            // "Review" on the event: the island opens on the review of Monday
            activities.activateEvent();
            compare(openedSpy.count, 1);
            compare([p.reviewDay, p.reviewStep, p.reviewTarget], [mon, 1, tue]);
            p.setDone(mon, refOf(p, mon, "Beşinci alışkanlık"), true);
            p.continueReview();
            p.finishReview();

            const monday = Habits.cell(p.record, mon), tuesday = Habits.cell(p.record, tue);
            compare([monday.done, monday.total, monday.level, monday.reviewed], [3, 5, 3, true], "the answer is Monday's");
            compare([tuesday.done, tuesday.total, tuesday.reviewed, tuesday.known], [0, 5, false, false], "Tuesday is untouched");
            compare(p.pending, "");
            pass(p, at(6, 21, 30));
            compare(p.pending, tue);
            tryVerify(shown);
            compare(activities.currentEvent.title, "How was today?");
        }

        function test_locked_at_the_time_asks_at_the_unlock() {
            const p = start();
            for (const name of five) p.addHabit(name);
            nativeCore.screenLocked = true;
            pass(p, at(5, 21, 30));
            compare(p.pending, mon);
            verify(quiet(), "not into a locked screen");
            compare(p.record.told, "");
            pass(p, at(5, 22, 15));
            verify(quiet());

            root.moment = at(5, 22, 40);
            nativeCore.screenLocked = false;
            nativeCore.screenUnlocked();
            tryVerify(shown);
            compare(activities.currentEvent.title, "How was today?");
            compare(p.record.told, mon);
        }

        function test_asleep_at_the_time_asks_after_the_wakeup_and_the_unlock() {
            const p = start();
            for (const name of five) p.addHabit(name);
            p.setDone(mon, refOf(p, mon, "İkinci alışkanlık"), true);
            pass(p, at(5, 19, 0));
            // suspended at 19:05, locked; awake again on Tuesday 07:30: no tick came in between
            nativeCore.screenLocked = true;
            root.moment = at(6, 7, 30);
            nativeCore.resumed();
            compare(p.today, tue);
            compare(Habits.items(p.record, tue).length, 5, "the new day's list is made at the wake-up");
            compare(p.pending, mon);
            verify(quiet(), "still locked");

            nativeCore.screenLocked = false;
            nativeCore.screenUnlocked();
            tryVerify(shown);
            compare(activities.currentEvent.title, "How was yesterday?");
            activities.activateEvent();
            p.setDone(mon, refOf(p, mon, "Üçüncü alışkanlık"), true);
            p.continueReview();
            p.finishReview();
            compare([Habits.cell(p.record, mon).done, Habits.cell(p.record, mon).reviewed], [2, true]);
            compare(Habits.cell(p.record, tue).done, 0);
        }

        function test_three_days_missed_only_the_latest_is_asked() {
            root.moment = at(8, 9);                               // Thursday
            let p = start();
            for (const name of five) p.addHabit(name);
            pass(p, at(8, 21, 30));
            tryVerify(shown);
            activities.activateEvent();
            p.continueReview();
            p.finishReview();
            p.destroy();
            wait(0);
            activities.dismissEvent();

            root.moment = at(12, 9);                              // off on Friday, Saturday, Sunday; Monday morning
            p = start();
            compare(p.pending, "2026-10-11");
            tryVerify(shown);
            compare(activities.currentEvent.title, "How was yesterday?");
            activities.activateEvent();
            compare(p.reviewDay, "2026-10-11");
            p.continueReview();
            p.finishReview();
            compare(p.pending, "");
            activities.dismissEvent();
            verify(quiet(), "the older days are not asked");
            compare(["2026-10-09", "2026-10-10", "2026-10-11"].map(k => p.record.days[k].r), [0, 0, 1]);
            compare(["2026-10-09", "2026-10-10"].map(k => Habits.cell(p.record, k).known), [false, false]);

            // filled in later from the calendar: thereby reviewed
            p.setDone("2026-10-09", refOf(p, "2026-10-09", "İkinci alışkanlık"), true);
            compare([Habits.cell(p.record, "2026-10-09").level, p.record.days["2026-10-09"].r], [1, 1]);
            compare(p.record.days["2026-10-10"].r, 0);
        }

        function test_closed_leaves_only_the_dot() {
            const p = start();
            for (const name of five) p.addHabit(name);
            pass(p, at(5, 21, 30));
            tryVerify(shown);
            settle();
            verify(waiting() !== null);
            // the cross on the event
            activities.closeEvent();
            settle();
            verify(waiting() === null, "closed");
            compare(p.record.shut, mon);
            compare(p.pending, mon, "the tab's dot stays");
            compare(Habits.cell(p.record, mon).reviewed, false);
            // the next evening it waits again
            pass(p, at(6, 21, 30));
            tryVerify(shown);
            settle();
            verify(waiting() !== null);
            waiting().actions[1].trigger();                       // "Not now" on the activity
            settle();
            verify(waiting() === null);
            compare(p.pending, tue);
        }

        function test_reminder_off_no_event_no_activity() {
            settings.habitsReminder = false;
            const p = start();
            for (const name of five) p.addHabit(name);
            pass(p, at(5, 21, 30));
            compare(p.pending, mon);
            verify(quiet());
            verify(waiting() === null);
            compare(p.record.told, "");
        }

        function test_extra_asked_once_then_permanent() {
            const p = start();
            for (const name of five) p.addHabit(name);
            // Monday evening: an extra for tomorrow
            pass(p, at(5, 21, 30));
            p.startReview(p.pending);
            p.continueReview();
            compare(p.reviewStep, 3, "no extras to ask about on Monday");
            compare(p.addExtra("Pazara git"), false);
            p.finishReview();
            compare(Habits.items(p.record, mon).length, 5);

            pass(p, at(6, 0, 0));
            compare(Habits.items(p.record, tue).map(i => i.name), five.concat(["Pazara git"]));
            // Tuesday evening: asked once
            pass(p, at(6, 21, 30));
            p.startReview(p.pending);
            p.continueReview();
            compare(p.reviewStep, 2);
            compare(Habits.unasked(p.record, tue), [{ index: 0, name: "Pazara git" }]);
            compare(p.answerExtra(0, true), true, "yes: a permanent habit");
            compare(p.reviewStep, 3);
            p.finishReview();

            pass(p, at(7, 0, 0));
            const item = Habits.items(p.record, wed).find(i => i.name === "Pazara git");
            compare(item.extra, false);
            pass(p, at(7, 21, 30));
            p.startReview(p.pending);
            p.continueReview();
            compare(p.reviewStep, 3, "never asked again");
        }

        function test_day_changes_at_midnight() {
            const p = start();
            for (const name of five) p.addHabit(name);
            pass(p, at(5, 23, 59));
            compare(p.today, mon);
            compare(Habits.items(p.record, tue).length, 0);
            pass(p, at(6, 0, 0));
            compare(p.today, tue);
            compare(Habits.items(p.record, tue).length, 5);
            // Monday is still the day to review, and editable
            compare(p.pending, mon);
            p.setDone(mon, refOf(p, mon, "İkinci alışkanlık"), true);
            compare([Habits.cell(p.record, mon).done, p.record.days[mon].r], [1, 0], "the waiting day is not marked by an edit");
        }

        function test_setup_keeps_the_time() {
            const p = start();
            p.addHabit("İkinci alışkanlık");
            compare(p.record.setup, 0);
            p.finishSetup("20:15");
            compare([p.record.setup, settings.habitsReviewTime], [1, "20:15"]);
            pass(p, at(5, 20, 14));
            compare(p.pending, "");
            pass(p, at(5, 20, 15));
            compare(p.pending, mon);
        }
    }
}
