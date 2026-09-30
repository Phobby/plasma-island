/*
    SPDX-License-Identifier: GPL-2.0-or-later

    PlasmaBackend: the ONLY file that talks to private / unstable Plasma APIs.
    Every UI module consumes the normalized properties and functions below.
    If a Plasma update changes one of these modules, fix it here.

    More private modules (Bluetooth, power profiles, brightness, keyboard,
    network, DND, …) live in backend/*.qml — likewise the only files allowed
    to import them.

    Verified against Plasma 6.6 (plasma-workspace, plasma-pa, plasma-nm, libksysguard):
      org.kde.plasma.private.mpris      Mpris2Model / PlayerContainer
      org.kde.notificationmanager       Notifications
      org.kde.plasma.private.volume     PreferredDevice / PulseAudio
      org.kde.plasma.private.battery    BatteryControlModel
      org.kde.ksysguard.sensors         Sensor
*/
import QtQuick

import org.kde.plasma.private.mpris as Mpris
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.private.battery as Battery
import org.kde.ksysguard.sensors as Sensors

Item {
    id: backend

    // ---- inputs -------------------------------------------------------------
    // Sensors only poll while this is true (i.e. the system module is on screen).
    property bool systemActive: false
    // Player position is only refreshed while the media module is on screen.
    property bool positionActive: false
    // Case-insensitive substring matched against player identity / desktop entry.
    property string preferredPlayer: ""

    // ---- media --------------------------------------------------------------
    readonly property var player: mpris.currentPlayer
    readonly property string track: player?.track ?? ""
    readonly property string artist: player?.artist ?? ""
    readonly property string album: player?.album ?? ""
    readonly property string artUrl: player?.artUrl ?? ""
    readonly property string playerName: player?.identity ?? ""
    readonly property string playerIcon: player?.iconName ?? ""
    readonly property int playbackStatus: player?.playbackStatus ?? 0
    readonly property bool isPlaying: playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool isPaused: playbackStatus === Mpris.PlaybackStatus.Paused
    readonly property bool hasMedia: track.length > 0 && playbackStatus > Mpris.PlaybackStatus.Stopped
    readonly property bool canControl: player?.canControl ?? false
    readonly property bool canGoNext: player?.canGoNext ?? false
    readonly property bool canGoPrevious: player?.canGoPrevious ?? false
    readonly property bool canSeek: player?.canSeek ?? false
    readonly property bool canRaise: player?.canRaise ?? false
    // microseconds
    readonly property real length: player?.length ?? 0
    readonly property real position: player?.position ?? 0
    // 0..1
    readonly property real playerVolume: player?.volume ?? 0

    function playPause(): void { player?.PlayPause(); }
    function next(): void { player?.Next(); }
    function previous(): void { player?.Previous(); }
    function raisePlayer(): void { player?.Raise(); }
    function seek(us: real): void { if (player) player.position = us; }
    function setPlayerVolume(v: real): void { if (player) player.volume = Math.max(0, Math.min(1, v)); }
    function refreshPosition(): void { player?.updatePosition(); }

    Mpris.Mpris2Model {
        id: mpris
    }

    // Player priority: prefer the configured player when it plays (or when
    // nothing else plays); otherwise let the multiplexer pick the active one.
    Instantiator {
        id: players
        model: mpris
        delegate: QtObject {
            required property int index
            required property var model
            readonly property var container: model.container ?? null
            readonly property int status: container?.playbackStatus ?? 0
            readonly property string key: ((model.identity ?? "") + " " + (model.desktopEntry ?? "")).toLowerCase()
            readonly property bool multiplexer: model.isMultiplexer ?? false
            onStatusChanged: Qt.callLater(backend.choosePlayer)
        }
        onObjectAdded: Qt.callLater(backend.choosePlayer)
        onObjectRemoved: Qt.callLater(backend.choosePlayer)
    }
    onPreferredPlayerChanged: Qt.callLater(choosePlayer)

    function choosePlayer(): void {
        const pref = preferredPlayer.trim().toLowerCase();
        let multiplexerIdx = -1, prefIdx = -1, prefPlaying = false, otherPlaying = false;
        for (let i = 0; i < players.count; ++i) {
            const p = players.objectAt(i);
            if (!p) continue;
            if (p.multiplexer) { multiplexerIdx = i; continue; }
            const playing = p.status === Mpris.PlaybackStatus.Playing;
            if (pref.length > 0 && prefIdx < 0 && p.key.indexOf(pref) >= 0) {
                prefIdx = i;
                prefPlaying = playing;
            } else if (playing) {
                otherPlaying = true;
            }
        }
        let target = multiplexerIdx;
        if (prefIdx >= 0 && (prefPlaying || !otherPlaying)) target = prefIdx;
        if (target >= 0 && mpris.currentIndex !== target) mpris.currentIndex = target;
    }

    Timer {
        interval: 1000
        repeat: true
        running: backend.positionActive && backend.isPlaying
        triggeredOnStart: true
        onTriggered: backend.refreshPosition()
    }

    // ---- output volume ------------------------------------------------------
    readonly property var sink: Vol.PreferredDevice.sink
    readonly property bool hasSink: sink !== null && sink !== undefined
    readonly property real volume: hasSink ? sink.volume / Vol.PulseAudio.NormalVolume : 0 // 0..1(+)
    readonly property bool muted: hasSink ? sink.muted : false
    readonly property string volumeIcon: hasSink ? Vol.AudioIcon.forVolume(Math.round(volume * 100), muted, "") : "audio-volume-muted"

    function setVolume(v: real): void {
        if (!hasSink) return;
        sink.volume = Math.round(Math.max(0, Math.min(1, v)) * Vol.PulseAudio.NormalVolume);
        if (sink.muted && v > 0) sink.muted = false;
    }
    function toggleMute(): void { if (hasSink) sink.muted = !sink.muted; }

    // ---- battery / network / sensors ---------------------------------------
    readonly property bool hasBattery: batteryControl.hasInternalBatteries
    readonly property int batteryPercent: batteryControl.percent
    readonly property bool batteryCharging: batteryControl.pluggedIn
                                            && batteryControl.state === Battery.BatteryControlModel.Charging
    readonly property bool batteryPluggedIn: batteryControl.pluggedIn
    readonly property bool batteryFull: batteryControl.pluggedIn
                                        && batteryControl.state === Battery.BatteryControlModel.FullyCharged
    readonly property bool batteryDischarging: batteryControl.state === Battery.BatteryControlModel.Discharging
    // Default output device name (e.g. "Speakers" → "Headphones").
    readonly property string sinkName: hasSink ? (sink.description || sink.name || "") : ""

    Battery.BatteryControlModel {
        id: batteryControl
    }

    readonly property real cpuUsage: Number(cpuSensor.value) || 0        // percent
    readonly property real cpuTemp: Number(cpuTempSensor.value) || 0     // °C, 0 = unavailable
    readonly property real memUsage: Number(memSensor.value) || 0        // percent
    readonly property bool hasGpu: gpuSensor.value !== undefined && gpuSensor.value !== null
    readonly property real gpuUsage: Number(gpuSensor.value) || 0        // percent
    // GPU indices differ per machine (e.g. only gpu1 on hybrid setups):
    // take the first one that reports a temperature.
    readonly property real gpuTemp: {
        for (const t of [gpu0Temp, gpu1Temp, gpu2Temp]) {
            const v = Number(t.value);
            if (v > 0) return v;
        }
        return 0;
    }
    readonly property real netDownRate: Number(downSensor.value) || 0    // bytes/s
    readonly property real netUpRate: Number(upSensor.value) || 0        // bytes/s

    component SystemSensor: Sensors.Sensor {
        enabled: backend.systemActive
        updateRateLimit: 1500
    }
    SystemSensor { id: cpuSensor; sensorId: "cpu/all/usage" }
    SystemSensor { id: cpuTempSensor; sensorId: "cpu/all/maximumTemperature" }
    SystemSensor { id: memSensor; sensorId: "memory/physical/usedPercent"; updateRateLimit: 2000 }
    SystemSensor { id: gpuSensor; sensorId: "gpu/all/usage" }
    SystemSensor { id: gpu0Temp; sensorId: "gpu/gpu0/temperature"; updateRateLimit: 3000 }
    SystemSensor { id: gpu1Temp; sensorId: "gpu/gpu1/temperature"; updateRateLimit: 3000 }
    SystemSensor { id: gpu2Temp; sensorId: "gpu/gpu2/temperature"; updateRateLimit: 3000 }
    SystemSensor { id: downSensor; sensorId: "network/all/download" }
    SystemSensor { id: upSensor; sensorId: "network/all/upload" }

    // "1.2M" / "340K" / "12" — compact byte rate for tight ring labels.
    function compactRate(bytes: real): string {
        if (bytes >= 1024 * 1024 * 1024) return (bytes / 1073741824).toFixed(1) + "G";
        if (bytes >= 1024 * 1024) return (bytes / 1048576).toFixed(bytes >= 10485760 ? 0 : 1) + "M";
        if (bytes >= 1024) return Math.round(bytes / 1024) + "K";
        return Math.round(bytes) + "B";
    }

    // ---- notifications ------------------------------------------------------
    // Emitted for notifications that arrive while the widget is running.
    signal notificationArrived(var notification)

    readonly property alias notificationModel: notifications
    readonly property int summaryRole: NotificationManager.Notifications.SummaryRole
    readonly property int bodyRole: NotificationManager.Notifications.BodyRole

    readonly property date startTime: new Date()
    property var seenIds: ({})

    NotificationManager.Notifications {
        id: notifications
        showExpired: true
        showDismissed: true
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        urgencies: NotificationManager.Notifications.NormalUrgency | NotificationManager.Notifications.CriticalUrgency

        onRowsInserted: (parent, first, last) => {
            for (let row = first; row <= last; ++row) {
                const n = backend.notificationAt(row);
                if (!n || backend.seenIds[n.id] || n.created < backend.startTime) continue;
                backend.seenIds[n.id] = true;
                backend.notificationArrived(n);
            }
        }
    }

    function notificationAt(row: int): var {
        const idx = notifications.index(row, 0);
        const R = NotificationManager.Notifications;
        const id = notifications.data(idx, R.IdRole);
        if (id === undefined) return null;
        return {
            id: id,
            summary: notifications.data(idx, R.SummaryRole) || "",
            body: plainText(notifications.data(idx, R.BodyRole) || ""),
            appName: notifications.data(idx, R.ApplicationNameRole) || "",
            icon: notifications.data(idx, R.ImageRole)
                  || notifications.data(idx, R.IconNameRole)
                  || notifications.data(idx, R.ApplicationIconNameRole)
                  || "preferences-desktop-notification-bell",
            created: notifications.data(idx, R.CreatedRole) || new Date()
        };
    }

    function rowForId(id: var): int {
        for (let i = 0; i < notifications.count; ++i) {
            if (notifications.data(notifications.index(i, 0), NotificationManager.Notifications.IdRole) == id) return i;
        }
        return -1;
    }

    // Runs the default action (or just dismisses when there is none).
    function activateNotification(id: var): void {
        const row = rowForId(id);
        if (row < 0) return;
        const idx = notifications.index(row, 0);
        if (notifications.data(idx, NotificationManager.Notifications.HasDefaultActionRole)) {
            notifications.invokeDefaultAction(idx, NotificationManager.Notifications.Close);
        } else {
            notifications.expire(idx);
        }
    }

    function closeNotification(id: var): void {
        const row = rowForId(id);
        if (row >= 0) notifications.close(notifications.index(row, 0));
    }

    function plainText(s: string): string {
        return s.replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").split("\n")[0];
    }
}
