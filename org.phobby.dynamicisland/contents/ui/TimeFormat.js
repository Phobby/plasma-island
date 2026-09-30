// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

// 75 → "1:15", 3725 → "1:02:05"
function clock(seconds) {
    const s = Math.max(0, Math.ceil(seconds));
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), ss = s % 60;
    const two = n => (n < 10 ? "0" : "") + n;
    return h > 0 ? h + ":" + two(m) + ":" + two(ss) : m + ":" + two(ss);
}

// milliseconds → "1:02.34"
function stopwatch(ms) {
    const total = Math.max(0, Math.floor(ms / 10));
    const cs = total % 100, s = Math.floor(total / 100) % 60, m = Math.floor(total / 6000);
    const two = n => (n < 10 ? "0" : "") + n;
    return m + ":" + two(s) + "." + two(cs);
}
