/*
    SPDX-License-Identifier: GPL-2.0-or-later
    One simple alarm ("HH:MM", next occurrence). Checked with a timer that
    re-arms at most every 30 s, so it stays correct across suspend/resume.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    required property var cfg
    property var sound: null
    property bool enabled: true

    readonly property real alarmAt: Number(cfg.alarmAt) || 0
    readonly property bool armed: alarmAt > 0
    readonly property string alarmTime: cfg.alarmTime

    function nextOccurrence(hhmm: string): real {
        const parts = hhmm.split(":");
        const d = new Date();
        d.setHours(Number(parts[0]) || 0, Number(parts[1]) || 0, 0, 0);
        if (d.getTime() <= Date.now()) d.setDate(d.getDate() + 1);
        return d.getTime();
    }
    function set(hhmm: string): void {
        cfg.alarmTime = hhmm;
        cfg.alarmAt = String(nextOccurrence(hhmm));
        check();
    }
    function clear(): void { cfg.alarmAt = "0"; }

    function check(): void {
        if (!armed) return;
        const left = alarmAt - Date.now();
        if (left <= 0) {
            clear();
            // Missed by more than 10 minutes (machine was off): don't ring late.
            if (left > -10 * 60000) ring();
            return;
        }
        timer.interval = Math.max(200, Math.min(left, 30000));
        timer.restart();
    }
    function ring(): void {
        manager.flash({
            key: "alarm",
            shake: true,
            icon: "alarm-symbolic",
            color: theme.orange,
            title: Lang.i18n("Alarm"),
            subtitle: cfg.alarmLabel || "",
            trailing: { type: "text", text: alarmTime, color: theme.orange },
            duration: 12000
        });
        if (sound) sound.play(cfg.timerSoundEnabled ? cfg.timerSound : "");
    }

    onAlarmAtChanged: check()
    Component.onCompleted: check()
    Timer {
        id: timer
        running: provider.enabled && provider.armed
        onTriggered: provider.check()
    }
}
