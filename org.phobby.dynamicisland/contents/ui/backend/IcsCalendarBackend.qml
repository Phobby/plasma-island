/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Calendar events from iCalendar (.ics) links, e.g. Google Calendar's
    "secret address in iCal format". No Akonadi/PIM needed: every enabled link
    is downloaded periodically and parsed off the GUI thread by IcsWorker.js
    (ical.js: recurrence rules, overrides, time zones).

    `sourcesJson` is a JSON list of { id, type, url, name, color, enabled };
    Google and iCloud links are read the same way, `type` is for the settings UI.
    `events` holds today's and tomorrow's occurrences, sorted by start; see
    IcsWorker.js for the fields. A link that fails to download keeps showing
    its last good copy.
*/
import QtQuick

Item {
    id: calendar

    property bool enabled: true
    property string sourcesJson: "[]"
    property int refreshMinutes: 5

    readonly property var sources: {
        let list = [];
        try { list = JSON.parse(sourcesJson || "[]"); } catch (e) { list = []; }
        if (!Array.isArray(list)) return [];
        return list.filter(s => s && typeof s.url === "string" && s.url.trim().length > 0 && s.enabled !== false)
                   .map(s => ({ id: String(s.id || s.url), url: normalize(s.url), name: String(s.name || ""), color: String(s.color || "#0a84ff") }));
    }
    readonly property bool available: enabled && sources.length > 0

    property var events: []
    // url → error message of the last attempt (download or parse)
    property var errors: ({})
    property bool loaded: false
    property real lastUpdated: 0
    // JSON { source id: { t: ms, error } } after every download, for the settings page.
    property string statusJson: "{}"

    property var cache: ({})      // url → last good iCalendar text
    property int seq: 0

    function normalize(url: string): string {
        return url.trim().replace(/^webcals?:\/\//i, "https://");
    }

    function refresh(): void {
        const run = ++seq;
        const list = sources;
        if (!available) { events = []; errors = ({}); loaded = false; return; }
        const failed = {};
        let pending = list.length;
        const done = () => {
            if (--pending > 0 || run !== seq) return;
            errors = failed;
            parse();
        };
        for (const s of list) {
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
            xhr.send();
        }
    }

    // Re-expands the cached files without downloading (also rolls the window).
    function parse(): void {
        const now = new Date();
        const from = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const to = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2).getTime();
        const list = sources.map((s, i) => ({ index: i, name: s.name, color: s.color, text: cache[s.url] || "" }))
                            .filter(s => s.text.length > 0);
        if (!worker.ready) { parsePending = true; return; }
        worker.sendMessage({ seq: seq, from: from, to: to, sources: list });
    }
    property bool parsePending: false

    WorkerScript {
        id: worker
        // The parser (280 kB) is only loaded once a calendar is connected.
        source: calendar.available ? "IcsWorker.js" : ""
        onReadyChanged: if (ready && calendar.parsePending) { calendar.parsePending = false; calendar.parse(); }
        onMessage: message => {
            if (message.seq !== calendar.seq || !calendar.available) return;
            const failed = Object.assign({}, calendar.errors);
            for (const i in message.errors) {
                const s = calendar.sources[Number(i)];
                if (s) failed[s.url] = message.errors[i];
            }
            calendar.errors = failed;
            calendar.events = message.events;
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
