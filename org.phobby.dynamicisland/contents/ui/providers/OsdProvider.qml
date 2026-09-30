/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Volume / brightness feedback and output device switches, shown in the
    island (a thin slider). Plasma's own OSD keeps working; see README for
    turning it off.
*/
import QtQuick
import ".."
import "../backend"

Item {
    id: provider

    required property ActivityManager manager
    required property PlasmaBackend backend
    required property DisplayBackend display
    required property Theme theme
    property bool enabled: true

    Connections {
        target: provider.backend
        enabled: provider.enabled
        function onVolumeChanged() { provider.volumeEvent(); }
        function onMutedChanged() { provider.volumeEvent(); }
        function onSinkNameChanged() {
            if (!provider.backend.sinkName) return;
            provider.manager.flash({
                key: "sink",
                icon: provider.backend.volumeIcon,
                color: provider.theme.blue,
                title: provider.backend.sinkName,
                subtitle: i18n("Audio output")
            });
        }
    }
    function volumeEvent(): void {
        const b = backend;
        manager.flash({
            key: "volume",
            live: true,
            icon: b.volumeIcon,
            color: b.muted ? theme.subText : theme.text,
            title: b.muted ? i18n("Muted") : i18n("Volume"),
            trailing: { type: "slider", value: b.muted ? 0 : b.volume, color: b.muted ? theme.subText : theme.text },
            duration: 1500
        });
    }

    Connections {
        target: provider.display
        enabled: provider.enabled
        function onBrightnessAdjusted(name, value) {
            provider.manager.flash({
                key: "brightness",
                live: true,
                icon: "video-display-brightness-symbolic",
                color: provider.theme.text,
                title: i18n("Brightness"),
                trailing: { type: "slider", value: value, color: provider.theme.text },
                duration: 1500
            });
        }
    }
}
