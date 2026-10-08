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
      betternotes BetterNotes on this computer: no account, nothing to sign in
                  to. Its `betternotes` command lists, shows, creates and
                  updates notes (`update <id> --title … --body -`, 0.1.13+,
                  the content on standard input) and shows a note as its
                  sticky window (`open <id>`, 0.1.14+); the change date, lock state
                  and next reminder come from its SQLite database, which is
                  only ever read. Installed as a Flatpak it is started with
                  `flatpak run` and its notes are in the sandbox's own folder.
                  A note is edited here as plain text; notes
                  with rich text stay read-only (BetterNotes has its own
                  editor for those). A locked note is read and written with
                  its master password on the command's standard input
                  (`--password-stdin`, 0.1.15+): the password is handed over
                  for that one command and kept nowhere here, and the note's
                  text never enters the list.

    `sourcesJson` is a JSON list of { id, type, name, server, user } and is
    stored in the widget configuration. Tokens live in KWallet (native core)
    under "notes:<id>" and, without it, only in memory until the shell
    restarts; they are removed when a source is disconnected.

    A note is { key, source (id), type, id, title, text, updated (ms), raw }.
    For Joplin the first line of `text` is the title. BetterNotes notes also
    carry readOnly, priority, tags, reminder (ms, 0 = none), locked, and their
    `text` is only the title until loadText() has fetched the content; after
    that it is "title\ncontent", which is also what save() takes for them.

    `drafts` keeps, per note key ("new:<source>" for a note not created yet),
    text that could not be saved, so that nothing typed is lost when saving
    fails or the island closes; it lives as long as the shell.
*/
import QtQuick
import ".."

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
        memos: { name: "Memos", color: "#10b981", icon: "" },
        betternotes: { name: "BetterNotes", color: "#2563eb", icon: Qt.resolvedUrl("../../icons/betternotes.svg"), local: true }
    })
    readonly property string betterNotesInstall: "curl -fsSL https://raw.githubusercontent.com/thebanri/BetterNotes/main/install.sh | sh"
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
    property var drafts: ({})               // key → unsaved text
    function setDraft(key: string, text: string): void {
        const d = Object.assign({}, drafts);
        if (text === null || text === undefined) delete d[key]; else d[key] = text;
        drafts = d;
    }

    // ---- BetterNotes (local) -----------------------------------------------------
    readonly property var local: core !== null ? core.local : null
    // Without the native module nothing on this computer can be looked for or run:
    // BetterNotes is then not "not found", it cannot be asked for.
    readonly property bool canLookForApps: local !== null
    // How BetterNotes is started here: { program, args (before its own), flatpak }; null = not installed.
    // On the PATH or in ~/.local/bin, else what its menu entry starts: an AppImage that was
    // only added to the menu, or the Flatpak (`flatpak run org.betternotes.BetterNotes`).
    function betterNotesLaunch(): var {
        if (!local) return null;
        const found = local.findExecutable(betterNotesName);
        if (found.length > 0) return { program: found, args: [], flatpak: false };
        for (const dir of desktopDirs) {
            const exec = /^Exec=("([^"]+)"|(\S+))(.*)$/m.exec(local.readTextFile(dir + "/" + betterNotesApp + ".desktop"));
            let program = exec ? (exec[2] || exec[3]) : "";
            if (program.length === 0) continue;
            if (program.indexOf("/") < 0) program = local.findExecutable(program);
            else if (core.existingPaths([program]).length === 0) program = "";
            if (program.length === 0) continue;
            if (/(^|\/)flatpak$/.test(program) && /(^|\s)run(\s|$)/.test(exec[4])) return { program: program, args: ["run", betterNotesApp], flatpak: true };
            return { program: program, args: [], flatpak: false };
        }
        return null;
    }
    // Its command; "" = not installed.
    function betterNotesCommand(): string {
        const launch = betterNotesLaunch();
        return launch ? launch.program : "";
    }
    property string betterNotesName: "betternotes"
    readonly property string betterNotesApp: "org.betternotes.BetterNotes"
    property var desktopDirs: ["~/.local/share/applications", "/usr/local/share/applications", "/usr/share/applications",
                               "~/.local/share/flatpak/exports/share/applications", "/var/lib/flatpak/exports/share/applications"]
    // Where its notes are: its own data folder, or the sandbox's when it is the Flatpak.
    property string betterNotesData: local ? local.dataHome() + "/betternotes" : ""
    property string betterNotesSandboxData: local && typeof local.environment === "function"
        ? local.environment("HOME") + "/.var/app/" + betterNotesApp + "/data/betternotes" : ""
    // (known since BetterNotes was last looked for)
    property bool betterNotesSandboxed: false
    readonly property string betterNotesFolder: betterNotesSandboxed && betterNotesSandboxData.length > 0 ? betterNotesSandboxData : betterNotesData
    readonly property bool hasBetterNotes: sources.some(s => s.type === "betternotes")
    // Its database changed (a note was edited in the app): list again, at once.
    readonly property Binding watchBinding: Binding {
        target: backend.local
        property: "watchedPaths"
        value: backend.enabled && backend.hasBetterNotes ? [backend.betterNotesFolder] : []
        when: backend.local !== null
    }
    readonly property Connections watchEvents: Connections {
        target: backend.local
        function onPathChanged() { localChange.restart(); }
    }
    readonly property Timer localChange: Timer { interval: 700; onTriggered: backend.betterNotesChanged() }
    // Looking at the database changes its folder too: SQLite makes its -wal and -shm beside it and
    // takes them away again, with every `betternotes list` and every look of ours. So a change of
    // the folder says nothing by itself (listing again for it would never end: one listing would
    // call for the next); only a change of the database does: its time or size, or what waits in
    // the -wal. `betterNotesSeen` is that, as it was after the last listing.
    property string betterNotesSeen: ""
    function betterNotesStamp(done: var): void {
        const db = betterNotesFolder + "/notes.sqlite3";
        local.run("stat", ["-c", "%s %y", "--", db, db + "-wal"], (code, out) => {
            const lines = out.trim().split("\n");
            // (an empty -wal is one that was only just made: the same as none)
            done(lines[0] + " " + (lines.length > 1 ? Number(lines[1].split(" ")[0]) || 0 : 0));
        });
    }
    function betterNotesChanged(): void {
        betterNotesStamp(stamp => { if (stamp !== betterNotesSeen) refreshSource("betternotes"); });
    }
    // `betternotes list` prints a table: ID (6) PRIORITY (10) TAGS (20, "-" = none) TITLE.
    function parseBetterNotesList(text: string): var {
        const rows = [];
        for (const line of text.split("\n")) {
            const m = /^(\d+)\s+(Low|Normal|High|Urgent)\s+(.*)$/.exec(line);
            if (!m) continue;
            let rest = m[3], tags = [];
            if (/^-(\s|$)/.test(rest)) rest = rest.slice(1);
            else {
                let t;
                while ((t = /^(#\S+)\s+/.exec(rest)) !== null && rest.length > t[0].length) { tags.push(t[1].slice(1)); rest = rest.slice(t[0].length); }
            }
            const archived = /^\s*\[Archived\] /.test(rest);
            rows.push({ id: m[1], priority: m[2], tags: tags, title: rest.replace(/^\s*(\[Archived\] )?/, "").trim(), archived: archived });
        }
        return rows;
    }
    // The content of a BetterNotes note (`betternotes show <id>`). done(error, text, rich):
    // rich = it has formatting that plain text would lose, so it is only shown here.
    // A locked note needs `password` (0.1.15+): the error is then "locked" (none given, or a BetterNotes
    // too old for it) or "wrong". The password goes to the command's standard input, nowhere else.
    function loadText(item: var, done: var, password: var): void {
        if (!item || item.type !== "betternotes" || betterNotesLaunch() === null) { done(Lang.i18n("BetterNotes was not found."), ""); return; }
        const secret = item.locked === true;
        if (secret && (!betterNotesUnlocks || typeof password !== "string" || password.length === 0)) { done("locked", ""); return; }
        const shown = (code, out, err) => {
            if (secret && code === 3) { done("wrong", ""); return; }
            if (secret && code === 4) { done("locked", ""); return; }
            if (code !== 0) { done((err || out).trim() || Lang.i18n("BetterNotes could not show the note."), ""); return; }
            const at = out.indexOf("--- Content ---\n");
            let text = at >= 0 ? out.slice(at + 16).replace(/\n$/, "") : out;
            // Rich text is shown as plain text.
            const rich = /<\/?(p|div|span|br|ul|ol|li|b|i|u|h[1-6]|html|body|img|font)\b[^>]*>/i.test(text);
            if (rich)
                text = text.replace(/<br\s*\/?>|<\/(p|div|li|h[1-6])>/gi, "\n").replace(/<[^>]+>/g, "").replace(/&nbsp;/g, " ").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&").replace(/\n{3,}/g, "\n\n").trim();
            done("", text, rich);
        };
        if (secret) runBetterNotes(["show", item.id, "--password-stdin"], password + "\n", shown);
        else runBetterNotes(["show", item.id], null, shown);
    }
    // Runs `betternotes` with `input` on its standard input where args hold "--body", "-".
    // An older native module cannot write to standard input: the content then goes
    // as one argument instead (no shell is involved, line breaks stay as they are).
    function runBetterNotes(args: var, input: var, done: var): void {
        const launch = betterNotesLaunch();
        if (launch === null) { done(-1, "", Lang.i18n("BetterNotes was not found.")); return; }
        betterNotesSandboxed = launch.flatpak;
        const command = launch.program, before = launch.args;
        if (input === null || input === undefined) local.run(command, before.concat(args), done);
        else if (typeof local.runWithInput === "function") local.runWithInput(command, before.concat(args), input, done);
        else if (args.indexOf("--password-stdin") >= 0) done(4, "", "");      // (an old native module cannot hand over a password)
        else {
            const at = args.indexOf("-");
            local.run(command, before.concat(args.slice(0, at)).concat([input]).concat(args.slice(at + 1)), done);
        }
    }
    // What went wrong, in words a user can act on.
    function betterNotesError(code: int, out: string, err: string, fallback: string): string {
        const text = ((err || "") + "\n" + (out || "")).trim();
        if (/unknown variant `?UpdateNote/.test(text))
            return Lang.i18n("The BetterNotes that is running is too old to save from here. Quit it and start it again (0.1.13 or newer).");
        if (/unknown variant `?OpenNote/.test(text))
            return Lang.i18n("The BetterNotes that is running is too old to open a note from here. Quit it and start it again (0.1.14 or newer).");
        if (/is in the trash/.test(text)) return Lang.i18n("This note is in the trash of BetterNotes. Restore it there first.");
        if (/does not exist/.test(text)) return Lang.i18n("This note no longer exists in BetterNotes.");
        if (code === 3) return Lang.i18n("The password is wrong.");
        if (code === 4) return Lang.i18n("This note is locked: its password is needed.");
        if (code === -1 && text.length === 0) return Lang.i18n("BetterNotes did not answer.");
        return text.replace(/^(Error|BetterNotes):\s*/, "").split("\n")[0] || fallback;
    }
    // Opens BetterNotes itself (what an older one can do instead of openNote()).
    function openBetterNotes(): void {
        const launch = betterNotesLaunch();
        if (launch !== null) core.startDetached(launch.program, launch.args);
    }
    // "BetterNotes 0.1.14", asked with every listing until it is new enough for
    // `open <id>`: an older command takes `open` as a plain launch.
    property string betterNotesVersion: ""
    readonly property bool betterNotesOpens: {
        const m = /(\d+)\.(\d+)\.(\d+)/.exec(betterNotesVersion);
        return m !== null && (Number(m[1]) * 1e6 + Number(m[2]) * 1e3 + Number(m[3])) >= 1014;
    }
    // 0.1.15 takes a locked note's password on standard input (`--password-stdin`).
    readonly property bool betterNotesUnlocks: {
        const m = /(\d+)\.(\d+)\.(\d+)/.exec(betterNotesVersion);
        return m !== null && (Number(m[1]) * 1e6 + Number(m[2]) * 1e3 + Number(m[3])) >= 1015;
    }
    function checkBetterNotes(): void {
        if (betterNotesLaunch() === null) { betterNotesVersion = ""; return; }
        runBetterNotes(["--version"], null, (code, out) => { betterNotesVersion = code === 0 ? out.trim() : ""; });
    }
    // Shows the note's sticky window, or brings it forward; BetterNotes is started in
    // the background when it is not running, and a locked note asks for its password
    // there. done(error)
    function openNote(item: var, done: var): void {
        runBetterNotes(["open", item.id], null, (code, out, err) => {
            done(code === 0 ? "" : betterNotesError(code, out, err, Lang.i18n("BetterNotes could not open the note.")));
        });
    }

    // ---- tokens --------------------------------------------------------------------
    property var secrets: ({})              // id → token
    function secretKey(id: string): string { return "notes:" + id; }
    function isLocal(id: string): bool {
        const s = sources.find(x => x.id === id);
        return s !== undefined && types[s.type].local === true;
    }
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
            if (secrets[id] || !walletReady || isLocal(id)) continue;
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
            problem: status => status === 0 ? Lang.i18n("Joplin is not running, or its Web Clipper service is turned off.")
                             : status === 403 || status === 401 ? Lang.i18n("Joplin did not accept the token.")
                             : Lang.i18n("Joplin answered %1.", status),
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
            problem: status => status === 0 ? Lang.i18n("No connection.")
                             : status === 401 ? Lang.i18n("The Simplenote sign-in is no longer valid; connect again.")
                             : Lang.i18n("Simplenote answered %1.", status),
            verify: function (fields, done) {
                backend.request("POST", backend.simperiumAuth + "/authorize/", { "X-Simperium-API-Key": backend.simperiumKey, "Content-Type": "application/json" },
                              JSON.stringify({ username: fields.user, password: fields.password }), (status, text) => {
                    const token = backend.parse(text).access_token;
                    if (status === 200 && token) done("", String(token), { server: "", user: fields.user });
                    else done(status === 401 || status === 400 ? Lang.i18n("The email or password was not accepted.") : status === 0 ? Lang.i18n("No connection.") : Lang.i18n("Simplenote answered %1.", status));
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
            problem: status => status === 0 ? Lang.i18n("The Memos server could not be reached.")
                             : status === 401 || status === 403 ? Lang.i18n("Memos did not accept the access token.")
                             : Lang.i18n("Memos answered %1.", status),
            from: (source, memo) => backend.note(source, String(memo.name), String(memo.content || ""), Date.parse(memo.updateTime || memo.createTime || "") || 0, null),
            verify: function (fields, done) {
                const server = String(fields.server || "").trim().replace(/\/+$/, ""), self = this;
                if (!/^https?:\/\/[^\s]+$/i.test(server)) { done(Lang.i18n("Enter the address of your Memos server, starting with http:// or https://.")); return; }
                backend.request("GET", server + "/api/v1/memos?pageSize=1", { "Authorization": "Bearer " + fields.token }, "", (status, text) => {
                    if (status !== 200 || backend.parse(text).memos === undefined) done(status === 200 ? Lang.i18n("This address does not look like a Memos server.") : self.problem(status));
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

    readonly property var localDrivers: ({
        betternotes: {
            verify: function (fields, done) {
                if (backend.betterNotesCommand().length === 0) done(Lang.i18n("BetterNotes was not found on this computer.")); else done("", "local", { server: "", user: "" });
            },
            list: function (source, token, done) {
                if (backend.betterNotesLaunch() === null) { done("missing", []); return; }
                if (!backend.betterNotesUnlocks) backend.checkBetterNotes();
                backend.runBetterNotes(["list"], null, (code, out, err) => {
                    if (code !== 0) { done((err || out).trim() || Lang.i18n("BetterNotes could not list its notes."), []); return; }
                    // What the command does not print: change date, lock, next reminder (read-only).
                    const db = backend.betterNotesFolder + "/notes.sqlite3", extra = {};
                    let rows = backend.local.sqliteQuery(db, "SELECT n.id AS id, n.updated_at AS updated, n.is_locked AS locked, "
                        + "(SELECT MIN(r.remind_at) FROM reminders r WHERE r.note_id = n.id AND r.dismissed = 0) AS reminder FROM notes n");
                    if (rows.length === 0) rows = backend.local.sqliteQuery(db, "SELECT id, updated_at AS updated FROM notes");
                    backend.betterNotesStamp(stamp => backend.betterNotesSeen = stamp);
                    for (const r of rows) extra[String(r.id)] = r;
                    const old = {};
                    for (const n of backend.bySource[source.id] || []) old[n.id] = n;
                    done("", backend.parseBetterNotesList(out).map(row => {
                        const x = extra[row.id] || {}, updated = Number(x.updated || 0), before = old[row.id];
                        const item = backend.note(source, row.id, row.title, updated, null);
                        item.title = row.title;
                        item.locked = Number(x.locked || 0) === 1;
                        // (a locked note is written with its password; an older BetterNotes cannot take one)
                        item.readOnly = (item.locked && !backend.betterNotesUnlocks) || (before !== undefined && before.rich === true);
                        item.rich = before !== undefined && before.rich === true;
                        item.priority = row.priority; item.tags = row.tags;
                        item.reminder = Number(x.reminder || 0) * 1000;
                        // Content fetched earlier stays while the note has not changed.
                        if (before && before.loaded && before.updated === updated) { item.text = before.text; item.loaded = true; }
                        return item;
                    }));
                });
            },
            // The first line is the title; a title alone makes an empty note.
            create: function (source, token, text, done) {
                const i = text.indexOf("\n");
                const title = (i < 0 ? text : text.slice(0, i)).trim(), content = i < 0 ? "" : text.slice(i + 1);
                const args = ["new", title].concat(content.length > 0 ? ["--body", "-"] : []).concat(["--id-only", "--no-open"]);
                backend.runBetterNotes(args, content.length > 0 ? content : null, (code, out, err) => {
                    if (code !== 0) { done(backend.betterNotesError(code, out, err, Lang.i18n("BetterNotes could not create the note."))); return; }
                    const made = item => {
                        item.title = title; item.text = title + "\n" + content;
                        item.readOnly = false; item.rich = false; item.priority = "Normal"; item.tags = []; item.locked = false; item.reminder = 0; item.loaded = true;
                        done("", item);
                    };
                    // "12" with --id-only; an older BetterNotes answers "Created note #12 …".
                    const m = /^\s*(\d+)\s*$/.exec(out) || /Created note #(\d+)/.exec(out);
                    if (m) { made(backend.note(source, m[1], title, Date.now(), null)); return; }
                    // No id printed: the newest note with this title.
                    backend.runBetterNotes(["list"], null, (code2, out2) => {
                        const rows = code2 === 0 ? backend.parseBetterNotesList(out2).filter(r => r.title === title) : [];
                        if (rows.length === 0) { done(Lang.i18n("BetterNotes created the note but did not say which one; it appears with the next refresh.")); return; }
                        const id = rows.map(r => Number(r.id)).reduce((a, b) => Math.max(a, b));
                        made(backend.note(source, String(id), title, Date.now(), null));
                    });
                });
            },
            // `text` is "title\ncontent"; only what changed is sent. A locked note: its password first on standard input.
            save: function (source, token, old, text, done, password) {
                const i = text.indexOf("\n");
                const title = (i < 0 ? text : text.slice(0, i)).trim(), content = i < 0 ? "" : text.slice(i + 1);
                const oldContent = old.loaded && old.text.indexOf(old.title + "\n") === 0 ? old.text.slice(old.title.length + 1) : old.loaded ? "" : null;
                const args = ["update", old.id];
                if (title.length > 0 && title !== old.title) args.push("--title", title);
                if (content !== oldContent) args.push("--body", "-");
                const saved = () => {
                    const item = Object.assign({}, old);
                    item.title = title.length > 0 ? title : old.title;
                    item.text = item.title + "\n" + content; item.loaded = true; item.updated = Date.now();
                    done("", item);
                };
                if (args.length === 2) { saved(); return; }
                const secret = old.locked === true;
                if (secret && (typeof password !== "string" || password.length === 0)) { done(backend.betterNotesError(4, "", "", "")); return; }
                if (secret) args.splice(2, 0, "--password-stdin");
                const input = (secret ? password + "\n" : "") + (args.indexOf("-") >= 0 ? content : "");
                backend.runBetterNotes(args, secret || args.indexOf("-") >= 0 ? input : null, (code, out, err) => {
                    if (code !== 0) { done(backend.betterNotesError(code, out, err, Lang.i18n("BetterNotes could not save the note."))); return; }
                    saved();
                });
            }
        }
    })
    function driver(type: string): var { return drivers[type] || localDrivers[type]; }

    // ---- installed apps ------------------------------------------------------------
    readonly property var appPaths: ({
        joplin: ["~/.config/joplin-desktop", "~/.var/app/net.cozic.joplin_desktop", "~/snap/joplin-desktop"],
        simplenote: ["~/.config/Simplenote", "~/.var/app/com.simplenote.Simplenote", "~/snap/simplenote"]
    })
    // Which note apps are on this computer: only looks for their folders and
    // asks Joplin's local service whether it is running.
    // done({ joplin, joplinRunning, simplenote, betternotes })
    function detect(done: var): void {
        const has = type => core !== null && core.existingPaths(appPaths[type]).length > 0;
        const found = { joplin: has("joplin"), joplinRunning: false, simplenote: has("simplenote"), betternotes: betterNotesCommand().length > 0 };
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
    // fields: { token } (joplin), { user, password } (simplenote), { server, token } (memos),
    // {} (betternotes: nothing to sign in to). done({ ok, error })
    function connect(type: string, fields: var, done: var): void {
        const isLocalType = types[type].local === true;
        driver(type).verify(fields, (error, token, info) => {
            if (error) { done({ ok: false, error: error }); return; }
            const same = sources.find(s => s.type === type && s.server === info.server && s.user === info.user);
            const id = same ? same.id : type + "-" + Date.now().toString(36);
            secrets[id] = token;
            if (walletReady && !isLocalType) core.writeSecret(secretKey(id), token, () => {});
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
            const token = types[s.type].local ? "local" : secrets[s.id];
            if (types[s.type].local) localDrivers[s.type].list(s, token, (error, found) => {
                // Uninstalled: the source goes away, its card says "Not found" again.
                if (error === "missing") { Qt.callLater(() => backend.disconnect(s.id)); finish("", []); } else finish(error, found);
            });
            else if (!token) finish(walletReady ? Lang.i18n("Not signed in; connect again.") : Lang.i18n("The sign-in is only kept until a restart; connect again."), []);
            else drivers[s.type].list(s, token, finish);
        }
    }
    // One source only (its files changed).
    function refreshSource(type: string): void {
        const s = sources.find(x => x.type === type);
        if (!s || !available || busy) return;
        const run = seq;
        driver(type).list(s, "local", (error, found) => {
            if (run !== seq) return;
            if (error === "missing") { disconnect(s.id); return; }
            const failed = Object.assign({}, errors);
            if (error) failed[s.id] = error; else { delete failed[s.id]; bySource[s.id] = found; }
            errors = failed;
            publish();
        });
    }
    // Adds what was fetched later (e.g. a note's content) to a listed note.
    function remember(key: string, fields: var): void {
        for (const id in bySource)
            for (const n of bySource[id]) if (n.key === key) Object.assign(n, fields);
    }
    function replace(sourceId: string, item: var): void {
        const list = (bySource[sourceId] || []).filter(n => n.id !== item.id);
        list.unshift(item);
        bySource[sourceId] = list;
        publish();
    }
    // done({ ok, note, error }). Text that could not be saved is kept in `drafts`.
    function create(text: string, sourceId: string, done: var): void {
        const s = sources.find(x => x.id === sourceId) || defaultSource;
        if (!s || (!secrets[s.id] && !types[s.type].local)) { done({ ok: false, note: null, error: Lang.i18n("Connect a notes app first.") }); return; }
        const key = "new:" + s.id;
        driver(s.type).create(s, secrets[s.id] || "local", text, (error, item) => {
            if (error) { setDraft(key, text); done({ ok: false, note: null, error: error }); return; }
            setDraft(key, null);
            replace(s.id, item);
            done({ ok: true, note: item, error: "" });
        });
    }
    // `password`: of a locked note, for this one save.
    function save(old: var, text: string, done: var, password: var): void {
        const s = sources.find(x => x.id === old.source);
        if (!s || (!secrets[s.id] && !types[s.type].local)) { setDraft(old.key, text); done({ ok: false, note: null, error: Lang.i18n("This notes app is no longer connected.") }); return; }
        const secret = old.locked === true;
        driver(s.type).save(s, secrets[s.id] || "local", old, text, (error, item) => {
            // (what a locked note says is never kept here: no draft of it, and the list holds its title only)
            if (error) { if (!secret) setDraft(old.key, text); done({ ok: false, note: null, error: error }); return; }
            if (drafts[old.key] === text) setDraft(old.key, null);
            replace(s.id, secret ? Object.assign({}, item, { text: item.title, loaded: false }) : item);
            done({ ok: true, note: item, error: "" });
        }, password);
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
