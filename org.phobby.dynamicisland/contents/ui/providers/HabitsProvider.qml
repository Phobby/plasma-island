/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Habits: the record (Habits.js, a JSON text in the settings), the new day's
    list at midnight and the evening review.

    The review of a day is due from the review time on and until the next
    day's time (Habits.due). While one is due and not done:

      * the island asks once, as a transient event ("How was today? 3/5
        checked", with a Review button). Only when somebody can see it: not
        while the session is locked, and after a start or a wake-up the same
        check runs again. So a review that was missed, because the shell was
        not running, the computer was asleep or the screen was locked, is asked
        at the next start, wake-up or unlock, and still belongs to its own day;
      * a Live Activity waits at the lowest priority (its category is not in
        the priority list, so every other activity comes first) until the
        review is done or the activity is closed;
      * `pending` names the day: the dot on the Habits tab.

    What tells that nobody is there: the native core's `screenLocked` /
    `screenUnlocked` (org.freedesktop.ScreenSaver) and `resumed` (logind's
    PrepareForSleep). Without the core the lock is not known and the question
    is simply asked when its time has come; the half-minute tick compares
    wall-clock times, so a start or a wake-up after the time is noticed anyway.

    Nothing but now() reads the clock, and tests replace it (`clock`).
*/
import QtQuick
import ".."
import "../Habits.js" as Habits

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    required property var cfg
    property var core: null                 // NativeBridge.qml (optional)
    property bool enabled: true
    property var clock: null                // tests: a function returning the moment
    function now(): var { return typeof clock === "function" ? clock() : new Date(); }

    readonly property var record: Habits.parse(cfg.habitsData)
    readonly property string reviewTime: cfg.habitsReviewTime
    readonly property bool reminder: cfg.habitsReminder
    // The calendar's strongest shade: GitHub's green, or the system's accent colour (kept visible on the island).
    readonly property color tone: cfg.habitsColorSource === 1 ? theme.ensure(theme.accent, theme.surface, 3) : theme.dark ? "#39d353" : "#216e39"

    // The moment of the last tick: what "today" and "due" are measured by.
    property var moment: now()
    readonly property string today: Habits.dayKey(moment)
    // The day whose evening review is waiting ("" = none).
    readonly property string pending: enabled ? Habits.due(record, moment, reviewTime) : ""
    readonly property var pendingCounts: Habits.counts(record, pending)
    readonly property bool locked: core !== null && core.screenLocked === true

    function store(next: var): void {
        if (next === record) return;
        const text = Habits.text(next);
        if (text !== cfg.habitsData) cfg.habitsData = text;
    }
    // The new day's list (midnight, or the first start after it) and what is due.
    property bool ready: false
    function tick(): void {
        if (!enabled || !ready) return;
        moment = now();
        store(Habits.roll(record, moment));
        announce();
    }

    function question(key: string): string {
        return key === today ? Lang.i18n("How was today?")
             : key === Habits.keyShift(today, -1) ? Lang.i18n("How was yesterday?")
             : Lang.i18n("How was %1?", Habits.dateOf(key || today).toLocaleDateString(Lang.locale, "d MMMM"));
    }
    // Asked once per day, and never into a locked screen or the island's first
    // moments (where events are dropped): it would count as asked.
    function announce(): void {
        const key = pending;
        if (!enabled || !ready || !reminder || key === "" || record.told === key || locked || !manager.warm) return;
        manager.flash({
            key: "habits",
            icon: "view-calendar-tasks",
            color: tone,
            title: question(key),
            subtitle: Lang.i18n("%1/%2 checked", pendingCounts.done, pendingCounts.total),
            trailing: { type: "button", text: Lang.i18nc("@action:button start the evening review of the habits", "Review") },
            activate: () => provider.startReview(key),
            closed: () => provider.dismiss(key),
            duration: 8000
        });
        store(Habits.note(record, "told", key));
    }
    // The waiting activity is closed: only the dot on the tab stays.
    function dismiss(key: string): void {
        if (key !== "") store(Habits.note(record, "shut", key));
    }

    // ---- the evening review --------------------------------------------------------
    // Its day and step (1 the day's list, 2 the extras one by one, 3 extras for
    // the day after) are kept here, so the island may close in between.
    property string reviewDay: ""
    property int reviewStep: 0
    readonly property string reviewTarget: reviewDay === "" ? "" : Habits.keyShift(reviewDay, 1)
    // The island is to open on the Habits page.
    signal opened()

    function startReview(key: string): void {
        if (key === "" || record.days[key] === undefined) return;
        reviewDay = key;
        reviewStep = 1;
        opened();
    }
    function continueReview(): void {
        if (reviewStep === 1 || reviewStep === 2) reviewStep = Habits.unasked(record, reviewDay).length > 0 ? 2 : 3;
    }
    // The answer to "tomorrow as well?" for an extra; true when it became a permanent habit.
    function answerExtra(index: int, again: bool): bool {
        const before = Habits.active(record).length;
        store(Habits.answerExtra(record, reviewDay, index, again));
        continueReview();
        return Habits.active(record).length > before;
    }
    // An extra for the day after the reviewed one; true when it became a permanent habit.
    function addExtra(name: string): bool {
        const before = Habits.active(record).length;
        store(Habits.addExtra(record, name, reviewTarget));
        return Habits.active(record).length > before;
    }
    function dropExtra(name: string): void { store(Habits.dropExtra(record, name, reviewTarget)); }
    function finishReview(): void {
        store(Habits.review(record, reviewDay));
        reviewDay = "";
        reviewStep = 0;
    }
    function leaveReview(): void {
        reviewDay = "";
        reviewStep = 0;
    }

    // ---- the lists -----------------------------------------------------------------
    function setDone(key: string, ref: string, done: bool): void {
        let next = Habits.setDone(record, key, ref, done);
        // An earlier day corrected from the calendar is thereby reviewed
        // (not the one that is still to be asked in full).
        if (key < today && key !== pending) next = Habits.review(next, key);
        store(next);
    }
    function dropFromDay(key: string, ref: string): void {
        let next = Habits.dropFromDay(record, key, ref);
        if (key < today && key !== pending) next = Habits.review(next, key);
        store(next);
    }
    function markReviewed(key: string): void { store(Habits.review(record, key)); }
    function addHabit(name: string): bool {
        const before = Habits.active(record).length;
        store(Habits.addHabit(record, name, now()));
        return Habits.active(record).length > before;
    }
    function deleteHabit(id: int): void { store(Habits.deleteHabit(record, id, now())); }
    function finishSetup(time: string): void {
        if (cfg.habitsReviewTime !== time) cfg.habitsReviewTime = time;
        store(Habits.finishSetup(record));
    }

    // ---- when to look --------------------------------------------------------------
    // Every half minute: late by that much at most, and right again after a
    // suspend however long it was.
    Timer {
        interval: 30000
        repeat: true
        running: provider.enabled
        onTriggered: provider.tick()
    }
    Component.onCompleted: { ready = true; tick(); }
    onEnabledChanged: tick()
    onClockChanged: tick()
    onReviewTimeChanged: tick()
    // Later, not from inside the change: announcing writes the record these depend on.
    onReminderChanged: Qt.callLater(announce)
    onPendingChanged: Qt.callLater(announce)
    // The screen was unlocked.
    onLockedChanged: tick()
    Connections {
        target: provider.core
        ignoreUnknownSignals: true
        function onScreenUnlocked() { provider.tick(); }
        function onResumed() { provider.tick(); }
    }
    Connections {
        target: provider.manager
        function onWarmChanged() { provider.tick(); }
    }

    Activity {
        activityId: "habits"
        category: "habits"
        priority: -10
        active: provider.enabled && provider.reminder && provider.pending !== "" && provider.record.shut !== provider.pending
        icon: "view-calendar-tasks"
        color: provider.tone
        title: provider.question(provider.pending)
        subtitle: Lang.i18n("%1/%2 checked", provider.pendingCounts.done, provider.pendingCounts.total)
        trailingText: provider.pendingCounts.done + "/" + provider.pendingCounts.total
        actions: [
            { icon: "dialog-ok-apply-symbolic", text: Lang.i18nc("@action:button start the evening review of the habits", "Review"),
              trigger: () => provider.startReview(provider.pending) },
            { icon: "window-close-symbolic", text: Lang.i18nc("@action:button close the waiting evening review", "Not now"),
              trigger: () => provider.dismiss(provider.pending) }
        ]
        onClicked: provider.startReview(provider.pending)
        Component.onCompleted: provider.manager.register(this)
    }
}
