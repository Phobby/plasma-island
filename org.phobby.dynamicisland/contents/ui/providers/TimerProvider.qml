/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Countdown timer. The end time is stored in the applet configuration, so a
    running timer survives a plasmashell restart.
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
    readonly property real endsAt: Number(cfg.timerEndsAt) || 0
    readonly property int pausedRemaining: cfg.timerPausedRemaining
    readonly property bool running: endsAt > 0
    readonly property bool paused: !running && pausedRemaining > 0
    readonly property real remaining: running ? Math.max(0, (endsAt - now) / 1000) : pausedRemaining
    readonly property int total: Math.max(1, cfg.timerTotal)

    function start(seconds: int): void {
        cfg.timerTotal = seconds;
        cfg.timerPausedRemaining = 0;
        cfg.timerEndsAt = String(Date.now() + seconds * 1000);
        now = Date.now();
    }
    function pause(): void {
        if (!running) return;
        cfg.timerPausedRemaining = Math.max(1, Math.ceil(remaining));
        cfg.timerEndsAt = "0";
    }
    function resume(): void {
        if (!paused) return;
        cfg.timerEndsAt = String(Date.now() + pausedRemaining * 1000);
        cfg.timerPausedRemaining = 0;
        now = Date.now();
    }
    function cancel(): void {
        cfg.timerEndsAt = "0";
        cfg.timerPausedRemaining = 0;
    }

    function finish(): void {
        cancel();
        manager.flash({
            key: "timer-done",
            shake: true,
            icon: "chronometer",
            color: theme.orange,
            title: i18n("Timer done"),
            trailing: { type: "text", text: TimeFormat.clock(total), color: theme.orange },
            duration: 8000
        });
        if (sound) sound.play(cfg.timerSoundEnabled ? cfg.timerSound : "");
    }

    Timer {
        interval: 1000
        repeat: true
        running: provider.running
        triggeredOnStart: true
        onTriggered: {
            provider.now = Date.now();
            if (provider.endsAt <= provider.now) provider.finish();
        }
    }

    Activity {
        activityId: "timer"
        category: "timer"
        active: provider.enabled && (provider.running || provider.paused)
        icon: "chronometer"
        color: provider.theme.orange
        title: provider.paused ? i18n("Timer paused") : i18n("Timer")
        trailingText: TimeFormat.clock(provider.remaining)
        progress: -1
        actions: [
            { icon: provider.paused ? "media-playback-start-symbolic" : "media-playback-pause-symbolic",
              text: provider.paused ? i18n("Resume") : i18n("Pause"),
              trigger: () => provider.paused ? provider.resume() : provider.pause() },
            { icon: "dialog-cancel-symbolic", text: i18n("Cancel"), trigger: () => provider.cancel() }
        ]
        Component.onCompleted: provider.manager.register(this)
    }
}
