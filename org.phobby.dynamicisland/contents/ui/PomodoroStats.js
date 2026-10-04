/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Pomodoro statistics: completed focus rounds per day, kept as a small JSON
    text in the widget's settings (`pomodoroStats`), nothing else to install or
    open: { days: { "YYYY-MM-DD": rounds }, total, best }.

    `days` only holds the last year (enough for the week and the streaks);
    `total` and `best` (the longest streak, in days) carry on beyond it.
    Every function takes the day it is asked about, so nothing here reads the
    clock.
*/
.pragma library

const KEEP_DAYS = 370;

function dayKey(date) {
    const two = n => (n < 10 ? "0" : "") + n;
    return date.getFullYear() + "-" + two(date.getMonth() + 1) + "-" + two(date.getDate());
}
// The day `offset` days from `date` (noon: never trips over a clock change).
function shifted(date, offset) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + offset, 12);
}

function parse(json) {
    const out = { days: {}, total: 0, best: 0 };
    try {
        const given = JSON.parse(json || "{}");
        if (given && typeof given === "object") {
            for (const key in given.days || {}) {
                const n = Math.floor(Number(given.days[key]));
                if (/^\d{4}-\d{2}-\d{2}$/.test(key) && n > 0) out.days[key] = n;
            }
            out.total = Math.max(0, Math.floor(Number(given.total)) || 0);
            out.best = Math.max(0, Math.floor(Number(given.best)) || 0);
        }
    } catch (e) {}
    let sum = 0;
    for (const key in out.days) sum += out.days[key];
    out.total = Math.max(out.total, sum);
    return out;
}

function count(stats, date) { return stats.days[dayKey(date)] || 0; }

// Days in a row with at least one round, ending on `date`; a day that has none
// yet does not break the row that ended the day before.
function streak(stats, date) {
    let day = count(stats, date) > 0 ? date : shifted(date, -1), n = 0;
    while (count(stats, day) > 0) { ++n; day = shifted(day, -1); }
    return n;
}
function bestStreak(stats, date) { return Math.max(stats.best, streak(stats, date)); }

// Monday to Sunday of the week `date` is in.
function week(stats, date) {
    const monday = shifted(date, -((date.getDay() + 6) % 7));
    let n = 0;
    for (let i = 0; i < 7; ++i) n += count(stats, shifted(monday, i));
    return n;
}
// The seven days up to `date`, oldest first: [{ date, count }]
function lastSeven(stats, date) {
    const out = [];
    for (let i = 6; i >= 0; --i) { const day = shifted(date, -i); out.push({ date: day, count: count(stats, day) }); }
    return out;
}

// One more completed focus round on `date`: the new statistics.
function record(stats, date) {
    const next = parse(JSON.stringify(stats));
    const key = dayKey(date);
    next.days[key] = (next.days[key] || 0) + 1;
    next.total += 1;
    next.best = Math.max(next.best, streak(next, date));
    const oldest = dayKey(shifted(date, -KEEP_DAYS));
    for (const k in next.days) if (k < oldest) delete next.days[k];
    return next;
}
