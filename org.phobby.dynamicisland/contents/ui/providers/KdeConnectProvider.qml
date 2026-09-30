/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Phone integration through KDE Connect:
      * incoming call → island expands (caller, "Mute ringtone"), stays as a
        Live Activity with the call duration while talking;
      * missed call → transient event; low phone battery → warning.
    KDE Connect has no "call ended" signal: the call ends when KDE Connect
    closes its call notification (or after a safety timeout).
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property PlasmaBackend backend
    required property Theme theme
    property var kdeconnect: null
    property var core: null
    property bool enabled: true
    property int lowBattery: 15

    property string callState: ""          // "" | ringing | talking
    property string caller: ""
    property string devicePath: ""
    property real callStartedAt: 0
    property var callNotificationId: null
    property real now: Date.now()

    function endCall(): void {
        callState = "";
        callNotificationId = null;
    }
    function muteRingtone(): void {
        if (core && devicePath) {
            core.call(false, "org.kde.kdeconnect", devicePath, "org.kde.kdeconnect.device.telephony", "sendMutePacket", [], null);
        }
    }

    Connections {
        target: provider.core
        enabled: provider.enabled
        ignoreUnknownSignals: true
        function onCallEvent(event, number, contactName, path) {
            const who = contactName || number || i18n("Unknown caller");
            provider.devicePath = path;
            if (event === "ringing") {
                provider.caller = who;
                provider.callState = "ringing";
                // iOS: the island grows for an incoming call.
                provider.manager.flash({
                    key: "call",
                    force: true,
                    shake: true,
                    icon: "call-incoming-symbolic",
                    pulse: true,
                    color: provider.theme.live,
                    title: who,
                    subtitle: number && contactName ? number : i18n("Incoming call"),
                    trailing: { type: "button", text: i18n("Mute") },
                    activate: () => provider.muteRingtone(),
                    width: provider.theme.notificationWidth,
                    duration: 10000
                });
                provider.callStartedAt = Date.now();
                safetyTimer.interval = 90 * 1000;
                safetyTimer.restart();
            } else if (event === "talking") {
                provider.caller = who;
                provider.callState = "talking";
                provider.callStartedAt = Date.now();
                safetyTimer.interval = 4 * 3600 * 1000;
                safetyTimer.restart();
            } else if (event === "missedCall") {
                provider.endCall();
                provider.manager.flash({
                    key: "call",
                    icon: "call-incoming-symbolic",
                    color: provider.theme.red,
                    title: who,
                    subtitle: i18n("Missed call"),
                    duration: 5000
                });
            }
        }
    }

    // Remember KDE Connect's call notification so we notice when it closes.
    Connections {
        target: provider.backend
        enabled: provider.callState !== ""
        function onNotificationArrived(n) {
            if (n.notifyRcName === "kdeconnect" && provider.callNotificationId === null
                && (n.summary.indexOf(provider.caller) >= 0 || n.body.indexOf(provider.caller) >= 0)) {
                provider.callNotificationId = n.id;
            }
        }
    }
    Timer {
        interval: 2000
        repeat: true
        running: provider.callState !== ""
        onTriggered: {
            provider.now = Date.now();
            if (provider.callNotificationId !== null && provider.backend.rowForId(provider.callNotificationId) < 0) provider.endCall();
        }
    }
    Timer {
        id: safetyTimer
        onTriggered: provider.endCall()
    }

    function format(s: int): string {
        const m = Math.floor(s / 60), ss = s % 60;
        return m + ":" + (ss < 10 ? "0" : "") + ss;
    }

    Activity {
        activityId: "call"
        category: "call"
        active: provider.enabled && provider.callState !== ""
        icon: provider.callState === "ringing" ? "call-incoming-symbolic" : "call-start"
        pulse: provider.callState === "ringing"
        color: provider.theme.live
        title: provider.caller
        subtitle: provider.callState === "ringing" ? i18n("Incoming call") : i18n("On a call")
        trailingText: provider.callState === "talking" ? provider.format(Math.round((provider.now - provider.callStartedAt) / 1000)) : ""
        compactWidth: provider.theme.eventWidth
        actions: provider.callState === "ringing" ? [
            { icon: "audio-volume-muted-symbolic", text: i18n("Mute ringtone"), trigger: () => provider.muteRingtone() }
        ] : []
        Component.onCompleted: provider.manager.register(this)
    }

    // Low phone battery (once until it recovers).
    property var warned: ({})
    Connections {
        target: provider.kdeconnect
        enabled: provider.enabled
        ignoreUnknownSignals: true
        function onPhonesChanged() {
            for (const p of provider.kdeconnect.phones) {
                if (p.charge >= 0 && p.charge < provider.lowBattery && !p.charging && !provider.warned[p.id]) {
                    provider.warned[p.id] = true;
                    provider.manager.flash({
                        key: "phone-low-" + p.id,
                        icon: p.icon,
                        color: provider.theme.red,
                        title: p.name,
                        subtitle: i18n("Phone battery low"),
                        trailing: { type: "ring", value: p.charge / 100, color: provider.theme.red, text: String(p.charge) },
                        duration: 5000
                    });
                } else if (p.charge >= provider.lowBattery + 5 || p.charging) {
                    provider.warned[p.id] = false;
                }
            }
        }
    }
}
