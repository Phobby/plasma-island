/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The user's Google account: every calendar is read, events can be added and
    deleted (Google Calendar API). Google only allows this through OAuth: the
    user signs in in the browser and approves, the browser is sent back to a
    local port (native LoopbackServer) with a code that is exchanged for
    tokens. No Google password ever reaches the island.

    OAuth needs a client registered in Google Cloud ("Desktop app"):
    `clientId` / `clientSecret`. `accountJson` is
    { user, calendars: [{ id, name, color, writable }] } and is stored in the
    widget configuration; the refresh token lives in KWallet (native core)
    and, without it, only in memory until the shell restarts.
*/
import QtQuick

QtObject {
    id: google

    property string clientId: ""
    property string clientSecret: ""
    property string accountJson: "{}"
    property var core: null                 // NativeBridge
    property string refreshToken: ""
    property string accessToken: ""
    property real expiresAt: 0

    property string authUrl: "https://accounts.google.com/o/oauth2/v2/auth"
    property string tokenUrl: "https://oauth2.googleapis.com/token"
    property string userUrl: "https://www.googleapis.com/oauth2/v3/userinfo"
    property string apiUrl: "https://www.googleapis.com/calendar/v3"
    readonly property string scope: "https://www.googleapis.com/auth/calendar email"

    readonly property var account: {
        let a = {};
        try { a = JSON.parse(accountJson || "{}") || {}; } catch (e) { a = {}; }
        return { user: String(a.user || ""), calendars: Array.isArray(a.calendars) ? a.calendars.filter(c => c && typeof c.id === "string") : [] };
    }
    // A client is registered and the browser can be sent back here.
    readonly property bool configured: clientId.trim().length > 0
    readonly property bool canSignIn: configured && core !== null && core.loopback !== null
    readonly property bool connected: account.user.length > 0 && account.calendars.length > 0
    readonly property bool ready: configured && connected && refreshToken.length > 0
    readonly property var writableCalendars: account.calendars.filter(c => c.writable)

    function secretKey(user: string): string { return "google:" + user; }
    readonly property string walletUser: core && core.secretsAvailable ? account.user : ""
    onWalletUserChanged: {
        const user = walletUser;
        if (user.length === 0 || refreshToken.length > 0) return;
        core.readSecret(secretKey(user), (ok, value) => { if (ok && value && google.account.user === user && google.refreshToken.length === 0) google.refreshToken = value; });
    }

    // ---- HTTP --------------------------------------------------------------------
    function form(fields: var): string {
        const parts = [];
        for (const k in fields) parts.push(encodeURIComponent(k) + "=" + encodeURIComponent(fields[k]));
        return parts.join("&");
    }
    // done(status, object); status 0 = no connection
    function send(method: string, url: string, headers: var, body: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            let data = {};
            try { data = JSON.parse(xhr.responseText || "{}") || {}; } catch (e) { data = {}; }
            done(xhr.status, data);
        };
        xhr.open(method, url);
        for (const name in headers) xhr.setRequestHeader(name, headers[name]);
        if (body.length > 0) xhr.send(body); else xhr.send();
    }
    function problem(status: int, data: var): string {
        if (status === 0) return i18n("No connection.");
        const detail = data && data.error ? (typeof data.error === "string" ? (data.error_description || data.error) : (data.error.message || "")) : "";
        if (status === 401 || detail === "invalid_grant") return i18n("The Google sign-in is no longer valid; connect the account again.");
        return detail.length > 0 ? i18n("Google: %1", detail) : i18n("The server answered %1.", status);
    }
    // A valid access token, renewed with the refresh token when needed. done(token, error)
    function withToken(done: var): void {
        if (accessToken.length > 0 && Date.now() < expiresAt - 60000) { done(accessToken, ""); return; }
        if (refreshToken.length === 0) { done("", i18n("No Google account is connected.")); return; }
        send("POST", tokenUrl, { "Content-Type": "application/x-www-form-urlencoded" },
             form({ grant_type: "refresh_token", refresh_token: refreshToken, client_id: clientId.trim(), client_secret: clientSecret.trim() }), (status, data) => {
            if (status === 200 && data.access_token) {
                accessToken = data.access_token;
                expiresAt = Date.now() + Number(data.expires_in || 3600) * 1000;
                done(accessToken, "");
                return;
            }
            // Access was withdrawn (or the token expired): sign in again.
            if (status === 400 || status === 401) { accessToken = ""; refreshToken = ""; }
            done("", problem(status, data));
        });
    }
    // done(status, object, error)
    function api(method: string, path: string, body: var, done: var): void {
        withToken((token, error) => {
            if (token.length === 0) { done(0, {}, error); return; }
            const headers = { "Authorization": "Bearer " + token };
            if (body !== null) headers["Content-Type"] = "application/json; charset=utf-8";
            send(method, apiUrl + path, headers, body !== null ? JSON.stringify(body) : "", (status, data) => {
                if (status === 401) accessToken = "";
                done(status, data, status >= 200 && status < 300 ? "" : problem(status, data));
            });
        });
    }

    // ---- sign-in -----------------------------------------------------------------
    property bool signingIn: false
    // Every sign-in page opened so far stays valid (state → { verifier, redirect }):
    // the user may finish in an older browser tab, or after pressing "cancel".
    property var pendingSignIns: ({})
    property var signInDone: null
    property int loopbackPort: 0
    readonly property Connections loopbackEvents: Connections {
        target: google.core ? google.core.loopback : null
        function onReceived(query) { google.finishSignIn(query); }
    }
    function randomText(length: int): string {
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
        let out = "";
        for (let i = 0; i < length; ++i) out += chars.charAt(Math.floor(Math.random() * chars.length));
        return out;
    }
    // Opens the browser on Google's consent page. done({ ok, error })
    function signIn(done: var): void {
        if (!canSignIn) { done({ ok: false, error: i18n("Cannot sign in to Google: the client ID or the native module is missing.") }); return; }
        if (loopbackPort <= 0) loopbackPort = core.loopback.start();
        if (loopbackPort <= 0) { done({ ok: false, error: i18n("Could not open the local return address.") }); return; }
        const verifier = randomText(64), state = randomText(24), redirect = "http://127.0.0.1:" + loopbackPort;
        pendingSignIns[state] = { verifier: verifier, redirect: redirect };
        signInDone = done;
        signingIn = true;
        Qt.openUrlExternally(authUrl + "?" + form({
            client_id: clientId.trim(), redirect_uri: redirect, response_type: "code", scope: scope,
            code_challenge: core.loopback.challenge(verifier), code_challenge_method: "S256",
            state: state, access_type: "offline", prompt: "consent"
        }));
    }
    // For a page that may be gone when the browser comes back: the outcome is
    // in `ready` and `signInError`.
    property string signInError: ""
    function startSignIn(): void {
        signInError = "";
        signIn(result => {
            google.signInError = result.error;
            if (!result.ok) console.warn("org.phobby.dynamicisland: Google sign-in failed:", result.error);
        });
    }
    // Only stops waiting on screen; a page already open in the browser still works.
    function cancelSignIn(): void {
        signingIn = false;
    }
    function stopListening(): void {
        if (core && core.loopback) core.loopback.stop();
        loopbackPort = 0;
        pendingSignIns = ({});
        signingIn = false;
    }
    function finishSignIn(query: string): void {
        const args = {};
        for (const part of query.split("&")) {
            const i = part.indexOf("=");
            if (i > 0) args[decodeURIComponent(part.slice(0, i))] = decodeURIComponent(part.slice(i + 1).replace(/\+/g, " "));
        }
        const p = pendingSignIns[args.state];
        if (!p) return;                                      // not our request
        delete pendingSignIns[args.state];
        signingIn = false;
        const finished = signInDone || (() => {});
        const fail = error => finished({ ok: false, error: error });
        if (!args.code) { fail(args.error === "access_denied" ? i18n("Access was not granted.") : i18n("Google did not send a sign-in code.")); return; }
        send("POST", tokenUrl, { "Content-Type": "application/x-www-form-urlencoded" },
             form({ grant_type: "authorization_code", code: args.code, code_verifier: p.verifier, redirect_uri: p.redirect,
                    client_id: clientId.trim(), client_secret: clientSecret.trim() }), (status, data) => {
            if (status !== 200 || !data.access_token) { fail(problem(status, data)); return; }
            if (!data.refresh_token) { fail(i18n("Google did not grant lasting access; try again.")); return; }
            const token = data.access_token, refresh = data.refresh_token;
            send("GET", userUrl, { "Authorization": "Bearer " + token }, "", (s2, user) => {
                if (s2 !== 200 || !user.email) { fail(problem(s2, user)); return; }
                accessToken = token;
                expiresAt = Date.now() + Number(data.expires_in || 3600) * 1000;
                refreshToken = refresh;
                loadCalendars(result => {
                    if (!result.ok) { accessToken = ""; refreshToken = ""; fail(result.error); return; }
                    accountJson = JSON.stringify({ user: user.email, calendars: result.calendars });
                    if (core && core.secretsAvailable) core.writeSecret(secretKey(user.email), refresh, () => {});
                    stopListening();
                    finished({ ok: true, error: "" });
                });
            });
        });
    }
    function disconnect(): void {
        stopListening();
        if (core && core.secretsAvailable && account.user.length > 0) core.removeSecret(secretKey(account.user));
        accessToken = ""; refreshToken = ""; expiresAt = 0;
        accountJson = "{}";
    }

    // ---- calendars and events ------------------------------------------------------
    // The calendars shown in Google Calendar. done({ ok, calendars, error })
    function loadCalendars(done: var): void {
        api("GET", "/users/me/calendarList?maxResults=250", null, (status, data, error) => {
            if (error.length > 0) { done({ ok: false, calendars: [], error: error }); return; }
            const calendars = (data.items || []).filter(c => c.selected !== false && !c.deleted).map(c => ({
                id: String(c.id), name: String(c.summaryOverride || c.summary || i18n("Calendar")),
                color: /^#[0-9a-f]{6}$/i.test(c.backgroundColor || "") ? c.backgroundColor.toLowerCase() : "#0a84ff",
                writable: c.accessRole === "owner" || c.accessRole === "writer"
            }));
            if (calendars.length === 0) done({ ok: false, calendars: [], error: i18n("No calendar was found in this account.") });
            else done({ ok: true, calendars: calendars, error: "" });
        });
    }
    function plain(html: string): string {
        return html.replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>/gi, "\n").replace(/<a\s[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/gi, (m, href, label) => label.indexOf("http") === 0 ? label : label + " " + href)
                   .replace(/<[^>]+>/g, "").replace(/&nbsp;/g, " ").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }
    function timeOf(point: var): real {
        if (!point) return NaN;
        if (point.dateTime) return new Date(point.dateTime).getTime();
        const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(point.date || "");
        return m ? new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])).getTime() : NaN;
    }
    // Occurrences between from and to (ms), recurring events expanded by Google.
    // `source` is the index the island lists this calendar under. done(events, error)
    function listEvents(calendar: var, source: int, from: real, to: real, done: var): void {
        const events = [];
        const page = token => {
            const query = form({ timeMin: new Date(from).toISOString(), timeMax: new Date(to).toISOString(), singleEvents: "true",
                                 orderBy: "startTime", maxResults: "2500" }) + (token ? "&pageToken=" + encodeURIComponent(token) : "");
            api("GET", "/calendars/" + encodeURIComponent(calendar.id) + "/events?" + query, null, (status, data, error) => {
                if (error.length > 0) { done(events, error); return; }
                for (const item of data.items || []) {
                    if (item.status === "cancelled") continue;
                    const start = timeOf(item.start), end = timeOf(item.end);
                    if (isNaN(start)) continue;
                    const notes = plain(String(item.description || "")).slice(0, 600), location = String(item.location || "").replace(/\s*\n\s*/g, ", ").trim();
                    const url = /https?:\/\/[^\s<>"'\\)]+/i.exec(location + "\n" + notes);
                    events.push({
                        key: source + ":" + item.id, uid: String(item.iCalUID || item.id), title: String(item.summary || "").trim(),
                        start: start, end: isNaN(end) ? start : Math.max(start, end), allDay: !!(item.start && item.start.date), todo: false,
                        recurring: !!item.recurringEventId, location: location, notes: notes,
                        link: String(item.hangoutLink || (url ? url[0] : "")),
                        calendar: calendar.name, color: calendar.color, source: source,
                        // What deleteEvent needs; a whole series is deleted through its parent.
                        google: { calendarId: calendar.id, eventId: String(item.recurringEventId || item.id) }
                    });
                }
                if (data.nextPageToken) page(data.nextPageToken); else done(events, "");
            });
        };
        page("");
    }
    function pad(n: int): string { return n < 10 ? "0" + n : String(n); }
    function dateText(t: real): string {
        const d = new Date(t);
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
    }
    // event: { title, start, end (ms; all-day: local midnights, end exclusive), allDay, location, notes }
    // done({ ok, error })
    function createEvent(calendar: var, event: var, done: var): void {
        const body = { summary: event.title };
        if (event.allDay) { body.start = { date: dateText(event.start) }; body.end = { date: dateText(event.end) }; }
        else { body.start = { dateTime: new Date(event.start).toISOString() }; body.end = { dateTime: new Date(event.end).toISOString() }; }
        if (event.location) body.location = event.location;
        if (event.notes) body.description = event.notes;
        api("POST", "/calendars/" + encodeURIComponent(calendar.id) + "/events", body, (status, data, error) => done({ ok: error.length === 0, error: error }));
    }
    function deleteEvent(calendarId: string, eventId: string, done: var): void {
        api("DELETE", "/calendars/" + encodeURIComponent(calendarId) + "/events/" + encodeURIComponent(eventId), null, (status, data, error) => {
            // 410: already gone
            done({ ok: error.length === 0 || status === 410, error: status === 410 ? "" : error });
        });
    }
}
