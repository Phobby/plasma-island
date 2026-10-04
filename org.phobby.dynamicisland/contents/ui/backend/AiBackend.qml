/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The AI tab's part that outlives the page: which sources of answers are
    connected, the one conversation, and the request that is running. It
    lives as long as the shell (main.qml), so a question keeps being answered
    after the island closed or another tab was chosen, and the page finds the
    conversation again. A plain question-and-answer box: text in, text out;
    no source is ever given a tool, a file or anything the user did not type.

    `sourcesJson` is a JSON list of { id, kind, server, model } and is stored
    in the widget configuration; the kinds are those of ai/AiCatalog.qml.
    Keys live in KDE Wallet (native core) under "ai:<id>" and, without it,
    only in memory until the shell restarts; they are never written to the
    settings, a log, a message or a command line, are read from the wallet
    only when a question is asked, and are deleted from it when the source is
    disconnected (also from the settings window).

    A message is { role: "user" | "assistant", text, source (id) } and may
    carry: cut (stopped at the length limit), stopped (by the user), problem
    ({ kind, detail }, see ai/AiStream.js). Every provider is told the whole
    conversation with each question (none keeps it), without the questions
    that got no answer.

    Before anything is sent: the tab is on, a source is connected, the text is
    within `maxChars`, and the notice of that source ("what you write is sent
    to…") was accepted once (`acknowledgedJson`). send() refuses otherwise
    and says why; the page cannot go around it.

    The conversation is kept in memory only. With `keepHistory` it is also
    written to ai-chat.json in the island's data folder (for the owner only)
    and read back when the page first opens; switched off, the file is deleted.

    Nothing runs here while no question is being answered: no timer, no
    request, no command.
*/
import QtQuick
import ".."
import "../ai"
import "../ai/AiStream.js" as Stream

QtObject {
    id: backend

    property var core: null                 // NativeBridge
    property bool enabled: false
    onEnabledChanged: if (!enabled) stop()

    // ---- settings --------------------------------------------------------------------
    property string sourcesJson: "[]"
    property string defaultId: ""
    property int maxTokens: 2048            // the longest answer, in tokens
    property int maxChars: 4000             // the longest question, in characters
    property bool keepHistory: false
    property string acknowledgedJson: "[]"  // ids of the sources whose notice was accepted

    // What every source is told first.
    readonly property string systemPrompt: "You are a quick-answer assistant inside a small desktop widget. Answer with text only: "
        + "you have no tools here and cannot read or change files, run commands or browse the web; if asked to, say briefly that this box cannot do that. "
        + "Keep answers short and to the point. Use Markdown only where it helps (lists, code blocks). Answer in the language of the question."

    // ---- sources ---------------------------------------------------------------------
    property AiCatalog catalog: AiCatalog {}
    readonly property var sources: {
        let list = [];
        try { list = JSON.parse(sourcesJson || "[]"); } catch (e) { list = []; }
        if (!Array.isArray(list)) return [];
        return list.filter(s => s && typeof s.id === "string" && s.id.length > 0 && catalog.kind(s.kind) !== null)
                   .map(s => ({ id: s.id, kind: s.kind, name: catalog.kind(s.kind).name, server: String(s.server || ""), model: String(s.model || "") }));
    }
    readonly property bool available: enabled && sources.length > 0
    // Chosen on the page for now; "" = the default one.
    property string chosenId: ""
    readonly property var current: sources.find(s => s.id === chosenId) || sources.find(s => s.id === defaultId) || sources[0] || null
    function source(id: string): var { return sources.find(s => s.id === id) || null; }
    function store(list: var): void {
        sourcesJson = JSON.stringify(list.map(s => ({ id: s.id, kind: s.kind, server: s.server, model: s.model })));
    }
    function serverOf(s: var): string { return s.server.length > 0 ? s.server : String(catalog.kind(s.kind).server || ""); }
    // "cli", "device" or "remote": a server the user named counts as this device only when its address is.
    function whereOf(s: var): string {
        const info = catalog.kind(s.kind);
        if (info.where !== "device") return info.where;
        return Stream.isThisDevice(Stream.address(serverOf(s)).host) ? "device" : "remote";
    }
    function label(s: var): string {
        const a = Stream.address(s.server);
        return a.ok ? Lang.i18n("%1 · %2", s.name, a.host) : s.name;
    }

    // ---- providers -------------------------------------------------------------------
    // One per source, made when first needed.
    property var drivers: ({})
    property var components: ({})
    function driverOf(kindName: string): var {
        const info = catalog.kind(kindName);
        if (info === null) return null;
        let component = info.driver;
        if (typeof component === "string") {
            component = components[info.driver];
            if (component === undefined) components[info.driver] = component = Qt.createComponent(Qt.resolvedUrl("../ai/" + info.driver));
        }
        if (component.status !== Component.Ready) {
            console.warn("org.phobby.dynamicisland: AI provider", kindName, "could not be loaded:", component.errorString());
            return null;
        }
        return component.createObject(backend, { core: backend.core, options: info, server: String(info.server || "") });
    }
    function driver(s: var): var {
        let d = drivers[s.id];
        if (!d) {
            d = driverOf(s.kind);
            if (d === null) return null;
            drivers[s.id] = d;
        }
        d.core = core;
        d.server = serverOf(s);
        return d;
    }

    // ---- keys ------------------------------------------------------------------------
    property var secrets: ({})              // id → key, in memory
    function secretKey(id: string): string { return "ai:" + id; }
    readonly property bool walletReady: core !== null && core.secretsAvailable
    // then(key): "" where the kind has none, or where it is not to be had any more.
    function withSecret(s: var, then: var): void {
        if (catalog.kind(s.kind).key !== true) { then(""); return; }
        if (secrets[s.id]) { then(secrets[s.id]); return; }
        if (!walletReady) { then(""); return; }
        core.readSecret(secretKey(s.id), (ok, value) => {
            if (ok && value) secrets[s.id] = value;
            then(ok && value ? value : "");
        });
    }
    // Sources that are gone (disconnected here or in the settings window): their key leaves the wallet too.
    property var known: ({})                // id → kind
    readonly property string idSignature: sources.map(s => s.id).join("\n")
    onIdSignatureChanged: forget()
    function forget(): void {
        const now = {};
        for (const s of sources) now[s.id] = s.kind;
        for (const id in known) {
            if (now[id] !== undefined) continue;
            if (busySource === id) stop();
            delete secrets[id];
            delete modelLists[id];
            if (drivers[id]) { drivers[id].destroy(); delete drivers[id]; }
            const info = catalog.kind(known[id]);
            if (info !== null && info.key === true && walletReady) core.removeSecret(secretKey(id));
            if (acknowledged(id)) acknowledgedJson = JSON.stringify(acknowledgedIds.filter(x => x !== id));
        }
        known = now;
    }

    // ---- models ----------------------------------------------------------------------
    property var modelLists: ({})           // id → [{ id, name }], as long as the shell
    // done(models, problem): asked of the source once, then remembered.
    function models(s: var, done: var): void {
        if (modelLists[s.id] !== undefined) { done(modelLists[s.id], null); return; }
        fetchModels(s, done);
    }
    function fetchModels(s: var, done: var): void {
        withSecret(s, secret => {
            const d = driver(s);
            if (d === null) { done([], Stream.problem("unknown", "")); return; }
            d.secret = secret;
            d.listModels(result => {
                if (result.ok) {
                    const lists = Object.assign({}, modelLists);
                    lists[s.id] = result.models;
                    modelLists = lists;
                }
                done(result.ok ? result.models : [], result.problem);
            });
        });
    }
    function setModel(id: string, model: string): void {
        store(sources.map(s => s.id === id ? Object.assign({}, s, { model: model }) : s));
    }
    // The model a kind would rather have, when the source offers it; else the first it lists.
    function pick(info: var, list: var): string {
        const want = String(info.prefer || "");
        return list.some(m => m.id === want) ? want : list.length > 0 ? list[0].id : "";
    }

    // ---- looking for what is on this computer --------------------------------------------
    property var probes: ({})               // kind → a provider only used for looking
    // done({ kind: { found, … } }) for the kinds that are looked for by themselves. Starts nothing, installs nothing.
    function detect(done: var): void {
        const names = catalog.order.filter(k => catalog.kind(k).probe === true);
        const result = {};
        let waiting = names.length;
        if (waiting === 0) { done(result); return; }
        for (const name of names) {
            let d = probes[name];
            if (!d) probes[name] = d = driverOf(name);
            if (!d) { result[name] = { found: false }; if (--waiting === 0) done(result); continue; }
            d.core = core;
            d.detect(found => { result[name] = found; if (--waiting === 0) done(result); });
        }
    }

    // ---- connecting ------------------------------------------------------------------
    // fields: { server, key }. done({ ok, id, error, kept }); kept = the key is in the wallet
    // (false: only until the shell restarts). Nothing is stored before the source has answered.
    function connect(kindName: string, fields: var, done: var): void {
        const info = catalog.kind(kindName);
        if (info === null) { done({ ok: false, id: "", error: Lang.i18n("This kind of source is not known."), kept: false }); return; }
        let server = "";
        if (info.needsServer === true) {
            const a = Stream.address(fields.server);
            if (!a.ok) { done({ ok: false, id: "", error: Lang.i18n("Enter the server's address, starting with http:// or https://."), kept: false }); return; }
            server = a.base;
        }
        const key = String(fields.key || "").trim();
        if (info.key === true && key.length === 0) { done({ ok: false, id: "", error: Lang.i18n("Paste the key first."), kept: false }); return; }
        const d = driverOf(kindName);
        if (d === null) { done({ ok: false, id: "", error: Lang.i18n("This kind of source could not be loaded."), kept: false }); return; }
        if (server.length > 0) d.server = server;
        d.secret = key;
        d.verify(result => {
            if (!result.ok) {
                d.destroy();
                done({ ok: false, id: "", error: problemText(result.problem, info.where, info.name), kept: false });
                return;
            }
            const same = sources.find(s => s.kind === kindName && s.server === server);
            let id = same ? same.id : kindName + "-" + Date.now().toString(36);
            while (!same && source(id) !== null) id += "x";         // (two in the same millisecond)
            if (drivers[id]) drivers[id].destroy();
            drivers[id] = d;
            const found = result.models || [];
            const lists = Object.assign({}, modelLists);
            lists[id] = found;
            modelLists = lists;
            const stored = kept => {
                // the model: the one the kind prefers, or the only one there is; else it is for the user to choose
                const want = String(info.prefer || "");
                const model = same && same.model.length > 0 ? same.model : info.modelOptional === true ? ""
                            : found.some(m => m.id === want) ? want : found.length === 1 ? found[0].id : "";
                const entry = { id: id, kind: kindName, server: server, model: model };
                store(same ? sources.map(s => s.id === id ? entry : s) : sources.concat([entry]));
                done({ ok: true, id: id, error: "", kept: kept });
            };
            if (info.key !== true) { stored(true); return; }
            secrets[id] = key;
            if (walletReady) core.writeSecret(secretKey(id), key, ok => stored(ok === true)); else stored(false);
        });
    }
    // Forgets the source; its key is deleted from the wallet (see forget()).
    function disconnect(id: string): void {
        store(sources.filter(s => s.id !== id));
        if (chosenId === id) chosenId = "";
    }

    // ---- the notice ------------------------------------------------------------------
    readonly property var acknowledgedIds: {
        try { const list = JSON.parse(acknowledgedJson || "[]"); return Array.isArray(list) ? list.map(String) : []; } catch (e) { return []; }
    }
    function acknowledged(id: string): bool { return acknowledgedIds.indexOf(id) >= 0; }
    function acknowledge(id: string): void {
        if (source(id) !== null && !acknowledged(id)) acknowledgedJson = JSON.stringify(acknowledgedIds.concat([id]));
    }
    // What is said once before the first message to a source.
    function noticeText(s: var): string {
        const where = whereOf(s), host = Stream.address(serverOf(s)).host;
        if (where === "cli") return Lang.i18n("What you write here is sent to Claude, through the Claude Code on this computer and the account it is signed in with. Every question uses up some of that account's usage.");
        if (where === "device") return Lang.i18n("What you write here goes to the model server on this computer (%1) and stays on this device. No account, no key.", host);
        return Lang.i18n("What you write here is sent to %1 (%2). Every question uses up your quota there and may cost money.", s.name, host);
    }

    // ---- the conversation --------------------------------------------------------------
    property var messages: []
    property string streaming: ""           // the answer while it is being written
    property bool busy: false
    property string busySource: ""          // id of the source that is answering
    // The page is on screen (set by the page): nobody has to be told that an answer is ready.
    property bool viewing: false
    onViewingChanged: if (viewing) unseen = false
    // An answer (or what went wrong) arrived while the page was not on screen: a dot on its tab.
    property bool unseen: false
    // What is typed and not sent yet: the page is made anew each time the island opens.
    property string draft: ""
    signal answered(string text)
    signal failed(var problem)

    // What a provider is told: the answered questions with their answers, then the new question.
    function context(): var {
        const out = [];
        for (let i = 0; i < messages.length; ++i) {
            const m = messages[i], next = messages[i + 1];
            if (m.role !== "user") continue;
            if (i === messages.length - 1) out.push({ role: "user", text: m.text });
            else if (next && next.role === "assistant" && next.text.length > 0) out.push({ role: "user", text: m.text }, { role: "assistant", text: next.text });
        }
        return out;
    }
    // It all goes along with every question: a long chat is slow and uses more.
    property int longChat: 12000
    readonly property bool lengthy: {
        let n = 0;
        for (const m of messages) n += m.text.length;
        return n > longChat;
    }

    // Why `text` is not sent: "" (it is), "off", "busy", "empty", "long", "none" (no source), "consent".
    function refusal(text: string): string {
        if (!enabled) return "off";
        if (busy) return "busy";
        const length = String(text || "").trim().length;
        if (length === 0) return "empty";
        if (length > maxChars) return "long";
        if (current === null) return "none";
        return acknowledged(current.id) ? "" : "consent";
    }
    property int turn: 0
    property var active: null               // the provider that is answering
    function send(text: string): string {
        const why = refusal(text);
        if (why.length > 0) return why;
        const s = current, info = catalog.kind(s.kind), mine = ++turn;
        messages = messages.concat([{ role: "user", text: String(text).trim(), source: s.id }]);
        busy = true; busySource = s.id; streaming = ""; waiting = "";
        // (reading the key may wait for the wallet to be unlocked: the clock starts when the question leaves)
        withSecret(s, secret => {
            if (mine !== turn || !busy) return;                     // stopped meanwhile
            if (info.key === true && secret.length === 0) { finish({ ok: false, cut: false, problem: Stream.problem("nokey", "") }); return; }
            const d = driver(s);
            if (d === null) { finish({ ok: false, cut: false, problem: Stream.problem("unknown", "") }); return; }
            d.secret = secret;
            const ask = model => {
                if (mine !== turn || !busy) return;
                active = d;
                watchdog.restart();
                d.send(context(), model, { system: systemPrompt, maxTokens: maxTokens });
            };
            if (s.model.length > 0 || info.modelOptional === true) { ask(s.model); return; }
            // no model chosen yet: the one the kind prefers, else the first the source lists
            models(s, (list, problem) => {
                if (mine !== turn || !busy) return;
                const model = pick(info, list);
                if (model.length === 0) { finish({ ok: false, cut: false, problem: problem || Stream.problem("model", "") }); return; }
                setModel(s.id, model);
                ask(model);
            });
        });
        return "";
    }

    // Pieces arrive faster than they need to be drawn: gathered and shown some 25 times a second.
    property string waiting: ""
    function take(text: string): void {
        waiting += text;
        watchdog.restart();
        if (!flusher.running) flusher.start();
    }
    function flush(): void {
        flusher.stop();
        if (waiting.length === 0) return;
        streaming += waiting;
        waiting = "";
    }
    readonly property Timer flusher: Timer { interval: 40; onTriggered: backend.flush() }
    readonly property Connections link: Connections {
        target: backend.active
        function onDelta(text) { backend.take(text); }
        function onAlive() { if (backend.busy) backend.watchdog.restart(); }
        function onFinished(result) { backend.finish(result); }
    }
    // No word for this long: the request is given up.
    property int timeoutSeconds: 120
    readonly property Timer watchdog: Timer {
        interval: Math.max(1, backend.timeoutSeconds) * 1000
        onTriggered: {
            if (!backend.busy) return;
            ++backend.turn;
            if (backend.active !== null) backend.active.cancel();
            backend.finish({ ok: false, cut: false, problem: Stream.problem("timeout", "") });
        }
    }

    function settle(): var {
        watchdog.stop();
        flush();
        const done = { text: streaming, source: busySource };
        busy = false; active = null; streaming = ""; busySource = "";
        return done;
    }
    function finish(result: var): void {
        if (!busy) return;
        const done = settle(), list = messages.slice();
        if (result.ok && done.text.length > 0) {
            list.push({ role: "assistant", text: done.text, source: done.source, cut: result.cut === true });
            messages = list;
            save();
            unseen = !viewing;
            answered(done.text);
            return;
        }
        // (an answer of nothing is no answer: said so, or that the length limit was used up before a word)
        const problem = result.ok ? Stream.problem(result.cut === true ? "cut" : "empty", "") : result.problem;
        if (done.text.length > 0) list.push({ role: "assistant", text: done.text, source: done.source, problem: problem });
        else list[list.length - 1] = Object.assign({}, list[list.length - 1], { problem: problem });
        messages = list;
        save();
        unseen = !viewing;
        failed(problem);
    }
    // "Stop": what was written so far stays.
    function stop(): void {
        if (!busy) return;
        ++turn;
        if (active !== null) active.cancel();
        const done = settle(), list = messages.slice();
        if (done.text.length > 0) list.push({ role: "assistant", text: done.text, source: done.source, stopped: true });
        else list[list.length - 1] = Object.assign({}, list[list.length - 1], { stopped: true });
        messages = list;
        save();
    }
    // The last question again (it got no answer, or the answer broke off).
    function retry(): string {
        if (busy) return "busy";
        const list = messages.slice();
        let last = list.pop();
        if (last && last.role === "assistant" && (last.problem || last.stopped)) last = list.pop();
        if (!last || last.role !== "user") return "empty";
        const before = messages;
        messages = list;
        const why = send(last.text);
        if (why.length > 0) messages = before;
        return why;
    }
    function newChat(): void {
        stop();
        messages = [];
        save();
    }

    // What went wrong, in words a user can act on. where: "cli" | "device" | "remote".
    function problemText(problem: var, where: string, name: string): string {
        const kind = problem ? problem.kind : "unknown", detail = problem ? String(problem.detail || "") : "";
        const said = text => detail.length > 0 ? Lang.i18n("%1 (%2)", text, detail) : text;
        switch (kind) {
        case "auth": return where === "cli" ? Lang.i18n("Claude Code is not signed in. Run “claude” in a terminal, sign in, then ask again.")
                                             : said(Lang.i18n("%1 did not accept the key.", name));
        case "nokey": return Lang.i18n("The key of %1 is not in KDE Wallet any more. Disconnect it and connect it again.", name);
        case "network": return where === "device" ? Lang.i18n("The model server on this computer did not answer. Is it running?")
                                                  : Lang.i18n("No connection to %1, or it was cut.", name);
        case "limit": return said(Lang.i18n("A usage limit of %1 was reached. Try again later.", name));
        case "timeout": return Lang.i18n("%1 did not answer in time.", name);
        case "model": return said(Lang.i18n("%1 does not have this model.", name));
        case "server": return said(Lang.i18n("%1 has a problem of its own right now. Try again later.", name));
        case "refused": return Lang.i18n("The model declined to answer this.");
        case "tools": return Lang.i18n("Claude Code reached for a tool. It was stopped at once; this box only takes text answers.");
        case "version": return said(Lang.i18n("This Claude Code does not take the options that keep its tools off, so it is not used."));
        case "missing": return Lang.i18n("Claude Code could not be started.");
        case "empty": return Lang.i18n("The model gave no answer.");
        case "cut": return Lang.i18n("The length limit was used up before an answer came. Raise it in the settings, or choose another model.");
        }
        return detail.length > 0 ? detail : Lang.i18n("Something went wrong.");
    }
    function problemOf(message: var): string {
        const s = source(message.source);
        return problemText(message.problem, s ? whereOf(s) : "remote", s ? s.name : Lang.i18n("The source"));
    }

    // ---- kept on disk, only when asked for ---------------------------------------------
    readonly property var local: core !== null ? core.local : null
    readonly property string historyPath: local ? local.dataHome() + "/dynamicisland/ai-chat.json" : ""
    readonly property bool canKeep: historyPath.length > 0
    property bool restored: false
    // Called when the page first opens (never at the shell's start).
    function restore(): void {
        if (restored) return;
        restored = true;
        if (!keepHistory || !canKeep || messages.length > 0) return;
        let kept = null;
        try { kept = JSON.parse(local.readTextFile(historyPath, 4000000) || "null"); } catch (e) { kept = null; }
        if (kept === null || !Array.isArray(kept.messages)) return;
        messages = kept.messages.filter(m => m && (m.role === "user" || m.role === "assistant") && typeof m.text === "string")
                                .map(m => ({ role: m.role, text: m.text, source: String(m.source || ""), cut: m.cut === true, stopped: m.stopped === true,
                                             problem: m.problem && typeof m.problem.kind === "string" ? { kind: m.problem.kind, detail: String(m.problem.detail || "") } : undefined }));
    }
    function save(): void {
        if (!keepHistory || !canKeep || !restored) return;
        if (messages.length === 0) { local.removeFile(historyPath); return; }
        const text = JSON.stringify({ version: 1, messages: messages });
        if (typeof local.writePrivateFile === "function") local.writePrivateFile(historyPath, text); else local.writeTextFile(historyPath, text);
    }
    onKeepHistoryChanged: {
        if (!canKeep) return;
        if (keepHistory) save(); else local.removeFile(historyPath);
    }
}
