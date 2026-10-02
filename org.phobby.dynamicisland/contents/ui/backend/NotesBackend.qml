/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Notes from open-source note apps, for quick everyday use: one list of all
    connected sources, newest first; a note can be read, edited and created.

      joplin      the desktop app's local Web Clipper API (http://localhost:41184)
                  with its API token
      simplenote  the account, through Simperium (the service behind
                  Simplenote); the password is only used to sign in, the
                  token it returns is what is kept
      memos       a self-hosted Memos server with an access token

    `sourcesJson` is a JSON list of { id, type, name, server, user } and is
    stored in the widget configuration. Tokens live in KWallet (native core)
    under "notes:<id>" and, without it, only in memory until the shell
    restarts; they are removed when a source is disconnected.

    A note is { key, source (id), type, id, title, text, updated (ms), raw }.
    For Joplin the first line of `text` is the title.
*/
import QtQuick

QtObject {
    id: backend

    property bool enabled: true
    property string sourcesJson: "[]"
    property string defaultId: ""
    property int refreshMinutes: 2
    property var core: null                 // NativeBridge

    readonly property var types: ({
        joplin: { name: "Joplin", color: "#1071d3", icon: Qt.resolvedUrl("../../icons/joplin.svg") },
        simplenote: { name: "Simplenote", color: "#3361cc", icon: Qt.resolvedUrl("../../icons/simplenote.svg") },
        memos: { name: "Memos", color: "#10b981", icon: "" }
    })
    readonly property string joplinServer: "http://localhost:41184"
    // Simplenote's own application on Simperium, as its open-source clients use it.
    property string simperiumAuth: "https://auth.simperium.com/1/chalk-bump-f49"
    property string simperiumApi: "https://api.simperium.com/1/chalk-bump-f49"
    readonly property string simperiumKey: "c8c2b86337154cdabc989b23e30c6bf4"

    readonly property var sources: {
        let list = [];
        try { list = JSON.parse(sourcesJson || "[]"); } catch (e) { list = []; }
        if (!Array.isArray(list)) return [];
        return list.filter(s => s && typeof s.id === "string" && types[s.type] !== undefined)
                   .map(s => ({ id: s.id, type: s.type, name: String(s.name || types[s.type].name), server: String(s.server || ""), user: String(s.user || "") }));
    }
    readonly property bool available: enabled && sources.length > 0
    // Where a quick note goes.
    readonly property var defaultSource: sources.find(s => s.id === defaultId) || sources[0] || null

    property var notes: []                  // every source, newest first
    property var bySource: ({})             // id → notes of that source
    property var errors: ({})               // id → message of the last attempt
    property bool loaded: false
    property bool busy: false
    property int seq: 0

    // ---- tokens --------------------------------------------------------------------
    property var secrets: ({})              // id → token
    function secretKey(id: string): string { return "notes:" + id; }
    readonly property bool walletReady: core !== null && core.secretsAvailable
    property var knownIds: []
    readonly property string idSignature: sources.map(s => s.id).join("\n")
    onIdSignatureChanged: syncSecrets()
    onWalletReadyChanged: syncSecrets()
    // Reads the tokens of new sources and forgets those of removed ones.
    function syncSecrets(): void {
        const ids = sources.map(s => s.id);
        for (const id of knownIds) {
            if (ids.indexOf(id) >= 0) continue;
            delete secrets[id];
            if (walletReady) core.removeSecret(secretKey(id));
        }
        knownIds = ids;
        let waiting = 0;
        for (const id of ids) {
            if (secrets[id] || !walletReady) continue;
            ++waiting;
            core.readSecret(secretKey(id), (ok, value) => {
                if (ok && value) secrets[id] = value;
                if (--waiting === 0) Qt.callLater(refresh);
            });
        }
        if (waiting === 0) Qt.callLater(refresh);
    }

    // ---- HTTP --------------------------------------------------------------------
    // done(status, text); status 0 = no connection
    function request(method: string, url: string, headers: var, body: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE) done(xhr.status, xhr.responseText || "");
        };
        xhr.open(method, url);
        for (const name in headers) xhr.setRequestHeader(name, headers[name]);
        if (body.length > 0) xhr.send(body); else xhr.send();
    }
    function parse(text: string): var {
        try { return JSON.parse(text) || {}; } catch (e) { return {}; }
    }
    function titleOf(text: string): string {
        const line = text.split("\n").find(l => l.trim().length > 0) || "";
        return line.replace(/^\s*#+\s*/, "").trim();
    }
    function note(source: var, id: string, text: string, updated: real, raw: var): var {
        return { key: source.id + ":" + id, source: source.id, type: source.type, id: id, title: titleOf(text), text: text, updated: updated, raw: raw };
    }

    // ---- drivers: verify(fields, done(error, token, info)), list, save, create ----
    readonly property var drivers: ({
        joplin: {
            base: source => (source.server || backend.joplinServer).replace(/\/+$/, ""),
            split: text => {
                const i = text.indexOf("\n");
                return i < 0 ? { title: text.trim(), body: "" } : { title: text.slice(0, i).trim(), body: text.slice(i + 1) };
            },
            join: item => String(item.title || "") + (item.body ? "\n" + item.body : ""),
            problem: status => status === 0 ? i18n("Joplin is not running, or its Web Clipper service is turned off.")
                             : status === 403 || status === 401 ? i18n("Joplin did not accept the token.")
                             : i18n("Joplin answered %1.", status),
            verify: function (fields, done) {
                const base = (fields.server || backend.joplinServer).replace(/\/+$/, ""), self = this;
                backend.request("GET", base + "/ping", {}, "", (status, text) => {
                    if (status !== 200 || text.indexOf("JoplinClipperServer") < 0) { done(self.problem(0)); return; }
                    backend.request("GET", base + "/notes?limit=1&token=" + encodeURIComponent(fields.token), {}, "", s2 => {
                        if (s2 !== 200) done(self.problem(s2)); else done("", fields.token, { server: fields.server || "", user: "" });
                    });
                });
            },
            list: function (source, token, done) {
                const found = [], self = this;
                const page = n => {
                    backend.request("GET", self.base(source) + "/notes?fields=id,title,body,updated_time&order_by=updated_time&order_dir=DESC&limit=100&page=" + n
                                         + "&token=" + encodeURIComponent(token), {}, "", (status, text) => {
                        if (status !== 200) { done(self.problem(status), found); return; }
                        const data = backend.parse(text);
                        for (const item of data.items || []) found.push(backend.note(source, String(item.id), self.join(item), Number(item.updated_time || 0), null));
                        if (data.has_more && n < 3) page(n + 1); else done("", found);
                    });
                };
                page(1);
            },
            save: function (source, token, old, text, done) {
                const self = this;
                backend.request("PUT", self.base(source) + "/notes/" + old.id + "?token=" + encodeURIComponent(token), { "Content-Type": "application/json" },
                              JSON.stringify(self.split(text)), (status, answer) => {
                    if (status !== 200) done(self.problem(status)); else done("", backend.note(source, old.id, text, Number(backend.parse(answer).updated_time || Date.now()), null));
                });
            },
            create: function (source, token, text, done) {
                const self = this;
                backend.request("POST", self.base(source) + "/notes?token=" + encodeURIComponent(token), { "Content-Type": "application/json" },
                              JSON.stringify(self.split(text)), (status, answer) => {
                    const item = backend.parse(answer);
                    if (status !== 200 || !item.id) done(self.problem(status)); else done("", backend.note(source, String(item.id), text, Number(item.updated_time || Date.now()), null));
                });
            }
        },
        simplenote: {
            problem: status => status === 0 ? i18n("No connection.")
                             : status === 401 ? i18n("The Simplenote sign-in is no longer valid; connect again.")
                             : i18n("Simplenote answered %1.", status),
            verify: function (fields, done) {
                backend.request("POST", backend.simperiumAuth + "/authorize/", { "X-Simperium-API-Key": backend.simperiumKey, "Content-Type": "application/json" },
                              JSON.stringify({ username: fields.user, password: fields.password }), (status, text) => {
                    const token = backend.parse(text).access_token;
                    if (status === 200 && token) done("", String(token), { server: "", user: fields.user });
                    else done(status === 401 || status === 400 ? i18n("The email or password was not accepted.") : status === 0 ? i18n("No connection.") : i18n("Simplenote answered %1.", status));
                });
            },
            list: function (source, token, done) {
                const found = [], self = this;
                const page = (mark, n) => {
                    backend.request("GET", backend.simperiumApi + "/note/index?data=true&limit=100" + (mark ? "&mark=" + encodeURIComponent(mark) : ""),
                                  { "X-Simperium-Token": token }, "", (status, text) => {
                        if (status !== 200) { done(self.problem(status), found); return; }
                        const data = backend.parse(text);
                        for (const item of data.index || []) {
                            const d = item.d || {};
                            if (d.deleted) continue;
                            found.push(backend.note(source, String(item.id), String(d.content || ""), Number(d.modificationDate || 0) * 1000, d));
                        }
                        if (data.mark && n < 3) page(data.mark, n + 1); else done("", found);
                    });
                };
                page("", 1);
            },
            write: function (source, token, id, data, done) {
                const self = this;
                backend.request("POST", backend.simperiumApi + "/note/i/" + encodeURIComponent(id) + "?response=1", { "X-Simperium-Token": token, "Content-Type": "application/json" },
                              JSON.stringify(data), status => {
                    if (status !== 200) done(self.problem(status)); else done("", backend.note(source, id, data.content, data.modificationDate * 1000, data));
                });
            },
            save: function (source, token, old, text, done) {
                this.write(source, token, old.id, Object.assign({}, old.raw || {}, { content: text, modificationDate: Date.now() / 1000 }), done);
            },
            create: function (source, token, text, done) {
                let id = "";
                for (let i = 0; i < 32; ++i) id += Math.floor(Math.random() * 16).toString(16);
                const now = Date.now() / 1000;
                this.write(source, token, id, { content: text, creationDate: now, modificationDate: now, deleted: false, tags: [], systemTags: [], shareURL: "", publishURL: "" }, done);
            }
        },
        memos: {
            base: source => source.server.replace(/\/+$/, ""),
            problem: status => status === 0 ? i18n("The Memos server could not be reached.")
                             : status === 401 || status === 403 ? i18n("Memos did not accept the access token.")
                             : i18n("Memos answered %1.", status),
            from: (source, memo) => backend.note(source, String(memo.name), String(memo.content || ""), Date.parse(memo.updateTime || memo.createTime || "") || 0, null),
            verify: function (fields, done) {
                const server = String(fields.server || "").trim().replace(/\/+$/, ""), self = this;
                if (!/^https?:\/\/[^\s]+$/i.test(server)) { done(i18n("Enter the address of your Memos server, starting with http:// or https://.")); return; }
                backend.request("GET", server + "/api/v1/memos?pageSize=1", { "Authorization": "Bearer " + fields.token }, "", (status, text) => {
                    if (status !== 200 || backend.parse(text).memos === undefined) done(status === 200 ? i18n("This address does not look like a Memos server.") : self.problem(status));
                    else done("", fields.token, { server: server, user: "" });
                });
            },
            list: function (source, token, done) {
                const self = this;
                backend.request("GET", self.base(source) + "/api/v1/memos?pageSize=100", { "Authorization": "Bearer " + token }, "", (status, text) => {
                    if (status !== 200) { done(self.problem(status), []); return; }
                    done("", (backend.parse(text).memos || []).filter(m => m.state !== "ARCHIVED").map(m => self.from(source, m)));
                });
            },
            save: function (source, token, old, text, done) {
                const self = this;
                backend.request("PATCH", self.base(source) + "/api/v1/" + old.id + "?updateMask=content", { "Authorization": "Bearer " + token, "Content-Type": "application/json" },
                              JSON.stringify({ name: old.id, content: text }), (status, answer) => {
                    const memo = backend.parse(answer);
                    if (status !== 200 || !memo.name) done(self.problem(status)); else done("", self.from(source, memo));
                });
            },
            create: function (source, token, text, done) {
                const self = this;
                backend.request("POST", self.base(source) + "/api/v1/memos", { "Authorization": "Bearer " + token, "Content-Type": "application/json" },
                              JSON.stringify({ content: text, visibility: "PRIVATE" }), (status, answer) => {
                    const memo = backend.parse(answer);
                    if (status !== 200 || !memo.name) done(self.problem(status)); else done("", self.from(source, memo));
                });
            }
        }
    })

    // ---- installed apps ------------------------------------------------------------
    readonly property var appPaths: ({
        joplin: ["~/.config/joplin-desktop", "~/.var/app/net.cozic.joplin_desktop", "~/snap/joplin-desktop"],
        simplenote: ["~/.config/Simplenote", "~/.var/app/com.simplenote.Simplenote", "~/snap/simplenote"]
    })
    // Which note apps are on this computer: only looks for their folders and
    // asks Joplin's local service whether it is running. done({ joplin, joplinRunning, simplenote })
    function detect(done: var): void {
        const has = type => core !== null && core.existingPaths(appPaths[type]).length > 0;
        const found = { joplin: has("joplin"), joplinRunning: false, simplenote: has("simplenote") };
        request("GET", joplinServer + "/ping", {}, "", (status, text) => {
            found.joplinRunning = status === 200 && text.indexOf("JoplinClipperServer") >= 0;
            if (found.joplinRunning) found.joplin = true;
            done(found);
        });
    }

    // ---- sources -------------------------------------------------------------------
    function store(list: var): void {
        sourcesJson = JSON.stringify(list.map(s => ({ id: s.id, type: s.type, name: s.name, server: s.server, user: s.user })));
    }
    // fields: { token } (joplin), { user, password } (simplenote), { server, token } (memos). done({ ok, error })
    function connect(type: string, fields: var, done: var): void {
        drivers[type].verify(fields, (error, token, info) => {
            if (error) { done({ ok: false, error: error }); return; }
            const same = sources.find(s => s.type === type && s.server === info.server && s.user === info.user);
            const id = same ? same.id : type + "-" + Date.now().toString(36);
            secrets[id] = token;
            if (walletReady) core.writeSecret(secretKey(id), token, () => {});
            if (!same) {
                knownIds = knownIds.concat([id]);
                store(sources.concat([{ id: id, type: type, name: types[type].name, server: info.server, user: info.user }]));
            }
            done({ ok: true, error: "" });
            Qt.callLater(refresh);
        });
    }
    // Forgets the source and deletes its token from the wallet.
    function disconnect(id: string): void {
        store(sources.filter(s => s.id !== id));
        refresh();
    }

    // ---- notes ---------------------------------------------------------------------
    function publish(): void {
        let all = [];
        for (const s of sources) all = all.concat(bySource[s.id] || []);
        all.sort((a, b) => b.updated - a.updated);
        notes = all;
    }
    function refresh(): void {
        const run = ++seq, list = sources;
        if (!available) { notes = []; bySource = ({}); errors = ({}); loaded = false; busy = false; return; }
        const failed = {}, fresh = {};
        let pending = list.length;
        busy = true;
        for (const s of list) {
            const finish = (error, found) => {
                if (error) { failed[s.id] = error; fresh[s.id] = bySource[s.id] || []; } else fresh[s.id] = found;
                if (--pending > 0 || run !== seq) return;
                bySource = fresh; errors = failed; loaded = true; busy = false;
                publish();
            };
            const token = secrets[s.id];
            if (!token) finish(walletReady ? i18n("Not signed in; connect again.") : i18n("The sign-in is only kept until a restart; connect again."), []);
            else drivers[s.type].list(s, token, finish);
        }
    }
    function replace(sourceId: string, item: var): void {
        const list = (bySource[sourceId] || []).filter(n => n.id !== item.id);
        list.unshift(item);
        bySource[sourceId] = list;
        publish();
    }
    // done({ ok, note, error })
    function create(text: string, sourceId: string, done: var): void {
        const s = sources.find(x => x.id === sourceId) || defaultSource;
        if (!s || !secrets[s.id]) { done({ ok: false, note: null, error: i18n("Connect a notes app first.") }); return; }
        drivers[s.type].create(s, secrets[s.id], text, (error, item) => {
            if (error) { done({ ok: false, note: null, error: error }); return; }
            replace(s.id, item);
            done({ ok: true, note: item, error: "" });
        });
    }
    function save(old: var, text: string, done: var): void {
        const s = sources.find(x => x.id === old.source);
        if (!s || !secrets[s.id]) { done({ ok: false, note: null, error: i18n("This notes app is no longer connected.") }); return; }
        drivers[s.type].save(s, secrets[s.id], old, text, (error, item) => {
            if (error) { done({ ok: false, note: null, error: error }); return; }
            replace(s.id, item);
            done({ ok: true, note: item, error: "" });
        });
    }

    readonly property string signature: available ? sources.map(s => s.id + "|" + s.server).join("\n") : ""
    onSignatureChanged: Qt.callLater(refresh)
    property real lastRequested: 0
    // For the moment the page opens: fetch now unless that just happened.
    function refreshIfStale(): void {
        if (available && Date.now() - lastRequested > 20000) { lastRequested = Date.now(); refresh(); }
    }

    readonly property Timer timer: Timer {
        interval: Math.max(1, backend.refreshMinutes) * 60000
        repeat: true
        running: backend.available
        onTriggered: backend.refresh()
    }
}
