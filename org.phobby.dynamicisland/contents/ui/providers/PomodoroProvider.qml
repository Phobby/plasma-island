/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Pomodoro: work / short break cycles, long break after N rounds. Phase
    changes are transient events.
*/
import QtQuick
import ".."
import "../TimeFormat.js" as TimeFormat

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    required property var cfg
    property var sound: null
    property bool enabled: true

    property real now: Date.now()
    readonly property string phase: cfg.pomodoroPhase          // "" | work | break | long
    readonly property real endsAt: Number(cfg.pomodoroEndsAt) || 0
    readonly property bool running: phase.length > 0
    readonly property int round: cfg.pomodoroRound             // completed work sessions in this set
    readonly property int rounds: Math.max(1, cfg.pomodoroRounds)
    readonly property real remaining: running ? Math.max(0, (endsAt - now) / 1000) : cfg.pomodoroWork * 60

    function phaseName(p: string): string {
        return p === "work" ? i18n("Focus") : p === "long" ? i18n("Long break") : i18n("Break");
    }
    function enter(p: string): void {
        const minutes = p === "work" ? cfg.pomodoroWork : p === "long" ? cfg.pomodoroLongBreak : cfg.pomodoroShortBreak;
        cfg.pomodoroPhase = p;
        cfg.pomodoroEndsAt = String(Date.now() + minutes * 60000);
        now = Date.now();
    }
    function start(): void {
        cfg.pomodoroRound = 0;
        enter("work");
    }
    function stop(): void {
        cfg.pomodoroPhase = "";
        cfg.pomodoroEndsAt = "0";
    }
    function skip(): void { advance(false); }

    function advance(announce: bool): void {
        let next;
        if (phase === "work") {
            const done = round + 1;
            cfg.pomodoroRound = done;
            next = done >= rounds ? "long" : "break";
        } else {
            if (phase === "long") cfg.pomodoroRound = 0;
            next = "work";
        }
        enter(next);
        if (announce) {
            manager.flash({
                key: "pomodoro",
                shake: true,
                icon: next === "work" ? "view-task" : "kteatime",
                color: next === "work" ? theme.red : theme.live,
                title: next === "work" ? i18n("Time to focus") : i18n("Time for a break"),
                subtitle: i18n("Round %1 of %2", Math.min(rounds, next === "work" ? round + 1 : round), rounds),
                trailing: { type: "text", text: TimeFormat.clock(remaining), color: theme.text }
            });
            if (sound) sound.play(cfg.timerSoundEnabled ? cfg.timerSound : "");
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: provider.running
        triggeredOnStart: true
        onTriggered: {
            provider.now = Date.now();
            if (provider.endsAt <= provider.now) provider.advance(true);
        }
    }

    Activity {
        activityId: "pomodoro"
        category: "timer"
        priority: 1
        active: provider.enabled && provider.running
        icon: provider.phase === "work" ? "view-task" : "kteatime"
        color: provider.phase === "work" ? provider.theme.red : provider.theme.live
        title: provider.phaseName(provider.phase)
        subtitle: i18n("Round %1 of %2", Math.min(provider.rounds, provider.round + (provider.phase === "work" ? 1 : 0)), provider.rounds)
        trailingText: TimeFormat.clock(provider.remaining)
        actions: [
            { icon: "media-skip-forward-symbolic", text: i18n("Skip"), trigger: () => provider.skip() },
            { icon: "media-playback-stop-symbolic", text: i18n("Stop"), trigger: () => provider.stop() }
        ]
        Component.onCompleted: provider.manager.register(this)
    }
}
