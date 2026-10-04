/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Suggestions: at the right moment the island asks one short question
    ("The screen is being recorded. Hide notifications while it lasts?") with
    three answers: Yes, Not now, Never suggest this. No answer within ten
    seconds counts as none. It remembers the answers per rule and adapts
    (Suggestions.js): asked less often when it is waved away, switched off
    when it is ignored, and after three yeses in a row it offers to do the
    thing by itself from then on, saying so each time with an "Undo".

    Everything is local and by rule: no network, no model. What was learned
    is one small file (SuggestionStore.qml).

    The rules (a rule whose part of the system is missing or switched off
    never comes up):
      meeting     a calendar event is about to start  → Do Not Disturb until it ends
      recording   screen recording / sharing starts   → Do Not Disturb while it lasts
      call        the microphone is taken into use while media plays → pause it
      battery     the battery reaches the low threshold → the power saving profile
      pomodoro    a Pomodoro focus round starts       → Do Not Disturb until its break
      headphones  headphones are connected while media is paused → play

    Nothing is suggested while Do Not Disturb is on or the screen is recorded
    (the recording's own question comes at its start), nor within
    `gapMinutes` of the last suggestion.

    Nothing but now() reads the clock, and tests replace it (`clock`).
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
    property bool recordingWatched: true    // screen recording / sharing (Activities)
    property bool microphoneWatched: true   // microphone and camera indicators
    property bool powerWatched: true        // charging, battery and power profile
    property bool mediaWatched: true        // the media module
    // At least this long between two suggestions.
    property int gapMinutes: 5
    property int lowBattery: 20
    // How long a question waits for its answer.
    property int answerSeconds: 10
    property var clock: null
    function now(): real { return typeof clock === "function" ? clock() : Date.now(); }

    property alias store: learned
    SuggestionStore {
        id: learned
        local: provider.core !== null && provider.core.local ? provider.core.local : null
        cfg: provider.cfg
    }
    SuggestionCatalog { id: catalog }

    // ---- what is going on -------------------------------------------------------------
    readonly property bool dndOn: dnd !== null && dnd.active
    readonly property bool recording: core !== null && core.screenCastApps.length > 0
    readonly property bool micInUse: core !== null && core.microphoneApps.length > 0
    readonly property var upcoming: calendar !== null && calendar.phase === "upcoming" ? calendar.pinned : null
    readonly property string upcomingKey: upcoming !== null ? String(upcoming.key) : ""
    readonly property bool working: pomodoro !== null && pomodoro.phase === "work"
    readonly property bool batteryLow: backend.hasBattery && !backend.batteryPluggedIn && backend.batteryPercent <= lowBattery

    // Which rules this system can make at all.
    readonly property var available: ({
        meeting: calendar !== null && dnd !== null,
        recording: recordingWatched && core !== null && dnd !== null,
        call: microphoneWatched && mediaWatched && core !== null,
        battery: powerWatched && backend.hasBattery && power !== null && power.profilesAvailable && Array.from(power.profiles).indexOf("power-saver") >= 0,
        pomodoro: pomodoro !== null && dnd !== null,
        headphones: mediaWatched && (bluetooth !== null || backend.hasSink)
    })
    // For the settings page: which rules it can offer.
    readonly property string availableText: Suggestions.RULES.filter(id => available[id] === true).join(",")
    onAvailableTextChanged: if (cfg.suggestionsAvailable !== availableText) cfg.suggestionsAvailable = availableText
    Component.onCompleted: { if (cfg.suggestionsAvailable !== availableText) cfg.suggestionsAvailable = availableText; ready = true; }
    // Moments that are there when the island starts are not news.
    property bool ready: false

    // Whether the thing a rule would do still makes sense right now.
    function holds(id: string): bool {
        switch (id) {
        case "meeting": return upcoming !== null && !dndOn;
        case "recording": return recording && !dndOn;
        case "call": return micInUse && backend.isPlaying;
        case "battery": return batteryLow && power.profile !== "power-saver";
        case "pomodoro": return working && !dndOn;
        case "headphones": return backend.hasMedia && backend.isPaused;
        }
        return false;
    }

    onUpcomingKeyChanged: if (upcomingKey.length > 0) moment("meeting")
    onRecordingChanged: if (recording) moment("recording"); else release("recording")
    onMicInUseChanged: if (micInUse) moment("call")
    onBatteryLowChanged: if (batteryLow) moment("battery")
    onWorkingChanged: if (working) moment("pomodoro"); else release("pomodoro")
    // Headphones: a Bluetooth headset or pair of headphones connects, or the audio output becomes one.
    property var audioDevices: ({})
    function connectedHeadphones(): var {
        const out = {};
        if (bluetooth !== null) for (const d of bluetooth.connectedDevices) if (/headset|headphones/.test(bluetooth.iconFor(d))) out[d.address] = true;
        return out;
    }
    function checkHeadphones(): void {
        const there = connectedHeadphones();
        let fresh = false;
        for (const address in there) if (audioDevices[address] !== true) fresh = true;
        audioDevices = there;
        if (fresh) moment("headphones");
    }
    Connections {
        target: provider.bluetooth
        function onConnectedDevicesChanged() { Qt.callLater(provider.checkHeadphones); }
    }
    Connections {
        target: provider.backend
        function onSinkNameChanged() { if (/head(phone|set)|kulakl|earbud|airpods|buds/i.test(provider.backend.sinkName)) provider.moment("headphones"); }
    }
    onBluetoothChanged: audioDevices = connectedHeadphones()

    // ---- a rule's moment has come -------------------------------------------------------
    function moment(id: string): void {
        if (!enabled || !ready || !manager.warm || available[id] !== true || !holds(id)) return;
        const what = Suggestions.decide(store.read(), id, now(), gapMinutes * 60000);
        if (what === "auto") {
            const subject = id === "meeting" ? upcoming : null;
            act(id, subject);
            announce(id);
        } else if (what === "suggest") {
            // Not into Do Not Disturb, and not into a screen that is being recorded
            // (the recording's own question comes at its start).
            if (dndOn || (recording && id !== "recording")) return;
            ask(id);
        }
    }

    function question(id: string): string {
        switch (id) {
        case "meeting": return Lang.i18n("“%1” starts soon. Turn on Do Not Disturb until it ends?", upcoming !== null && upcoming.title ? upcoming.title : Lang.i18n("Event"));
        case "recording": return Lang.i18n("The screen is being recorded. Hide notifications while it lasts?");
        case "call": return Lang.i18n("The microphone is in use. Pause the media?");
        case "battery": return Lang.i18n("The battery is low (%1). Switch to the power saving profile?", Lang.percent(backend.batteryPercent));
        case "pomodoro": return Lang.i18n("A focus round has started. Turn on Do Not Disturb until the break?");
        case "headphones": return Lang.i18n("Headphones are connected. Carry on playing?");
        }
        return "";
    }
    function iconOf(id: string): string {
        return id === "call" ? "audio-input-microphone-symbolic" : id === "battery" ? "battery-low-symbolic"
             : id === "headphones" ? "audio-headphones-symbolic" : "notifications-disabled-symbolic";
    }
    function colorOf(id: string): color {
        return id === "battery" ? theme.live : id === "call" || id === "headphones" ? theme.blue : theme.purple;
    }
    // What was done, in words (the automatic mode says it).
    function doneText(id: string): string {
        return id === "call" ? Lang.i18n("Media paused") : id === "battery" ? Lang.i18n("Power saving profile is on")
             : id === "headphones" ? Lang.i18n("Playing again") : Lang.i18n("Do Not Disturb is on");
    }

    function ask(id: string): void {
        // what the question is about, as it is now (an answer comes seconds later)
        const subject = id === "meeting" ? upcoming : null;
        manager.flash({
            key: "suggestion",
            live: true,
            // the screen recording itself outranks events: its question has to come through
            force: id === "recording",
            icon: iconOf(id),
            color: colorOf(id),
            title: question(id),
            width: theme.notificationWidth,
            height: theme.questionHeight,
            duration: answerSeconds * 1000,
            buttons: [
                { text: Lang.i18n("Yes"), primary: true, trigger: () => provider.answered(id, "yes", subject) },
                { text: Lang.i18n("Not now"), trigger: () => provider.answered(id, "later", subject) },
                { text: Lang.i18n("Never suggest this"), trigger: () => provider.answered(id, "never", subject) }
            ],
            shown: () => store.write(Suggestions.shown(store.read(), id, provider.now())),
            expired: () => provider.answered(id, "timeout", subject),
            closed: () => provider.answered(id, "later", subject)
        });
    }
    function answered(id: string, what: string, subject: var): void {
        const result = Suggestions.answer(store.read(), id, what);
        store.write(result.state);
        if (what === "yes") {
            act(id, subject);
            if (result.offer) offer(id);
        }
        // Ignored five times in a row: switched off, said once.
        if (result.notice) {
            manager.flash({
                key: "suggestion-note",
                icon: "notifications-disabled-symbolic",
                color: theme.subText,
                title: Lang.i18n("I will not show this suggestion any more"),
                subtitle: Lang.i18n("You can switch it on again in Settings → Suggestions"),
                duration: 7000
            });
        }
    }
    // Yes three times in a row: from now on without asking?
    function offer(id: string): void {
        manager.flash({
            key: "suggestion",
            icon: "media-playlist-repeat-symbolic",
            color: colorOf(id),
            title: Lang.i18n("Shall I do this automatically from now on?"),
            subtitle: catalog.title(id),
            width: theme.notificationWidth,
            height: theme.questionHeight,
            duration: answerSeconds * 1000,
            buttons: [
                { text: Lang.i18n("Yes"), primary: true, trigger: () => {
                    store.write(Suggestions.automatic(store.read(), id, true));
                    provider.manager.flash({ key: "suggestion-note", icon: "media-playlist-repeat-symbolic", color: provider.colorOf(id),
                                             title: Lang.i18n("Automatic from now on"), subtitle: Lang.i18n("It says so each time, with an Undo"), duration: 4000 });
                } },
                { text: Lang.i18n("No, keep asking"), trigger: () => store.write(Suggestions.automatic(store.read(), id, false)) }
            ],
            expired: () => store.write(Suggestions.automatic(store.read(), id, false)),
            closed: () => store.write(Suggestions.automatic(store.read(), id, false))
        });
    }

    // ---- doing it, and taking it back -----------------------------------------------------
    // Do Not Disturb that a rule switched on for as long as something lasts: whose it is.
    property string held: ""
    property string profileBefore: ""
    // The user switched it off meanwhile: it is theirs again.
    onDndOnChanged: if (!dndOn) held = ""

    function act(id: string, subject: var): void {
        switch (id) {
        case "meeting":
            // until the event ends: Plasma switches it off by itself then
            if (subject && subject.end > now()) dnd.setActiveUntil(new Date(subject.end)); else dnd.setActive(true);
            break;
        case "recording":
        case "pomodoro":
            dnd.setActive(true);
            held = id;
            break;
        case "call":
            if (backend.isPlaying) backend.playPause();
            break;
        case "battery":
            profileBefore = power.profile;
            power.setProfile("power-saver");
            break;
        case "headphones":
            if (backend.isPaused) backend.playPause();
            break;
        }
    }
    function undo(id: string): void {
        switch (id) {
        case "meeting":
        case "recording":
        case "pomodoro":
            held = "";
            dnd.setActive(false);
            break;
        case "call":
            if (backend.isPaused) backend.playPause();
            break;
        case "battery":
            power.setProfile(profileBefore.length > 0 ? profileBefore : "balanced");
            break;
        case "headphones":
            if (backend.isPlaying) backend.playPause();
            break;
        }
    }
    // What a rule held for as long as something lasted is over.
    function release(id: string): void {
        if (held !== id) return;
        held = "";
        if (dnd !== null && dnd.active) dnd.setActive(false);
    }

    // Done by itself: said, with an Undo. Under the key of the change's own
    // event (Do Not Disturb, the power profile), a moment after it, so that
    // the island shows one event for it: this one.
    function announce(id: string): void {
        const key = id === "battery" ? "power-profile" : id === "call" || id === "headphones" ? "suggestion-done" : "dnd";
        said.pending = {
            key: key,
            icon: iconOf(id),
            color: colorOf(id),
            title: doneText(id),
            subtitle: Lang.i18n("Done automatically"),
            trailing: { type: "button", text: Lang.i18n("Undo") },
            activate: () => provider.undoAutomatic(id),
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
    // "Undo": taken back, and the rule asks again from now on.
    function undoAutomatic(id: string): void {
        undo(id);
        store.write(Suggestions.undone(store.read(), id));
        manager.flash({ key: "suggestion-note", icon: "edit-undo-symbolic", color: theme.subText, title: Lang.i18n("Undone"),
                        subtitle: Lang.i18n("I will ask again next time"), duration: 3500 });
    }
}
