/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Writes to the user's calendars over CalDAV (Apple iCloud): the .ics links
    of IcsCalendarBackend are read-only, so adding or deleting an event needs
    the account itself. iCloud wants the Apple ID and an app-specific password
    (account.apple.com → Sign-In and Security → App-Specific Passwords).

    `accountJson` is { server, user, calendars: [{ url, name, color }], defaultUrl }
    and is stored in the widget configuration; the password lives in KWallet
    (native core) and, without it, only in memory until the shell restarts.
*/
import QtQuick
import ".."

QtObject {
    id: client

    property string accountJson: "{}"
    property var core: null                 // NativeBridge
    property string password: ""

    readonly property string defaultServer: "https://caldav.icloud.com"
    readonly property var account: {
        let a = {};
        try { a = JSON.parse(accountJson || "{}") || {}; } catch (e) { a = {}; }
        return { server: String(a.server || defaultServer), user: String(a.user || ""),
                 calendars: Array.isArray(a.calendars) ? a.calendars.filter(c => c && typeof c.url === "string") : [],
                 defaultUrl: String(a.defaultUrl || "") };
    }
    readonly property bool connected: account.user.length > 0 && account.calendars.length > 0
    // Connected and the password is known: events can be added right away.
    readonly property bool ready: connected && password.length > 0
    readonly property var defaultCalendar: account.calendars.find(c => c.url === account.defaultUrl) || account.calendars[0] || null

    function secretKey(user: string): string { return "caldav:" + user; }
    readonly property string walletUser: core && core.secretsAvailable ? account.user : ""
    onWalletUserChanged: {
        const user = walletUser;
        if (user.length === 0 || password.length > 0) return;
        core.readSecret(secretKey(user), (ok, value) => { if (ok && value && client.account.user === user && client.password.length === 0) client.password = value; });
    }

    // ---- HTTP --------------------------------------------------------------------
    function resolve(base: string, href: string): string {
        if (/^https?:\/\//i.test(href)) return href;
        const origin = /^(https?:\/\/[^\/]+)/i.exec(base);
        return (origin ? origin[1] : "") + (href.charAt(0) === "/" ? "" : "/") + href;
    }
    // done(status, text); status 0 = no connection
    function request(method: string, url: string, user: string, pass: string, headers: var, body: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE) done(xhr.status, xhr.responseText || "");
        };
        xhr.open(method, url);
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(user + ":" + pass));
        for (const name in headers) xhr.setRequestHeader(name, headers[name]);
        if (body.length > 0) xhr.send(body); else xhr.send();
    }
    function propfind(url: string, user: string, pass: string, depth: string, props: string, done: var): void {
        const body = '<?xml version="1.0" encoding="utf-8"?>'
                   + '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:a="http://apple.com/ns/ical/"><d:prop>' + props + '</d:prop></d:propfind>';
        request("PROPFIND", url, user, pass, { "Depth": depth, "Content-Type": "application/xml; charset=utf-8" }, body, done);
    }
    function problem(status: int): string {
        return status === 401 || status === 403 ? Lang.i18n("The Apple ID or app-specific password was not accepted.")
             : status === 0 ? Lang.i18n("No connection.")
             : Lang.i18n("The server answered %1.", status);
    }

    // Tolerant of any namespace prefix: <href>, <d:href>, <D:href>…
    function unescapeXml(text: string): string {
        return text.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
                   .replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, "&").trim();
    }
    function element(xml: string, name: string): string {
        const m = new RegExp("<(?:[\\w-]+:)?" + name + "(?:\\s[^>]*)?>([\\s\\S]*?)</(?:[\\w-]+:)?" + name + ">", "i").exec(xml);
        return m ? m[1] : "";
    }
    function hrefIn(xml: string, name: string): string {
        return unescapeXml(element(element(xml, name), "href"));
    }
    function responses(xml: string): var {
        return xml.match(/<(?:[\w-]+:)?response(?:\s[^>]*)?>[\s\S]*?<\/(?:[\w-]+:)?response>/gi) || [];
    }

    // Signs in and lists the calendars that take events.
    // done({ ok, calendars: [{ url, name, color }], error })
    function discover(server: string, user: string, pass: string, done: var): void {
        const fail = status => done({ ok: false, calendars: [], error: problem(status) });
        const base = server.replace(/\/+$/, "") + "/";
        propfind(base, user, pass, "0", "<d:current-user-principal/>", (s1, t1) => {
            const principal = hrefIn(t1, "current-user-principal");
            if (s1 !== 207 || principal.length === 0) { fail(s1 === 207 ? 404 : s1); return; }
            const principalUrl = resolve(base, principal);
            propfind(principalUrl, user, pass, "0", "<c:calendar-home-set/>", (s2, t2) => {
                const home = hrefIn(t2, "calendar-home-set");
                if (s2 !== 207 || home.length === 0) { fail(s2 === 207 ? 404 : s2); return; }
                const homeUrl = resolve(principalUrl, home);
                propfind(homeUrl, user, pass, "1", "<d:displayname/><d:resourcetype/><a:calendar-color/><c:supported-calendar-component-set/>", (s3, t3) => {
                    if (s3 !== 207) { fail(s3); return; }
                    const calendars = [];
                    for (const r of responses(t3)) {
                        if (!/<(?:[\w-]+:)?calendar(?:\s[^>]*)?\/?>/i.test(element(r, "resourcetype"))) continue;      // iCloud: <calendar xmlns="…"/>
                        const components = element(r, "supported-calendar-component-set");
                        if (components.length > 0 && !/VEVENT/i.test(components)) continue;      // reminder lists
                        const href = unescapeXml(element(r, "href"));
                        if (href.length === 0) continue;
                        const color = /#[0-9a-f]{6}/i.exec(element(r, "calendar-color"));
                        calendars.push({ url: resolve(homeUrl, href).replace(/\/*$/, "/"), name: unescapeXml(element(r, "displayname")) || Lang.i18n("Calendar"),
                                         color: color ? color[0].toLowerCase() : "#0a84ff" });
                    }
                    if (calendars.length === 0) done({ ok: false, calendars: [], error: Lang.i18n("No calendar that takes events was found in this account.") });
                    else done({ ok: true, calendars: calendars, error: "" });
                });
            });
        });
    }

    // ---- reading ----------------------------------------------------------------
    // The event files of a calendar. done(status, { url: etag }); 207 = fine
    function listEvents(calendarUrl: string, done: var): void {
        propfind(calendarUrl, account.user, password, "1", "<d:getetag/>", (status, text) => {
            const items = {};
            if (status === 207) {
                for (const r of responses(text)) {
                    const href = unescapeXml(element(r, "href")), etag = unescapeXml(element(r, "getetag"));
                    if (/\.ics$/i.test(href) && etag.length > 0) items[resolve(calendarUrl, href)] = etag;
                }
            }
            done(status, items);
        });
    }
    function fetchEvent(url: string, done: var): void {
        request("GET", url, account.user, password, {}, "", done);
    }

    // Signs in, then remembers the account (and its password in KWallet).
    // done({ ok, error })
    function connect(user: string, pass: string, done: var): void {
        const server = account.server;
        discover(server, user.trim(), pass.trim(), result => {
            if (!result.ok) { done(result); return; }
            password = pass.trim();
            accountJson = JSON.stringify({ server: server, user: user.trim(), calendars: result.calendars, defaultUrl: result.calendars[0].url });
            if (core && core.secretsAvailable) core.writeSecret(secretKey(user.trim()), password, () => {});
            done({ ok: true, error: "" });
        });
    }
    function disconnect(): void {
        if (core && core.secretsAvailable && account.user.length > 0) core.removeSecret(secretKey(account.user));
        password = "";
        accountJson = JSON.stringify({ server: account.server });
    }
    function setDefaultCalendar(url: string): void {
        const a = account;
        accountJson = JSON.stringify({ server: a.server, user: a.user, calendars: a.calendars, defaultUrl: url });
    }

    // ---- iCalendar ---------------------------------------------------------------
    function pad(n: int): string { return n < 10 ? "0" + n : String(n); }
    function utcStamp(t: real): string {
        const d = new Date(t);
        return d.getUTCFullYear() + pad(d.getUTCMonth() + 1) + pad(d.getUTCDate()) + "T" + pad(d.getUTCHours()) + pad(d.getUTCMinutes()) + pad(d.getUTCSeconds()) + "Z";
    }
    function dateStamp(t: real): string {
        const d = new Date(t);
        return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate());
    }
    function escapeText(text: string): string {
        return text.replace(/\\/g, "\\\\").replace(/;/g, "\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
    }
    // Content lines are at most 75 octets: folded well below that for non-ASCII text.
    function fold(line: string): string {
        const parts = [];
        for (let i = 0; i < line.length; i += 30) parts.push(line.substr(i, 30));
        return parts.join("\r\n ");
    }
    function makeUid(): string {
        const hex = n => { let s = ""; for (let i = 0; i < n; ++i) s += Math.floor(Math.random() * 16).toString(16); return s; };
        return (hex(8) + "-" + hex(4) + "-4" + hex(3) + "-a" + hex(3) + "-" + hex(12)).toUpperCase();
    }
    // event: { title, start, end (ms; all-day: local midnights, end exclusive), allDay, location, notes }
    function makeEvent(uid: string, event: var): string {
        const now = utcStamp(Date.now());
        const lines = ["BEGIN:VEVENT", "UID:" + uid, "DTSTAMP:" + now, "CREATED:" + now, "LAST-MODIFIED:" + now, "SEQUENCE:0",
                       "SUMMARY:" + escapeText(event.title)];
        if (event.allDay) lines.push("DTSTART;VALUE=DATE:" + dateStamp(event.start), "DTEND;VALUE=DATE:" + dateStamp(event.end));
        else lines.push("DTSTART:" + utcStamp(event.start), "DTEND:" + utcStamp(event.end));
        if (event.location) lines.push("LOCATION:" + escapeText(event.location));
        if (event.notes) lines.push("DESCRIPTION:" + escapeText(event.notes));
        lines.push("END:VEVENT");
        return lines.map(fold).join("\r\n") + "\r\n";
    }
    function wrap(vevent: string): string {
        return "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//org.phobby//Dynamic Island//EN\r\nCALSCALE:GREGORIAN\r\n" + vevent + "END:VCALENDAR\r\n";
    }

    // done({ ok, uid, text (the stored iCalendar file), error })
    function createEvent(calendar: var, event: var, done: var): void {
        const uid = makeUid(), text = wrap(makeEvent(uid, event));
        request("PUT", calendar.url + uid + ".ics", account.user, password,
                { "Content-Type": "text/calendar; charset=utf-8", "If-None-Match": "*" }, text, status => {
            if (status === 200 || status === 201 || status === 204) done({ ok: true, uid: uid, text: text, error: "" });
            else done({ ok: false, uid: uid, text: "", error: problem(status) });
        });
    }
    // The event's file is named after its UID (as Apple's own apps do); the
    // calendar it lives in is found by trying each one. done({ ok, error })
    function deleteEvent(uid: string, done: var): void {
        const calendars = account.calendars.slice();
        const next = () => {
            const c = calendars.shift();
            if (!c) { done({ ok: false, error: Lang.i18n("The event was not found in the calendars of the account; delete it on your phone.") }); return; }
            request("DELETE", c.url + encodeURIComponent(uid) + ".ics", account.user, password, {}, "", status => {
                if (status === 200 || status === 204) done({ ok: true, error: "" });
                else if (status === 404 || status === 412) next();
                else done({ ok: false, error: problem(status) });
            });
        };
        next();
    }
}
