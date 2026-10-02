/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Calendar events from iCalendar (.ics) links, e.g. Google Calendar's
    "secret address in iCal format". No Akonadi/PIM needed: every enabled link
    is downloaded periodically and parsed off the GUI thread by IcsWorker.js
    (ical.js: recurrence rules, overrides, time zones).

    `sourcesJson` is a JSON list of { id, type, url, name, color, enabled };
    Google and iCloud links are read the same way, `type` is for the settings UI.
    With a signed-in account (`client`, CalDavClient) every calendar of the
    account is read as well, file by file, without any link; an event that is
    in both is listed once, as the link shows it. A Google account (`google`,
    GoogleCalendar) is read through Google's API, which expands the events
    itself; those skip the parser and are merged with its result.
    `events` holds today's and tomorrow's occurrences, sorted by start; see
    IcsWorker.js for the fields. `rangeEvents` additionally covers the days a
    month view asked for with setView(). A link that fails to download keeps
    showing its last good copy.
*/
import QtQuick

Item {
    id: calendar

    property bool enabled: true
    property string sourcesJson: "[]"
    property int refreshMinutes: 5

    property var client: null               // CalDavClient
    readonly property var linkSources: {
        let list = [];
        try { list = JSON.parse(sourcesJson || "[]"); } catch (e) { list = []; }
        if (!Array.isArray(list)) return [];
        return list.filter(s => s && typeof s.url === "string" && s.url.trim().length > 0 && s.enabled !== false)
                   .map(s => ({ id: String(s.id || s.url), url: normalize(s.url), name: String(s.name || ""), color: String(s.color || "#0a84ff"), account: "" }));
    }
    property var google: null               // GoogleCalendar
    readonly property var accountSources: client && client.ready
        ? client.account.calendars.map(c => ({ id: c.url, url: c.url, name: String(c.name || ""), color: String(c.color || "#0a84ff"), account: "apple" }))
        : []
    readonly property var googleSources: google && google.ready
        ? google.account.calendars.map(c => ({ id: "google:" + c.id, url: "google:" + c.id, name: c.name, color: c.color, account: "google", calendar: c }))
        : []
    // Links first: of an event that is in both, the link's copy is kept.
    readonly property var sources: linkSources.concat(accountSources, googleSources)
    readonly property bool available: enabled && sources.length > 0

    property var events: []
    // Every occurrence between today and the days requested by setView().
    property var rangeEvents: []
    property real viewFrom: 0
    property real viewTo: 0
    // The days (ms, [from, to)) a month view shows; expanded without downloading.
    function setView(from: real, to: real): void {
        if (from === viewFrom && to === viewTo) return;
        viewFrom = from;
        viewTo = to;
        if (!available || !loaded) return;
        // Google's events are only here for the months around the last view.
        if (googleSources.length > 0 && (from < googleFrom || to > googleTo)) refresh(); else parse();
    }
    // url → error message of the last attempt (download or parse)
    property var errors: ({})
    property bool loaded: false
    property real lastUpdated: 0
    // JSON { source id: { t: ms, error } } after every download, for the settings page.
    property string statusJson: "{}"

    property var cache: ({})      // url → last good iCalendar text
    property var files: ({})      // account calendar url → { file url: { etag, text } }
    // Google: source url → occurrences, downloaded for the days [googleFrom, googleTo)
    property var googleEvents: ({})
    property real googleFrom: 0
    property real googleTo: 0
    readonly property int parallel: 6

    // One calendar of the account: lists its event files, downloads the new
    // and changed ones and joins them into one iCalendar text. done(error)
    function syncCalendar(url: string, done: var): void {
        const dav = client;
        dav.listEvents(url, (status, items) => {
            if (status !== 207) { done(dav.problem(status)); return; }
            const old = files[url] || {}, now = {}, wanted = [];
            for (const f in items) {
                if (old[f] && old[f].etag === items[f]) now[f] = old[f]; else wanted.push(f);
            }
            let running = 0, failed = 0;
            const finish = () => {
                files[url] = now;
                const blocks = [], zones = {};
                for (const f in now) {
                    for (const b of now[f].text.match(/^BEGIN:(VTIMEZONE|VEVENT|VTODO)\r?\n[\s\S]*?^END:\1\r?$/gm) || []) {
                        if (b.indexOf("BEGIN:VTIMEZONE") === 0) { if (zones[b]) continue; zones[b] = true; }
                        blocks.push(b.replace(/\r?$/, ""));
                    }
                }
                cache[url] = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n" + blocks.map(b => b + "\r\n").join("") + "END:VCALENDAR\r\n";
                done(failed > 0 ? i18n("%1 events could not be downloaded", failed) : "");
            };
            const pump = () => {
                if (wanted.length === 0 && running === 0) { finish(); return; }
                while (running < parallel && wanted.length > 0) {
                    const f = wanted.shift();
                    ++running;
                    dav.fetchEvent(f, (code, text) => {
                        --running;
                        if (code === 200 && text.indexOf("BEGIN:VCALENDAR") >= 0) now[f] = { etag: items[f], text: text };
                        else if (old[f]) now[f] = old[f];
                        else ++failed;
                        pump();
                    });
                }
            };
            pump();
        });
    }

    // Changes made here (CalDavClient) show at once; the published link only
    // follows later. Both are forgotten when the shell restarts.
    property var added: []        // [{ uid, text, name, color }] until the link has the event
    property var removed: ({})    // uid → true: deleted events the link may still list
    readonly property int addedBase: 100000      // source index of the first added event
    function addEvent(uid: string, text: string, name: string, color: string): void {
        added = added.concat([{ uid: uid, text: text, name: name, color: color }]);
        if (available) parse();
    }
    function removeEvent(uid: string): void {
        removed[uid] = true;
        added = added.filter(a => a.uid !== uid);
        if (available) parse();
    }
    property int seq: 0

    function normalize(url: string): string {
        return url.trim().replace(/^webcals?:\/\//i, "https://");
    }

    // For moments the user is looking (the Calendar page opens): downloads
    // again unless that just happened, instead of waiting for the timer.
    property real lastRequested: 0
    function refreshIfStale(): void {
        if (available && Date.now() - lastRequested > 20000) refresh();
    }

    function refresh(): void {
        const run = ++seq;
        lastRequested = Date.now();
        const list = sources;
        if (!available) { events = []; rangeEvents = []; errors = ({}); loaded = false; return; }
        const failed = {};
        let pending = list.length;
        const done = () => {
            if (--pending > 0 || run !== seq) return;
            errors = failed;
            parse();
        };
        // Google: a month of slack on both sides, so paging to the next month shows at once.
        const today = new Date(), view = viewTo > viewFrom;
        const first = new Date(view ? Math.min(viewFrom, today.getTime()) : today.getTime()), last = new Date(view ? Math.max(viewTo, today.getTime()) : today.getTime());
        const gFrom = new Date(first.getFullYear(), first.getMonth() - 1, 1).getTime(), gTo = new Date(last.getFullYear(), last.getMonth() + 2, 1).getTime();
        const fresh = {};
        let googleLeft = googleSources.length;
        list.forEach((s, index) => {
            if (s.account !== "google") return;
            google.listEvents(s.calendar, index, gFrom, gTo, (found, error) => {
                if (error.length > 0) { failed[s.url] = error; fresh[s.url] = googleEvents[s.url] || []; }
                else fresh[s.url] = found;
                if (--googleLeft === 0 && run === seq) { googleEvents = fresh; googleFrom = gFrom; googleTo = gTo; }
                done();
            });
        });
        for (const s of list) {
            if (s.account === "google") continue;
            if (s.account === "apple") {
                syncCalendar(s.url, error => { if (error.length > 0) failed[s.url] = error; done(); });
                continue;
            }
            const xhr = new XMLHttpRequest();
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                const text = xhr.responseText || "";
                if (xhr.status === 200 && text.indexOf("BEGIN:VCALENDAR") >= 0) cache[s.url] = text;
                else failed[s.url] = xhr.status === 200 ? i18n("Not an iCalendar file")
                                   : xhr.status > 0 ? i18n("Server answered %1", xhr.status) : i18n("No connection");
                done();
            };
            xhr.open("GET", s.url);
            // Always the server's current copy, never one cached on the way.
            xhr.setRequestHeader("Cache-Control", "no-cache");
            xhr.setRequestHeader("Pragma", "no-cache");
            xhr.send();
        }
    }

    // Re-expands the cached files without downloading (also rolls the window).
    function parse(): void {
        const now = new Date();
        const from = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const to = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2).getTime();
        const list = sources.map((s, i) => ({ index: i, name: s.name, color: s.color, text: cache[s.url] || "" }))
                            .filter(s => s.text.length > 0)
                            .concat(added.map((a, i) => ({ index: addedBase + i, name: a.name, color: a.color, text: a.text })));
        if (!worker.ready) { parsePending = true; return; }
        const view = viewTo > viewFrom;
        worker.sendMessage({ seq: seq, view: ++viewSeq, near: [from, to], sources: list,
                             from: view ? Math.min(from, viewFrom) : from, to: view ? Math.max(to, viewTo) : to });
    }
    property bool parsePending: false
    property int viewSeq: 0

    WorkerScript {
        id: worker
        // The parser (280 kB) is only loaded once a calendar is connected.
        source: calendar.available ? "IcsWorker.js" : ""
        onReadyChanged: if (ready && calendar.parsePending) { calendar.parsePending = false; calendar.parse(); }
        onMessage: message => {
            if (message.seq !== calendar.seq || message.view !== calendar.viewSeq || !calendar.available) return;
            const failed = Object.assign({}, calendar.errors);
            for (const i in message.errors) {
                const s = calendar.sources[Number(i)];
                if (s) failed[s.url] = message.errors[i];
            }
            calendar.errors = failed;
            const from = message.near[0], to = message.near[1];
            // An added event the link has caught up with is listed only once.
            const linked = {}, seen = {};
            // Google's occurrences, already expanded, join the parsed ones.
            const wFrom = message.from, wTo = message.to;
            calendar.sources.forEach((s, index) => {
                if (s.account !== "google") return;
                for (const e of calendar.googleEvents[s.url] || []) {
                    if (e.start < wTo && (e.end > wFrom || e.start >= wFrom)) message.events.push(Object.assign({}, e, { source: index, calendar: s.name, color: s.color }));
                }
            });
            message.events.sort((a, b) => a.start - b.start || a.end - b.end);
            for (const e of message.events) if (e.source < calendar.addedBase) linked[e.uid] = true;
            // The same occurrence from a link and from the account: the first source wins.
            for (const e of message.events) {
                const id = e.uid + "@" + e.start, other = seen[id];
                if (other === undefined || e.source < other) seen[id] = e.source;
            }
            const all = message.events.filter(e => !calendar.removed[e.uid] && seen[e.uid + "@" + e.start] === e.source
                                                   && (e.source < calendar.addedBase || !linked[e.uid]));
            if (calendar.added.some(a => linked[a.uid])) calendar.added = calendar.added.filter(a => !linked[a.uid]);
            calendar.rangeEvents = all;
            calendar.events = all.filter(e => e.start < to && (e.end > from || e.start >= from));
            calendar.lastUpdated = Date.now();
            calendar.loaded = true;
            const status = {};
            for (const s of calendar.sources) status[s.id] = { t: calendar.lastUpdated, error: failed[s.url] || "" };
            calendar.statusJson = JSON.stringify(status);
        }
    }

    // Only the set of links matters, not every keystroke-level change of the JSON.
    readonly property string signature: available ? sources.map(s => s.url + "|" + s.name + "|" + s.color).join("\n") : ""
    onSignatureChanged: Qt.callLater(refresh)
    Component.onCompleted: Qt.callLater(refresh)

    Timer {
        interval: Math.max(1, calendar.refreshMinutes) * 60000
        repeat: true
        running: calendar.available
        onTriggered: calendar.refresh()
    }
}
