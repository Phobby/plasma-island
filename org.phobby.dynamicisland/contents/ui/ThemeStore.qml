/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The theme store: the catalog/ folder of the project's repository, read
    from where it is published (ThemeFile.CATALOG_URL).

    Privacy: nothing is asked on its own. The only requests are the list
    (browse(), when the user opens the store) and one theme file (download(),
    when the user presses Download): plain GETs, no account, no cookies, no
    telemetry, nothing in the background.

    Safety: a downloaded file is taken only when it is at most 64 kB, its
    SHA-256 is the one the list names, and it is a valid theme
    (ThemeFile.parse: data only, unknown fields left out). It is handed back,
    never applied.
*/
import QtQuick
import "ThemeFile.js" as ThemeFile

QtObject {
    id: store

    property string catalogUrl: ThemeFile.CATALOG_URL
    // The address is still the placeholder: there is nothing to ask.
    readonly property bool configured: ThemeFile.configured(catalogUrl)

    // "" (not asked yet) | "loading" | "ready" | "error"
    property string state: ""
    property var entries: []                // ThemeFile.parseIndex(): [{ id, name, author, description, path, sha256, preview }]
    property string error: ""
    property var busy: ({})                 // id → true while its file is downloaded
    // Every request that was made (tests look at this).
    property int requests: 0
    property int seq: 0

    // done(status, bytes): status 0 = no connection, -1 = larger than `limit`.
    function fetch(url: string, limit: int, done: var): void {
        const xhr = new XMLHttpRequest();
        let answered = false;
        const answer = (status, bytes) => { if (!answered) { answered = true; done(status, bytes); } };
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                // Too large by its own account: not downloaded to the end. (Aborting
                // from inside this callback crashes Qt's XMLHttpRequest: a moment later.)
                const length = Number(xhr.getResponseHeader("Content-Length"));
                if (length > limit) { answer(-1, null); Qt.callLater(() => xhr.abort()); }
            } else if (xhr.readyState === XMLHttpRequest.DONE) {
                const bytes = xhr.status === 200 && xhr.response ? new Uint8Array(xhr.response) : null;
                answer(bytes !== null && bytes.length > limit ? -1 : xhr.status, bytes);
            }
        };
        ++requests;
        xhr.open("GET", url);
        xhr.responseType = "arraybuffer";
        xhr.send();
    }
    function problem(status: int): string {
        return status === 0 ? Lang.i18n("No connection: the store could not be reached. Check the network and try again.")
             : status === -1 ? Lang.i18n("The store sent more than it may; nothing was taken.")
             : status === 404 ? Lang.i18n("The store was not found at its address (404).")
             : Lang.i18n("The store answered %1.", status);
    }

    // The list of themes: asked when the user opens the store.
    function browse(): void {
        if (!configured) { state = "error"; error = Lang.i18n("The store has no address yet."); return; }
        const run = ++seq;
        state = "loading"; error = "";
        watchdog.restart();
        fetch(catalogUrl.replace(/\/+$/, "") + "/index.json", ThemeFile.MAX_INDEX_BYTES, (status, bytes) => {
            if (run !== seq) return;
            watchdog.stop();
            if (status !== 200) { state = "error"; error = problem(status); return; }
            const text = ThemeFile.utf8Decode(bytes);
            const list = text === null ? { ok: false } : ThemeFile.parseIndex(text);
            if (!list.ok) { state = "error"; error = list.error === "newer" ? Lang.i18n("The store's list is for a newer version of the island.") : Lang.i18n("The store's list could not be read."); return; }
            entries = list.themes;
            state = "ready";
        });
    }
    readonly property Timer watchdog: Timer {
        interval: 20000
        onTriggered: { ++store.seq; store.state = "error"; store.error = store.problem(0); }
    }

    // One theme of the list: done({ ok, theme, error, field }); the errors are
    // ThemeFile.parse()'s, "checksum", or a sentence about the connection.
    function download(entry: var, done: var): void {
        const mark = on => { const b = Object.assign({}, busy); if (on) b[entry.id] = true; else delete b[entry.id]; busy = b; };
        const fail = (error, field) => { mark(false); done({ ok: false, theme: null, error: error, field: field || "" }); };
        if (!configured) { fail(Lang.i18n("The store has no address yet.")); return; }
        mark(true);
        fetch(catalogUrl.replace(/\/+$/, "") + "/" + entry.path, ThemeFile.MAX_BYTES, (status, bytes) => {
            if (status === -1) { fail("size"); return; }
            if (status !== 200 || bytes === null) { fail(problem(status)); return; }
            if (ThemeFile.sha256(bytes) !== entry.sha256) { fail("checksum"); return; }
            const text = ThemeFile.utf8Decode(bytes);
            const read = ThemeFile.parse(text === null ? "" : text);
            if (!read.ok) { fail(read.error, read.field); return; }
            read.theme.keeps = ["top", "offsetX", "scale"].filter(key => read.theme.style[key] === undefined);
            read.theme.style = Styles.normalize(read.theme.style);
            mark(false);
            done(read);
        });
    }
}
