/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Stopwatch with laps (state persisted in the configuration).
*/
import QtQuick
import ".."
import "../TimeFormat.js" as TimeFormat

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    required property var cfg
    property bool enabled: true
    // Set by the Tools page while it shows the stopwatch (10 Hz refresh).
    property bool precise: false

    property real now: Date.now()
    readonly property real startedAt: Number(cfg.stopwatchStartedAt) || 0
    readonly property real accumulated: Number(cfg.stopwatchElapsed) || 0
    readonly property bool running: startedAt > 0
    readonly property real elapsed: accumulated + (running ? now - startedAt : 0)
    readonly property var laps: {
        try { return JSON.parse(cfg.stopwatchLaps || "[]"); } catch (e) { return []; }
    }

    function start(): void {
        if (running) return;
        cfg.stopwatchStartedAt = String(Date.now());
        now = Date.now();
    }
    function stop(): void {
        if (!running) return;
        cfg.stopwatchElapsed = String(accumulated + Date.now() - startedAt);
        cfg.stopwatchStartedAt = "0";
        now = Date.now();
    }
    function lap(): void {
        const l = laps.slice();
        l.unshift(elapsed);
        cfg.stopwatchLaps = JSON.stringify(l.slice(0, 20));
    }
    function reset(): void {
        cfg.stopwatchStartedAt = "0";
        cfg.stopwatchElapsed = "0";
        cfg.stopwatchLaps = "[]";
    }

    Timer {
        interval: provider.precise ? 50 : 1000
        repeat: true
        running: provider.running
        onTriggered: provider.now = Date.now()
    }

    Activity {
        activityId: "stopwatch"
        category: "timer"
        priority: -1
        active: provider.enabled && provider.running
        icon: "chronometer"
        color: provider.theme.text
        title: Lang.i18n("Stopwatch")
        trailingText: TimeFormat.clock(provider.elapsed / 1000)
        actions: [
            { icon: "flag", text: Lang.i18n("Lap"), trigger: () => provider.lap() },
            { icon: "media-playback-stop-symbolic", text: Lang.i18n("Stop"), trigger: () => provider.stop() }
        ]
        Component.onCompleted: provider.manager.register(this)
    }
}
