/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Suggestions: few, and only where they have proved welcome. At a rule's
    moment the island may ask one short question, do the thing by itself
    (saying so, with an Undo), keep the suggestion quietly for when the
    island is opened, or say nothing: Suggestions.js decides from what it
    learned about that rule in that context. Rules and statistics only, on
    this computer: no network, no model.

    The rules (a rule whose part of the system is missing or off never comes up):
      meeting        a calendar event is about to start   → Do Not Disturb until it ends
      meeting-media  …it has a video link and media plays → pause the media
      recording      screen recording / sharing starts    → Do Not Disturb while it lasts
      call           the microphone is taken into use while media plays → pause it
      pomodoro       a Pomodoro focus round starts        → Do Not Disturb until its break
      battery        the battery reaches the low threshold → the power saving profile
      disconnect     the headphones go away while media plays → pause it
      headphones     (experimental, off) headphones are connected while media is paused → play

    How a suggestion comes:
      a card      only for what is over within minutes, at most `dailyCards`
                  a day, not within a rule's wait
      a hint      a small mark on the pill; the suggestion waits in the open
                  island (`pending`, at most three)
      quietly     the same without the mark: while Do Not Disturb is on, an
                  application is full screen, the screen is recorded or the
                  microphone is in use
    A suggestion whose moment has passed goes away by itself; that and a
    suggestion nobody saw teach nothing.

    Learning without asking: when the user does a rule's thing by hand
    within two minutes of its moment, that counts for the rule.

    Whose it is: what a rule switched on is remembered (`owned`) and taken
    back when its cause ends, but only that: something the user switched on
    or changed in between is left alone.

    Nothing but now() reads the clock, and tests replace it (`clock`).
    Everything here happens on a change of something; nothing polls.
*/
import QtQuick
import ".."
import "../Suggestions.js" as Suggestions

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    required property var cfg
    required property var backend           // PlasmaBackend: media, battery, the audio output
    property var core: null                 // NativeBridge: screen casts, microphone, the store's file
    property var dnd: null                  // backend/DndBackend.qml
    property var power: null                // backend/PowerBackend.qml
    property var bluetooth: null            // backend/BluetoothBackend.qml
    property var pomodoro: null             // providers/PomodoroProvider.qml
    property var calendar: null             // providers/CalendarProvider.qml
    property bool enabled: true
    // The parts of the island a rule leans on; one that is switched off takes its rule with it.
    property bool recordingWatched: true
    property bool microphoneWatched: true
    property bool powerWatched: true
    property bool mediaWatched: true
    // An application fills the screen (main.qml tells).
    property bool fullscreen: false
    // The settings: "quiet", "balanced", "active"; 0 = what the level says.
    property string level: "balanced"
    property int dailyCards: 0
    property int cooldownMinutes: 0
    property int halfLifeDays: 0
    // At least this long between two cards of any rules.
    property int gapMinutes: 5
    property int lowBattery: 20
    property int answerSeconds: 12
    property var clock: null
    function now(): real { return typeof clock === "function" ? clock() : Date.now(); }
    readonly property var tuning: Suggestions.tuning(level, dailyCards, cooldownMinutes, halfLifeDays)

    property alias store: learned
    SuggestionStore {
        id: learned
        local: provider.core !== null && provider.core.local ? provider.core.local : null
        cfg: provider.cfg
    }
    SuggestionCatalog { id: catalog }
    function learn(id: string, ctx: string, signal: string): bool {
        const result = Suggestions.record(store.read(), id, ctx, signal, now(), tuning);
        store.write(result.state);
        return result.closed;
    }

    // ---- what is going on -------------------------------------------------------------
    readonly property bool dndOn: dnd !== null && dnd.active
    readonly property bool recording: core !== null && core.screenCastApps.length > 0
    readonly property bool micInUse: core !== null && core.microphoneApps.length > 0
    readonly property var upcoming: calendar !== null && calendar.phase === "upcoming" ? calendar.pinned : null
    readonly property string upcomingKey: upcoming !== null ? String(upcoming.key) : ""
    readonly property bool working: pomodoro !== null && pomodoro.phase === "work"
    readonly property bool batteryLow: backend.hasBattery && !backend.batteryPluggedIn && backend.batteryPercent <= lowBattery
    readonly property string profile: power !== null ? String(power.profile) : ""
    // The audio output: "hp" (headphones, a headset) or "spk", from what the device says of itself.
    readonly property string output: {
        if (!backend.hasSink) return "";
        const sink = backend.sink;
        const port = sink.ports && sink.activePortIndex >= 0 && sink.ports[sink.activePortIndex] ? String(sink.ports[sink.activePortIndex].name || "") : "";
        return /head(phone|set)|hands-free|earbud|kulakl|airpods|buds/i.test(String(sink.formFactor || "") + " " + port + " " + backend.sinkName) ? "hp" : "spk";
    }

    // Which rules this system can make at all.
    readonly property var available: ({
        "meeting": calendar !== null && dnd !== null,
        "meeting-media": calendar !== null && mediaWatched,
        "recording": recordingWatched && core !== null && dnd !== null,
        "call": microphoneWatched && mediaWatched && core !== null,
        "pomodoro": pomodoro !== null && dnd !== null,
        "battery": powerWatched && backend.hasBattery && power !== null && power.profilesAvailable && Array.from(power.profiles).indexOf("power-saver") >= 0,
        "disconnect": mediaWatched && backend.hasSink,
        "headphones": mediaWatched && (bluetooth !== null || backend.hasSink)
    })
    readonly property string availableText: Suggestions.RULES.filter(id => available[id] === true).join(",")
    onAvailableTextChanged: if (cfg.suggestionsAvailable !== availableText) cfg.suggestionsAvailable = availableText
    Component.onCompleted: { if (cfg.suggestionsAvailable !== availableText) cfg.suggestionsAvailable = availableText; ready = true; }
    // Moments that are there when the island starts are not news.
    property bool ready: false

    // Whether the thing a rule would do still makes sense right now.
    function holds(id: string): bool {
        switch (id) {
        case "meeting": return upcoming !== null && !dndOn;
        case "meeting-media": return upcoming !== null && !!upcoming.link && backend.isPlaying;
        case "recording": return recording && !dndOn;
        case "call": return micInUse && backend.isPlaying;
        case "pomodoro": return working && !dndOn;
        case "battery": return batteryLow && profile !== "power-saver";
        case "disconnect": return backend.isPlaying && output !== "hp" && now() - lostAt <= Suggestions.TUNING.window;
        case "headphones": return backend.hasMedia && backend.isPaused;
        }
        return false;
    }
    // The context of a rule's moment: coarse buckets only (Suggestions.context).
    function contextOf(id: string): string {
        const f = Suggestions.timeFeatures(now());
        if ((id === "meeting" || id === "meeting-media") && upcoming !== null) {
            if (upcoming.calendar) f.calendar = String(upcoming.calendar);
            if (upcoming.end > upcoming.start) f.duration = Suggestions.durationBucket((upcoming.end - upcoming.start) / 60000);
            f.video = !!upcoming.link;
        } else if (id === "call" && output.length > 0) {
            f.output = output;
        } else if (id === "battery") {
            delete f.part;
        }
        return Suggestions.context(f);
    }

    // Nothing interrupts these; a suggestion then only waits in the open island.
    function quietBecause(id: string): string {
        if (dndOn) return "dnd";
        if (fullscreen) return "fullscreen";
        if (recording && id !== "recording") return "recording";
        if (micInUse && id !== "call") return "call";
        return "";
    }

    onUpcomingKeyChanged: if (upcomingKey.length > 0) moment("meeting"); else ended("meeting")
    onRecordingChanged: if (recording) moment("recording"); else ended("recording")
    onMicInUseChanged: if (micInUse) moment("call"); else ended("call")
    onBatteryLowChanged: if (batteryLow) moment("battery"); else ended("battery")
    onWorkingChanged: if (working) moment("pomodoro"); else ended("pomodoro")
    // The headphones went away (the output is no longer one) / came.
    property real lostAt: 0
    onOutputChanged: {
        if (!ready) { wasOutput = output; return; }
        if (output === "hp") { moment("headphones"); ended("disconnect"); }
        else if (output === "spk" && wasOutput === "hp") { lostAt = now(); moment("disconnect"); }
        wasOutput = output;
    }
    property string wasOutput: ""
    property var audioDevices: ({})
    function connectedHeadphones(): var {
        const out = {};
        if (bluetooth !== null) for (const d of bluetooth.connectedDevices) if (/headset|headphones/.test(bluetooth.iconFor(d))) out[d.address] = true;
        return out;
    }
    function checkHeadphones(): void {
        const there = connectedHeadphones();
        let came = false, went = false;
        for (const address in there) if (audioDevices[address] !== true) came = true;
        for (const address in audioDevices) if (there[address] !== true) went = true;
        audioDevices = there;
        if (came) moment("headphones");
        if (went && Object.keys(there).length === 0) { lostAt = now(); moment("disconnect"); }
    }
    Connections {
        target: provider.bluetooth
        function onConnectedDevicesChanged() { Qt.callLater(provider.checkHeadphones); }
    }
    onBluetoothChanged: audioDevices = connectedHeadphones()

    // ---- a rule's moment has come -------------------------------------------------------
    // What happened at the last moment of each rule: { ctx, t, done } (for learning from what the
    // user then does by hand).
    property var moments: ({})
    function moment(trigger: string): void {
        if (!enabled || !ready || !manager.warm) return;
        const t = now(), asks = [];
        for (const id of Suggestions.RULES) {
            if (Suggestions.INFO[id].trigger !== trigger || available[id] !== true) continue;
            const ctx = contextOf(id), action = Suggestions.INFO[id].action;
            // done by hand just before: learned from, nothing to suggest
            if (manual[action] !== undefined && t - manual[action] <= Suggestions.TUNING.window && done(action)) {
                moments[id] = { ctx: ctx, t: t, done: true };
                learn(id, ctx, "implicit");
                offerIfDue(id, ctx);
                continue;
            }
            if (!holds(id)) continue;
            moments[id] = { ctx: ctx, t: t, done: false };
            const what = Suggestions.status(store.read(), id, ctx, t, tuning);
            if (what === "auto") {
                act(id, id === "meeting" ? upcoming : null, true);
                learn(id, ctx, "auto");
                announce(id, ctx);
            } else if (what === "ask" || what === "offer") {
                asks.push({ id: id, ctx: ctx, offer: what === "offer" });
            }
        }
        if (asks.length > 0) deliver(trigger, asks);
    }
    // Is the thing an action does already so?
    function done(action: string): bool {
        return action === "dnd" ? dndOn : action === "pause" ? backend.isPaused : action === "saver" ? profile === "power-saver" : backend.isPlaying;
    }

    // As a card, or kept for the open island.
    function deliver(trigger: string, asks: var): void {
        const state = store.read(), t = now();
        const quiet = quietBecause(asks[0].id);
        const timed = Suggestions.INFO[asks[0].id].timed;
        const cards = asks.filter(a => Suggestions.waits(state, a.id, t, tuning, gapMinutes * 60000) === 0);
        if (timed && quiet.length === 0 && cards.length > 0 && Suggestions.cardsToday(state, t) < tuning.dailyCards) {
            card(trigger, cards);
            keep(asks.filter(a => cards.indexOf(a) < 0), false);
        } else {
            keep(asks, quiet.length === 0);
        }
    }

    function actionText(id: string): string {
        const action = Suggestions.INFO[id].action;
        return action === "dnd" ? Lang.i18n("Do Not Disturb") : action === "pause" ? Lang.i18n("Pause the media")
             : action === "saver" ? Lang.i18n("Power saving profile") : Lang.i18n("Carry on playing");
    }
    function question(id: string): string {
        switch (id) {
        case "meeting": return Lang.i18n("“%1” starts soon. Turn on Do Not Disturb until it ends?", upcoming !== null && upcoming.title ? upcoming.title : Lang.i18n("Event"));
        case "meeting-media": return Lang.i18n("“%1” starts soon. Pause the media?", upcoming !== null && upcoming.title ? upcoming.title : Lang.i18n("Event"));
        case "recording": return Lang.i18n("The screen is being recorded. Hide notifications while it lasts?");
        case "call": return Lang.i18n("The microphone is in use. Pause the media?");
        case "battery": return Lang.i18n("The battery is low (%1). Switch to the power saving profile?", Lang.percent(backend.batteryPercent));
        case "pomodoro": return Lang.i18n("A focus round has started. Turn on Do Not Disturb until the break?");
        case "disconnect": return Lang.i18n("The headphones are gone. Pause the media?");
        case "headphones": return Lang.i18n("Headphones are connected. Carry on playing?");
        }
        return "";
    }
    function iconOf(id: string): string {
        const action = Suggestions.INFO[id].action;
        return id === "call" ? "audio-input-microphone-symbolic" : id === "battery" ? "battery-low-symbolic"
             : id === "headphones" || id === "disconnect" ? "audio-headphones-symbolic"
             : action === "pause" ? "media-playback-pause-symbolic" : "notifications-disabled-symbolic";
    }
    function colorOf(id: string): color {
        const action = Suggestions.INFO[id].action;
        return action === "saver" ? theme.live : action === "dnd" ? theme.purple : theme.blue;
    }
    function doneText(id: string): string {
        const action = Suggestions.INFO[id].action;
        return action === "pause" ? Lang.i18n("Media paused") : action === "saver" ? Lang.i18n("Power saving profile is on")
             : action === "play" ? Lang.i18n("Playing again") : Lang.i18n("Do Not Disturb is on");
    }
    // The "Why?" line: what the suggestion goes by, in words.
    function whyText(id: string, ctx: string): string {
        const w = Suggestions.why(store.read(), id, ctx, now(), tuning);
        if (w.kind === "hand") return Lang.i18n("Why? You did this by hand the last %1 times here.", w.n);
        if (w.kind === "answers") return Lang.i18n("Why? You said yes to %1 of the last %2 here.", w.yes, w.of);
        if (w.kind === "similar") return w.welcome ? Lang.i18n("Why? You mostly say yes to this at other times.") : Lang.i18n("Why? New here; at other times you mostly said no.");
        return Lang.i18n("Why? This is the moment the rule is for; I am still learning.");
    }
    function contextText(ctx: string): string { return catalog.contextText(ctx); }

    // ---- a card ---------------------------------------------------------------------------
    // The card that is out: { trigger, asks, subject } (null: none).
    property var out: null
    function card(trigger: string, asks: var): void {
        const subject = trigger === "meeting" ? upcoming : null;
        const one = asks.length === 1, first = asks[0];
        if (one && first.offer) { offer(first.id, first.ctx); return; }
        const mine = { trigger: trigger, asks: asks, subject: subject };
        // several things for one moment: one card, each ticked by itself
        const checks = one ? [] : asks.map(a => ({ text: provider.actionText(a.id), checked: true }));
        const each = signal => { for (let i = 0; i < asks.length; ++i) provider.answered(asks[i], one || checks[i].checked ? signal : "no", subject); };
        const all = signal => { for (const a of asks) provider.answered(a, signal, subject); };
        out = mine;
        manager.flash({
            key: "suggestion",
            live: true,
            // the screen recording itself outranks events: its question has to come through
            force: trigger === "recording",
            icon: one ? iconOf(first.id) : "view-calendar-symbolic",
            color: colorOf(first.id),
            title: one ? question(first.id) : Lang.i18n("“%1” starts soon.", subject !== null && subject.title ? subject.title : Lang.i18n("Event")),
            subtitle: whyText(first.id, first.ctx),
            checks: checks,
            width: theme.notificationWidth,
            height: theme.questionHeight + (one ? 0 : 24),
            duration: answerSeconds * 1000,
            buttons: [
                { text: Lang.i18n("Yes"), primary: true, trigger: () => each("yes") },
                { text: Lang.i18n("Always"), trigger: () => each("always") },
                { text: Lang.i18n("No"), trigger: () => all("no") },
                { text: Lang.i18n("Not now"), more: true, trigger: () => all("later") },
                { text: Lang.i18n("Turn this rule off"), more: true, trigger: () => all("never") }
            ],
            shown: () => { for (const a of asks) provider.learn(a.id, a.ctx, "shown"); },
            expired: () => all("timeout"),
            closed: () => all("later")
        });
    }
    function answered(ask: var, what: string, subject: var): void {
        out = null;
        drop(ask.id);
        if (what === "never") { store.write(Suggestions.never(store.read(), ask.id)); return; }
        learn(ask.id, ask.ctx, what);
        if (what === "yes" || what === "always") {
            act(ask.id, subject, false);
            if (what === "always") note("media-playlist-repeat-symbolic", colorOf(ask.id), Lang.i18n("Automatic from now on"), contextText(ask.ctx));
            else offerIfDue(ask.id, ask.ctx);
        }
    }
    // Its moment passed before anybody answered: it goes away and teaches nothing.
    function withdraw(trigger: string): void {
        if (out !== null && out.trigger === trigger) {
            out = null;
            if (manager.currentEvent !== null && manager.currentEvent.key === "suggestion") manager.dismissEvent();
            manager.queue = manager.queue.filter(q => q.key !== "suggestion");
        }
        const left = pending.filter(p => Suggestions.INFO[p.id].trigger !== trigger);
        if (left.length !== pending.length) pending = left;
    }

    // "Shall I do this by myself from now on?": asked once per context, when it is sure enough or
    // the user has done it by hand often enough.
    function offerIfDue(id: string, ctx: string): void {
        if (Suggestions.status(store.read(), id, ctx, now(), tuning) === "offer") offer(id, ctx);
    }
    function offer(id: string, ctx: string): void {
        const e = Suggestions.estimate(store.read(), id, ctx, now(), tuning);
        const decline = () => store.write(Suggestions.automatic(store.read(), id, ctx, false, provider.now()));
        manager.flash({
            key: "suggestion-offer",
            icon: "media-playlist-repeat-symbolic",
            color: colorOf(id),
            title: e.implicit >= Suggestions.TUNING.implicitOffer
                   ? Lang.i18n("You did this by hand the last %1 times: %2. Shall I do it by myself?", e.implicit, actionText(id))
                   : Lang.i18n("Shall I do this by myself from now on? %1", actionText(id)),
            subtitle: catalog.title(id) + " · " + contextText(ctx),
            width: theme.notificationWidth,
            height: theme.questionHeight,
            duration: answerSeconds * 1000,
            buttons: [
                { text: Lang.i18n("Yes"), primary: true, trigger: () => {
                    store.write(Suggestions.automatic(store.read(), id, ctx, true, provider.now()));
                    if (provider.holds(id)) { provider.act(id, id === "meeting" ? provider.upcoming : null, true); provider.learn(id, ctx, "auto"); }
                    provider.note("media-playlist-repeat-symbolic", provider.colorOf(id), Lang.i18n("Automatic from now on"), Lang.i18n("It says so each time, with an Undo"));
                } },
                { text: Lang.i18n("No, keep asking"), trigger: decline }
            ],
            expired: decline,
            closed: decline
        });
    }
    function note(icon: string, color: color, title: string, subtitle: string): void {
        manager.flash({ key: "suggestion-note", icon: icon, color: color, title: title, subtitle: subtitle, duration: 4500 });
    }

    // ---- kept for the open island ---------------------------------------------------------
    // [{ id, ctx, title, why, icon, color, hint }], at most three; the island shows them when it is opened.
    property var pending: []
    readonly property bool hint: enabled && pending.some(p => p.hint) && quietBecause("") === ""
    function keep(asks: var, hinted: bool): void {
        if (asks.length === 0) return;
        let list = pending.filter(p => !asks.some(a => a.id === p.id));
        for (const a of asks) {
            list.push({ id: a.id, ctx: a.ctx, offer: a.offer, title: question(a.id), why: whyText(a.id, a.ctx), icon: iconOf(a.id), color: colorOf(a.id),
                        hint: hinted, subject: a.id === "meeting" ? upcoming : null });
        }
        pending = list.slice(-Suggestions.TUNING.maxPending);
    }
    function drop(id: string): void {
        if (pending.some(p => p.id === id)) pending = pending.filter(p => p.id !== id);
    }
    // An answer given in the open island: "yes", "always", "no", "later", "never".
    function answerPending(id: string, what: string): void {
        const p = pending.find(x => x.id === id);
        if (!p) return;
        answered({ id: p.id, ctx: p.ctx, offer: p.offer }, what, p.subject);
    }
    // What a kept suggestion was about is over, or was done meanwhile.
    function prune(): void {
        if (pending.length === 0) return;
        const left = pending.filter(p => provider.holds(p.id));
        if (left.length !== pending.length) pending = left;
    }
    onEnabledChanged: if (!enabled) { pending = []; withdraw(out !== null ? out.trigger : ""); }

    // ---- doing it, and whose it is ------------------------------------------------------------
    // What a rule switched on and may take back: { dnd: { id, ctx, auto, until }, media: {…}, profile: { …, before } }
    property var owned: ({})
    // What this is about to change itself (so that the change is not taken for the user's).
    property var expected: ({})
    // When the user last did a thing by hand: { dnd, pause, saver, play } → ms
    property var manual: ({})
    function own(slot: string, id: string, ctx: string, auto: bool, more: var): void {
        const all = Object.assign({}, owned);
        all[slot] = Object.assign({ id: id, ctx: ctx, auto: auto }, more || {});
        owned = all;
    }
    function disown(slot: string): void {
        if (owned[slot] === undefined) return;
        const all = Object.assign({}, owned);
        delete all[slot];
        owned = all;
    }
    function setDnd(on: bool, until: real): void {
        if (dndOn === on) return;
        expected.dnd = on;
        if (on && until > now()) dnd.setActiveUntil(new Date(until)); else dnd.setActive(on);
    }
    function setPlaying(on: bool): void {
        if (backend.isPlaying === on) return;
        expected.playing = on;
        backend.playPause();
    }
    function setProfile(name: string): void {
        if (profile === name) return;
        expected.profile = name;
        power.setProfile(name);
    }
    function act(id: string, subject: var, auto: bool): void {
        const ctx = moments[id] ? moments[id].ctx : contextOf(id);
        switch (Suggestions.INFO[id].action) {
        case "dnd":
            if (dndOn) return;                  // the user's own: not ours to end
            // an event's: until it ends (Plasma switches it off by itself then)
            own("dnd", id, ctx, auto, { until: subject && subject.end > now() ? subject.end : 0 });
            setDnd(true, subject && subject.end > now() ? subject.end : 0);
            break;
        case "pause":
            if (!backend.isPlaying) return;
            own("media", id, ctx, auto);
            setPlaying(false);
            break;
        case "saver":
            if (profile === "power-saver") return;
            own("profile", id, ctx, auto, { before: profile });
            setProfile("power-saver");
            break;
        case "play":
            if (!backend.isPaused) return;
            own("media", id, ctx, auto);
            setPlaying(true);
            break;
        }
    }
    // A rule's cause is over: what it switched on, and only that, is taken back; a suggestion
    // about it goes away.
    function ended(trigger: string): void {
        withdraw(trigger);
        prune();
        for (const slot of ["dnd", "media", "profile"]) {
            const o = owned[slot];
            if (o === undefined || Suggestions.INFO[o.id].trigger !== trigger || !Suggestions.INFO[o.id].ends) continue;
            disown(slot);
            if (slot === "dnd") setDnd(false, 0);
            else if (slot === "media") { if (backend.isPaused) setPlaying(true); }
            else if (profile === "power-saver") setProfile(o.before.length > 0 ? o.before : "balanced");
        }
    }

    // A thing changed. Ours (expected), the system's own (an event's Do Not Disturb running
    // out), or the user's: theirs teaches, and ends our hold on it.
    function changed(slot: string, action: string, on: bool, key: string, value: var): void {
        if (expected[key] !== undefined) {
            const ours = expected[key] === value;
            delete expected[key];
            if (ours) return;
        }
        const t = now(), o = owned[slot];
        if (o !== undefined && !on) {
            disown(slot);
            // an event's Do Not Disturb that ran out is nobody's doing
            if (slot === "dnd" && o.until > 0 && t >= o.until - 5000) return;
            // switched back by hand what was done by itself: taken as an "Undo"
            if (o.auto) undone(o.id, o.ctx, false);
            return;
        }
        if (!on) return;
        manual[action] = t;
        // by hand at a rule's moment: the rule learns, and a suggestion about it is not needed
        for (const id of Suggestions.RULES) {
            const m = moments[id];
            if (Suggestions.INFO[id].action !== action || !m || m.done || t - m.t > Suggestions.TUNING.window) continue;
            m.done = true;
            if (out !== null && out.asks.some(a => a.id === id)) withdraw(out.trigger);
            drop(id);
            learn(id, m.ctx, "implicit");
            offerIfDue(id, m.ctx);
        }
        prune();
    }
    onDndOnChanged: if (ready) changed("dnd", "dnd", dndOn, "dnd", dndOn)
    onProfileChanged: if (ready) changed("profile", "saver", profile === "power-saver", "profile", profile)
    Connections {
        target: provider.backend
        function onIsPlayingChanged() {
            if (!provider.ready) return;
            // a pause, not a track ending or a player closing
            if (provider.backend.isPlaying) provider.changed("media", "play", true, "playing", true);
            else if (provider.backend.isPaused) provider.changed("media", "pause", true, "playing", false);
        }
    }

    // Done by itself: said, with an Undo. Under the key of the change's own event (Do Not
    // Disturb, the power profile), a moment after it, so that the island shows one event for it.
    function announce(id: string, ctx: string): void {
        const action = Suggestions.INFO[id].action;
        said.pending = {
            key: action === "saver" ? "power-profile" : action === "dnd" ? "dnd" : "suggestion-done",
            icon: iconOf(id),
            color: colorOf(id),
            title: doneText(id),
            subtitle: Lang.i18n("Done automatically"),
            trailing: { type: "button", text: Lang.i18n("Undo") },
            activate: () => provider.undone(id, ctx, true),
            duration: 8000
        };
        said.restart();
    }
    Timer {
        id: said
        property var pending: null
        interval: 400
        onTriggered: if (pending !== null) { provider.manager.flash(pending); pending = null; }
    }
    // "Undo" (or switched back by hand): taken back; here the rule asks again, and the second
    // time it is closed here, which is said once.
    function undone(id: string, ctx: string, revert: bool): void {
        if (revert) {
            const action = Suggestions.INFO[id].action;
            const slot = action === "dnd" ? "dnd" : action === "saver" ? "profile" : "media";
            const o = owned[slot];
            disown(slot);
            if (action === "dnd") setDnd(false, 0);
            else if (action === "saver") setProfile(o !== undefined && o.before.length > 0 ? o.before : "balanced");
            else setPlaying(action === "pause");
        }
        if (learn(id, ctx, "undo")) {
            note("notifications-disabled-symbolic", theme.subText, Lang.i18n("I will not do this here any more"),
                 catalog.title(id) + " · " + contextText(ctx));
        } else {
            note("edit-undo-symbolic", theme.subText, Lang.i18n("Undone"), Lang.i18n("I will ask again next time"));
        }
    }
}
