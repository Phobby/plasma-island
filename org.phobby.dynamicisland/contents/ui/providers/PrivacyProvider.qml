/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Privacy indicators: orange dot while an app records the microphone, green
    dot while a camera is in use. Shown right of the island at all times and
    listed (with the apps) on the Activities page.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property PlasmaBackend backend
    required property Theme theme
    property var core: null
    property bool enabled: true

    readonly property var micApps: core ? core.microphoneApps : []
    readonly property var cameraApps: core ? core.cameraApps : []

    Activity {
        activityId: "privacy-microphone"
        category: "privacy"
        indicatorOnly: true
        active: provider.enabled && provider.micApps.length > 0
        icon: "audio-input-microphone-symbolic"
        color: provider.theme.orange
        title: provider.backend.micMuted ? i18n("Microphone (muted)") : i18n("Microphone in use")
        subtitle: provider.micApps.join(", ")
        actions: [
            { icon: provider.backend.micMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic",
              text: provider.backend.micMuted ? i18n("Unmute microphone") : i18n("Mute microphone"),
              trigger: () => provider.backend.toggleMicMute() }
        ]
        Component.onCompleted: provider.manager.register(this)
    }

    Activity {
        activityId: "privacy-camera"
        category: "privacy"
        indicatorOnly: true
        active: provider.enabled && provider.cameraApps.length > 0
        icon: "camera-web-symbolic"
        color: provider.theme.live
        title: i18n("Camera in use")
        subtitle: provider.cameraApps.join(", ")
        Component.onCompleted: provider.manager.register(this)
    }
}
