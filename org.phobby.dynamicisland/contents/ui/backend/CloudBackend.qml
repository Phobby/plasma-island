/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Cloud tab's part that outlives the page: which clouds there are (the
    remotes of the user's rclone, and sync clients found on this computer),
    their listings, how full they are, their sync state, what is being copied,
    and the alerts. Names, sizes and dates only: no file's content is ever
    read, nothing is previewed.

    What it may do to a cloud: list a folder (one level), ask how full it is,
    copy a file or folder from it to this computer, copy one to it. It cannot
    delete, move or rename, and it never writes over a file that is there
    unless the user chose that for this very file.

    Sync state is never made up. rclone itself has none; it comes from a
    client that runs on this computer and says it (Dropbox's own command for
    a Dropbox remote, Syncthing's local interface as a card of its own). A
    cloud without such a source is "unknown", and says why.

    Nothing runs while the tab is off. While it is on: a listing only when the
    page asks for one (kept for a minute); how full the clouds are every ten
    minutes while the page is on screen, else every three hours and only if
    alerts are wanted; sync state every ten seconds, only while the page or
    the indicator wants it and a source for it exists.

    An alert (storage nearly full, sign-in run out, unreachable, sync error)
    is said once and again only after `alertPauseHours`; it ends by itself
    when the cause is gone. When each was last said is kept in the settings.

    rclone's configuration file, tokens and passwords are never opened: only
    the command is asked. Nothing learned here is sent anywhere.
*/
import QtQuick
import ".."
import "../cloud"
import "../cloud/Rclone.js" as Rclone

QtObject {
    id: backend

    property var core: null
    property bool enabled: false
    property var hub: null                  // TransferHub: copies show as the island's transfers
    readonly property var local: core !== null ? core.local : null

    // ---- settings --------------------------------------------------------------------
    property string hiddenJson: "[]"        // names of remotes not shown
    property string aliasesJson: "{}"       // remote name → the name shown
    property int warnPercent: 90
    property int criticalPercent: 98
    property bool alerts: true
    property int alertPauseHours: 6
    property bool confirmUpload: true
    property int autoFetchMB: 25            // a file up to this size is fetched when the pointer rests on it
    property int cacheMB: 500
    property bool indicator: true
    // Written here: when each alert was last said ({ "remote:kind": ms }), and where the last upload went.
    property string alertedJson: "{}"
    property string lastTarget: ""
    // (the tests name a command and a configuration of their own)
    property string commandName: "rclone"
    property var extra: []

    function parsed(json: string, fallback: var): var {
        try { const v = JSON.parse(json); return v !== null && typeof v === "object" ? v : fallback; } catch (e) { return fallback; }
    }
    readonly property var hidden: { const l = parsed(hiddenJson, []); return Array.isArray(l) ? l.map(String) : []; }
    readonly property var aliases: parsed(aliasesJson, ({}))

    // ---- what is on this computer ------------------------------------------------------
    property bool looked: false
    property string command: ""             // rclone's full path; "" = not installed
    property var remotes: []                // [{ name, type }] as rclone names them
    // The clouds that are shown: [{ id, name, type }]
    readonly property var clouds: remotes.filter(r => hidden.indexOf(r.name) < 0)
                                         .map(r => ({ id: r.name, name: Rclone.display(String(aliases[r.name] || r.name)).slice(0, 40), type: r.type }))
    function cloud(id: string): var { return clouds.find(c => c.id === id) || null; }
    readonly property string home: local ? local.dataHome().replace(/\/\.local\/share$/, "") : ""
    property string cacheFolder: home.length > 0 ? home + "/.cache/dynamicisland/cloud" : ""
    property string downloadsFolder: ""

    // done(): rclone is looked for and asked for its remotes; the sync clients are looked for. Starts and installs nothing.
    function detect(done: var): void {
        const finish = () => { looked = true; pollSources(); if (done) done(); };
        if (local === null) { command = ""; remotes = []; finish(); return; }
        command = local.findExecutable(commandName);
        if (downloadsFolder.length === 0)
            local.run("xdg-user-dir", ["DOWNLOAD"], (code, out) => { downloadsFolder = code === 0 && out.trim().charAt(0) === "/" ? out.trim() : home + "/Downloads"; });
        let waiting = 1 + statusSources.length;
        const one = () => { if (--waiting === 0) finish(); };
        for (const s of statusSources) {
            s.core = core;
            s.detect(found => { const all = Object.assign({}, sourcesFound); all[s.name] = found; sourcesFound = all; one(); });
        }
        if (command.length === 0) { remotes = []; one(); return; }
        local.run(command, extra.concat(Rclone.remotesArguments()), (code, out) => {
            remotes = code === 0 ? Rclone.parseRemotes(out) : [];
            // a remote mounted as a folder (rclone mount) is said to be so
            mounted = Rclone.mounts(local.readTextFile("/proc/mounts", 200000));
            one();
        });
    }
    property var mounted: []

    property var providers: ({})
    readonly property Component providerMaker: Component { RcloneProvider {} }
    function provider(id: string): var {
        if (!Rclone.known(id, remotes)) return null;        // only a remote rclone itself named
        let p = providers[id];
        if (!p) providers[id] = p = providerMaker.createObject(backend, { remote: id });
        p.core = core; p.command = command; p.extra = extra; p.workFolder = cacheFolder;
        return p;
    }

    // ---- listings --------------------------------------------------------------------
    property var listings: ({})             // "remote:path" → { at, entries, more }
    property int listingSeconds: 60
    // done({ ok, entries, more, problem }). One level; kept for a minute unless `fresh`.
    function list(id: string, path: string, fresh: bool, done: var): void {
        const p = provider(id), key = Rclone.target(id, path);
        if (!enabled || p === null) { done({ ok: false, entries: [], more: false, problem: { kind: command.length === 0 ? "missing" : "remote", detail: "" } }); return; }
        const kept = listings[key];
        if (!fresh && kept !== undefined && Date.now() - kept.at < listingSeconds * 1000) { done({ ok: true, entries: kept.entries, more: kept.more, problem: null }); return; }
        p.list(path, result => {
            if (result.ok) listings[key] = { at: Date.now(), entries: result.entries, more: result.more };
            note(id, result.ok ? null : result.problem);
            done(result);
        });
    }
    function forget(id: string, path: string): void { delete listings[Rclone.target(id, path)]; }

    // ---- how full, and what is wrong -----------------------------------------------------
    property var abouts: ({})               // id → { used, total, free } | null (the cloud does not say)
    property var troubles: ({})             // id → { kind, detail }: the last question failed
    function level(id: string): string { return Rclone.storageLevel(abouts[id] || null, warnPercent, criticalPercent); }
    function note(id: string, problem: var): void {
        const all = Object.assign({}, troubles);
        if (problem) all[id] = problem; else delete all[id];
        troubles = all;
        judge(id);
    }
    function refreshStorage(): void {
        if (!enabled || command.length === 0) return;
        for (const c of clouds) {
            const p = provider(c.id);
            if (p === null) continue;
            p.about(result => {
                if (result.ok) { const all = Object.assign({}, abouts); all[c.id] = result.about; abouts = all; }
                note(c.id, result.ok ? null : result.problem);
            });
        }
    }
    // The page is on screen (set by the page).
    property bool viewing: false
    // (a moment after the page opened: the listing goes first, and two questions at once make a cloud's request limit more likely)
    onViewingChanged: if (viewing && Date.now() - storageAt > 600000) soon.restart()
    readonly property Timer soon: Timer {
        interval: 4000
        onTriggered: { if (!backend.viewing) return; backend.storageAt = Date.now(); if (backend.looked) backend.refreshStorage(); else backend.detect(backend.refreshStorage); }
    }
    property real storageAt: 0
    readonly property Timer storageTimer: Timer {
        interval: backend.viewing ? 600000 : 3 * 3600000
        repeat: true
        running: backend.enabled && (backend.viewing || backend.alerts)
        onTriggered: { backend.storageAt = Date.now(); if (backend.looked) backend.refreshStorage(); else backend.detect(backend.refreshStorage); }
    }

    // ---- sync state --------------------------------------------------------------------
    readonly property var statusSources: [dropboxStatus, syncthingStatus]
    readonly property DropboxStatus dropboxStatus: DropboxStatus {}
    readonly property SyncthingStatus syncthingStatus: SyncthingStatus {}
    property var sourcesFound: ({})         // "Dropbox" → { found, installed, running }
    property var sync: ({})                 // "Dropbox" → { state, progress, problem }
    readonly property bool hasSources: Object.keys(sourcesFound).some(n => sourcesFound[n].found === true)
    // Syncthing is no rclone remote: a card of its own, state only.
    readonly property bool syncthingFound: sourcesFound["Syncthing"] !== undefined && sourcesFound["Syncthing"].found === true
    readonly property string syncthingKey: "cloud:syncthing"
    function setSyncthingKey(key: string): void {
        syncthingStatus.secret = key.trim();
        if (core !== null && core.secretsAvailable) core.writeSecret(syncthingKey, key.trim(), () => {});
        pollSources();
    }
    // { state, progress, source, note }: what is known about a cloud's sync, and from where.
    function syncOf(id: string): var {
        const c = remotes.find(r => r.name === id);
        const mount = mounted.find(m => m.remote === id);
        if (c && c.type === "dropbox" && sourcesFound["Dropbox"] !== undefined && sourcesFound["Dropbox"].found === true) {
            const s = sync["Dropbox"] || { state: "unknown", progress: -1 };
            return { state: s.state, progress: s.progress, source: "Dropbox", note: "" };
        }
        const offline = troubles[id] !== undefined && (troubles[id].kind === "network" || troubles[id].kind === "timeout");
        return { state: offline ? "offline" : "unknown", progress: -1, source: "",
                 note: mount ? Lang.i18n("Mounted at %1 by rclone, which does not say how far a sync is.", mount.path)
                             : Lang.i18n("rclone copies when asked and keeps no sync state; no sync client for this cloud was found on this computer.") };
    }
    function pollSources(): void {
        if (!enabled) return;
        for (const s of statusSources) {
            if (sourcesFound[s.name] === undefined || sourcesFound[s.name].found !== true) continue;
            const ask = () => s.status(result => {
                const before = sync[s.name], all = Object.assign({}, sync);
                all[s.name] = result;
                sync = all;
                if (before !== undefined && before.state === "syncing" && result.state === "synced") synced(s.name);
                judgeSync(s.name, result);
            });
            if (s.needsKey && s.secret.length === 0 && core !== null && core.secretsAvailable)
                core.readSecret(syncthingKey, (ok, value) => { if (ok && value) s.secret = value; ask(); });
            else ask();
        }
    }
    readonly property Timer syncTimer: Timer {
        interval: 10000
        repeat: true
        running: backend.enabled && backend.hasSources && (backend.viewing || backend.indicator)
        onTriggered: backend.pollSources()
    }
    // For the island: is anything syncing, is anything wrong.
    readonly property bool syncing: Object.keys(sync).some(n => sync[n].state === "syncing")
    readonly property real syncProgress: { const s = Object.keys(sync).map(n => sync[n]).find(x => x.state === "syncing"); return s ? s.progress : -1; }
    readonly property bool syncError: Object.keys(sync).some(n => sync[n].state === "error")
    readonly property bool storageWarning: clouds.some(c => level(c.id) === "warning" || level(c.id) === "critical")
    signal synced(string name)

    // ---- alerts ------------------------------------------------------------------------
    // kind: "storage" | "full" | "auth" | "unreachable" | "sync"
    signal alert(string id, string kind, string title, string text)
    signal alertEnded(string id, string kind)
    property var standing: ({})             // "id:kind" → true while the cause lasts
    readonly property var alerted: parsed(alertedJson, ({}))
    function raise(id: string, kind: string, title: string, text: string): void {
        const key = id + ":" + kind;
        if (standing[key] === true) return;                 // said already, and it has not ended since
        const now = Object.assign({}, standing);
        now[key] = true;
        standing = now;
        if (!alerts || !Rclone.due(Number(alerted[key]) || 0, Date.now(), alertPauseHours)) return;
        const said = Object.assign({}, alerted);
        said[key] = Date.now();
        alertedJson = JSON.stringify(said);
        alert(id, kind, title, text);
    }
    function settle(id: string, kind: string): void {
        const key = id + ":" + kind;
        if (standing[key] !== true) return;
        const now = Object.assign({}, standing);
        delete now[key];
        standing = now;
        alertEnded(id, kind);
    }
    function judge(id: string): void {
        const c = cloud(id);
        if (c === null) return;
        const trouble = troubles[id], full = level(id), about = abouts[id];
        if (trouble && trouble.kind === "auth") raise(id, "auth", Lang.i18n("%1: sign-in has run out", c.name), Lang.i18n("Open the Cloud tab for how to connect it again"));
        else settle(id, "auth");
        if (trouble && (trouble.kind === "network" || trouble.kind === "timeout")) raise(id, "unreachable", Lang.i18n("%1 cannot be reached", c.name), "");
        else settle(id, "unreachable");
        if (full === "critical") { settle(id, "storage"); raise(id, "full", Lang.i18n("%1 is full", c.name), Lang.i18n("%1 of %2 used", Lang.percent(Math.floor(Rclone.fullness(about))), size(about.total))); }
        else if (full === "warning") { settle(id, "full"); raise(id, "storage", Lang.i18n("%1 is nearly full", c.name), Lang.i18n("%1 of %2 used", Lang.percent(Math.floor(Rclone.fullness(about))), size(about.total))); }
        else if (full === "ok") { settle(id, "storage"); settle(id, "full"); }
    }
    function judgeSync(name: string, result: var): void {
        if (result.state === "error") raise(name, "sync", Lang.i18n("%1: sync error", name), Lang.i18n("Open its own window to see what is wrong"));
        else settle(name, "sync");
    }
    function judgeAll(): void { for (const c of clouds) judge(c.id); }
    onWarnPercentChanged: judgeAll()
    onCriticalPercentChanged: judgeAll()

    // ---- copies ------------------------------------------------------------------------
    readonly property Component transferMaker: Component { TransferActivity {} }
    property int serial: 0
    // Starts one copy and shows it among the island's transfers. run(progress, done) starts the job.
    function track(kind: string, source: string, target: string, name: string, openUrl: string, run: var, done: var, again: var): var {
        const t = transferMaker.createObject(backend, { transferId: "cloud-" + (++serial), kind: kind, source: source, target: target, fileName: name,
                                                        icon: kind === "upload" ? "cloud-upload" : "cloud-download", openUrl: openUrl,
                                                        detail: kind === "upload" ? Lang.i18n("Uploading") : Lang.i18n("Downloading") });
        if (again) t.retryFn = again;
        const job = run(p => {
            t.percent = p.percent; t.speed = p.speed; t.processedBytes = p.bytes; t.totalBytes = p.total; t.etaSeconds = p.eta;
        }, result => {
            t.state = result.ok ? "done" : result.cancelled ? "cancelled" : "failed";
            t.errorText = result.ok || result.cancelled ? "" : problemText(result.problem, source === "" ? target : source);
            if (hub !== null) hub.finish(t);
            t.destroy(5000);
            if (done) done(result);
        });
        if (job === null) return null;
        t.cancelFn = () => job.cancel();
        if (hub !== null) hub.add(t);
        return job;
    }

    // Fetched into the island's cache, so that a file can be dragged out: "id:path" → { local, size, modified }
    property var ready: ({})
    property var fetching: ({})             // "id:path" → percent (0..100, -1 unknown) while it is fetched
    function cachePath(id: string, path: string): string { return cacheFolder + "/" + id + "/" + Rclone.cleanPath(path); }
    // The local copy of a file, if it was fetched and the cloud's file has not changed since; else "".
    function readyPath(id: string, path: string, entry: var): string {
        const r = ready[Rclone.target(id, path)];
        return r !== undefined && r.size === entry.size && r.modified === entry.modified ? r.local : "";
    }
    // done(localPath | ""): quiet = no transfer on the island (the pointer only rested on it).
    function fetch(id: string, path: string, entry: var, quiet: bool, done: var): void {
        const p = provider(id), key = Rclone.target(id, path), c = cloud(id);
        if (p === null || c === null || entry.dir || cacheFolder.length === 0) { if (done) done(""); return; }
        const have = readyPath(id, path, entry);
        if (have.length > 0) { if (done) done(have); return; }
        if (fetching[key] !== undefined) return;
        const dest = cachePath(id, path);
        const mark = v => { const f = Object.assign({}, fetching); if (v === null) delete f[key]; else f[key] = v; fetching = f; };
        mark(-1);
        const finished = result => {
            mark(null);
            if (result.ok) {
                const r = Object.assign({}, ready);
                r[key] = { local: dest, size: entry.size, modified: entry.modified };
                ready = r;
                trimCache();
            }
            if (done) done(result.ok ? dest : "");
        };
        if (quiet) p.fetch(path, dest, s => mark(s.percent), finished);
        else track("download", c.name, "", entry.name, "", (progress, end) => p.fetch(path, dest, s => { mark(s.percent); progress(s); }, end), finished, null);
    }
    // Whole folders fetched into the cache: "id:path" → local folder. Everything under one can be dragged out.
    property var readyFolders: ({})
    property var fetchingFolders: ({})      // "id:path" → percent while it is fetched
    // The local copy of a file or folder if it is here (itself, or inside a fetched folder); else "".
    function localOf(id: string, path: string, entry: var): string {
        const clean = Rclone.cleanPath(path);
        if (!entry.dir) { const own = readyPath(id, clean, entry); if (own.length > 0) return own; }
        const parts = clean.length > 0 ? clean.split("/") : [];
        for (let n = entry.dir ? parts.length : parts.length - 1; n >= 0; --n)
            if (readyFolders[Rclone.target(id, parts.slice(0, n).join("/"))] !== undefined) return cachePath(id, clean);
        return "";
    }
    function folderReady(id: string, path: string): bool { return localOf(id, path, { dir: true }).length > 0; }
    // done(localFolder | ""): the folder with everything under it. quiet = no transfer on the island.
    function fetchFolder(id: string, path: string, quiet: bool, done: var): void {
        const p = provider(id), key = Rclone.target(id, path), c = cloud(id);
        if (p === null || c === null || cacheFolder.length === 0) { if (done) done(""); return; }
        if (folderReady(id, path)) { if (done) done(cachePath(id, path)); return; }
        if (fetchingFolders[key] !== undefined) return;
        const dest = cachePath(id, path);
        const mark = v => { const f = Object.assign({}, fetchingFolders); if (v === null) delete f[key]; else f[key] = v; fetchingFolders = f; };
        mark(-1);
        const finished = result => {
            mark(null);
            if (result.ok) { const r = Object.assign({}, readyFolders); r[key] = dest; readyFolders = r; trimCache(); }
            if (done) done(result.ok ? dest : "");
        };
        const name = Rclone.cleanPath(path).length > 0 ? Rclone.baseName(path) : c.name;
        if (quiet) p.fetchFolder(path, dest, s => mark(s.percent), finished);
        else track("download", c.name, "", name, "", (progress, end) => p.fetchFolder(path, dest, s => { mark(s.percent); progress(s); }, end), finished, null);
    }
    // The folder that was opened is measured and, when it is small enough, fetched quietly, so that it and
    // what is in it can be dragged out at once. A larger one waits to be asked for.
    readonly property var autoFolder: ({ bytes: autoFetchMB * 4 * 1048576, count: 300 })
    function prefetch(id: string, path: string): void {
        if (!enabled || autoFetchMB <= 0 || folderReady(id, path) || fetchingFolders[Rclone.target(id, path)] !== undefined) return;
        measure(id, path, size => {
            if (size.ok && size.count > 0 && size.bytes <= autoFolder.bytes && size.count <= autoFolder.count) fetchFolder(id, path, true, null);
        });
    }
    // To the Downloads folder, never over a file that is there: "name (1).ext". done(localPath | "")
    function download(id: string, path: string, entry: var, done: var): void {
        const p = provider(id), c = cloud(id);
        if (p === null || c === null || downloadsFolder.length === 0) { if (done) done(""); return; }
        local.run("ls", ["-A", "--", downloadsFolder], (code, out) => {
            const name = Rclone.uniqueName(entry.name, code === 0 ? out.split("\n") : []);
            const dest = downloadsFolder + "/" + name;
            const start = () => track("download", c.name, "", name, Rclone.fileUrl(entry.dir ? dest : downloadsFolder),
                                      (progress, end) => p.download(path, dest, entry.dir, progress, end),
                                      result => { if (done) done(result.ok ? dest : ""); }, start);
            start();
        });
    }
    // A folder is measured before it is fetched. Above `askAbove` the page asks; above `refuseAbove` it is not done from here.
    readonly property var askAbove: ({ bytes: 200 * 1048576, count: 200 })
    readonly property var refuseAbove: ({ bytes: 5 * 1073741824, count: 5000 })
    function measure(id: string, path: string, done: var): void {
        const p = provider(id);
        if (p === null) { done({ ok: false, count: 0, bytes: 0 }); return; }
        p.size(path, done);
    }
    function trimCache(): void {
        if (local === null || cacheFolder.length === 0) return;
        local.run("find", [cacheFolder, "-type", "f", "-printf", "%T@\t%s\t%p\n"], (code, out) => {
            if (code !== 0) return;
            const files = out.split("\n").map(l => l.split("\t")).filter(f => f.length === 3).map(f => ({ at: Number(f[0]), size: Number(f[1]), path: f[2] }))
                             .sort((a, b) => a.at - b.at);
            let total = files.reduce((n, f) => n + f.size, 0);
            // the oldest go first, until it fits; what was thinned out does not count as fetched any more
            let removed = false;
            for (const f of files) {
                if (total <= cacheMB * 1048576) break;
                if (f.path.indexOf(cacheFolder + "/") === 0 && local.removeFile(f.path)) { total -= f.size; removed = true; }
            }
            if (removed) { ready = ({}); readyFolders = ({}); }
        });
    }

    // ---- uploads -----------------------------------------------------------------------
    // What dropping these would mean: done({ items: [{ local, name, folder, bytes, count, exists }], bytes, count, big }).
    // Only local files; what the target holds is asked afresh, so "exists" is true now.
    readonly property var bigUpload: ({ bytes: 2 * 1073741824, count: 500 })
    function plan(urls: var, id: string, path: string, done: var): void {
        const p = provider(id), paths = urls.map(u => Rclone.localPath(u)).filter(x => x.length > 0);
        if (p === null || paths.length === 0) { done({ items: [], bytes: 0, count: 0, big: false }); return; }
        list(id, path, true, listing => {
            const there = listing.ok ? listing.entries.map(e => e.name) : [];
            const items = [];
            let waiting = paths.length;
            const one = () => {
                if (--waiting > 0) return;
                const bytes = items.reduce((n, i) => n + i.bytes, 0), count = items.reduce((n, i) => n + i.count, 0);
                done({ items: items, bytes: bytes, count: count, big: bytes > bigUpload.bytes || count > bigUpload.count });
            };
            for (const file of paths) {
                local.run("stat", ["-L", "-c", "%F\t%s", "--", file], (code, out) => {
                    const parts = out.trim().split("\t"), name = Rclone.baseName(file);
                    if (code !== 0 || parts.length !== 2) { one(); return; }
                    const folder = parts[0] === "directory";
                    const item = { local: file, name: name, folder: folder, bytes: folder ? 0 : Number(parts[1]), count: 1, exists: there.indexOf(name) >= 0 };
                    if (parts[0] !== "directory" && parts[0].indexOf("regular") !== 0) { one(); return; }     // no devices, sockets…
                    items.push(item);
                    if (!folder) { one(); return; }
                    p.ask(["size", "--json", "--", file], 120000, (c2, o2) => {
                        const s = c2 === 0 ? Rclone.parseSize(o2) : null;
                        if (s !== null) { item.bytes = s.bytes; item.count = s.count; }
                        one();
                    });
                });
            }
        });
    }
    signal uploaded(string id, string path)
    // choice for the items that exist there: "overwrite" | "both" (a new name) | "skip". The files on this computer are only read.
    function upload(items: var, id: string, path: string, choice: string): void {
        const p = provider(id), c = cloud(id);
        if (p === null || c === null) return;
        lastTarget = Rclone.target(id, path);
        const kept = listings[Rclone.target(id, path)], there = kept !== undefined ? kept.entries.map(e => e.name) : [];
        let waiting = 0;
        const one = () => { if (--waiting === 0) { forget(id, path); uploaded(id, path); } };
        for (const item of items) {
            if (item.exists && choice === "skip") continue;
            const name = item.exists && choice === "both" ? Rclone.uniqueName(item.name, there) : item.name;
            there.push(name);
            ++waiting;
            const start = () => track("upload", "", c.name, name, "",
                                      (progress, end) => p.upload(item.local, Rclone.join(path, name), item.folder, item.exists && choice === "overwrite", progress, end),
                                      one, () => { ++waiting; start(); });
            start();
        }
        if (waiting === 0) uploaded(id, path);
    }

    // ---- words -------------------------------------------------------------------------
    function size(bytes: real): string {
        if (!(bytes >= 0)) return "";
        const units = ["B", "kB", "MB", "GB", "TB"];
        let n = bytes, u = 0;
        while (n >= 1000 && u < units.length - 1) { n /= 1000; ++u; }
        return (u === 0 || n >= 100 ? Math.round(n) : n.toLocaleString(Lang.locale, "f", 1)) + " " + units[u];
    }
    function stateText(state: string): string {
        return state === "synced" ? Lang.i18n("Up to date") : state === "syncing" ? Lang.i18n("Syncing") : state === "paused" ? Lang.i18n("Paused")
             : state === "error" ? Lang.i18n("Error") : state === "offline" ? Lang.i18n("Offline") : Lang.i18n("Sync state unknown");
    }
    function problemText(problem: var, name: string): string {
        const kind = problem ? problem.kind : "unknown", detail = problem ? String(problem.detail || "") : "";
        switch (kind) {
        case "missing": return Lang.i18n("rclone was not found on this computer.");
        case "auth": return Lang.i18n("The sign-in of %1 has run out. Connect it again in your own terminal:", name);
        case "network": return Lang.i18n("%1 cannot be reached. Is there a connection?", name);
        case "timeout": return Lang.i18n("%1 did not answer in time.", name);
        case "notfound": return Lang.i18n("This folder is not there any more.");
        case "denied": return Lang.i18n("%1 does not allow this.", name);
        case "remote": return Lang.i18n("rclone does not know %1 any more.", name);
        case "full": return Lang.i18n("%1 has no room left.", name);
        case "busy": return Lang.i18n("%1 is being asked too often right now and makes everyone wait. Try again in a moment.", name);
        }
        return detail.length > 0 ? detail : Lang.i18n("Something went wrong.");
    }
    function reconnectCommand(id: string): string { return Rclone.reconnectCommand(id); }

    onEnabledChanged: if (!enabled) { listings = ({}); looked = false; readyFolders = ({}); }
}
