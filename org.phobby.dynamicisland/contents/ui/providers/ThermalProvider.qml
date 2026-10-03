/*
    SPDX-License-Identifier: GPL-2.0-or-later
    High CPU / GPU temperature warning (thresholds configurable). Sensors are
    read every 10 s while this is enabled.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property PlasmaBackend backend
    required property Theme theme
    property bool enabled: true
    property int cpuThreshold: 90
    property int gpuThreshold: 85

    Binding { target: provider.backend; property: "thermalWatch"; value: provider.enabled }

    property bool cpuWarned: false
    property bool gpuWarned: false

    function warn(name: string, temp: real): void {
        manager.flash({
            key: "thermal-" + name,
            icon: "temperature-warm",
            pulse: true,
            color: theme.red,
            title: Lang.i18n("%1 is running hot", name),
            subtitle: Lang.i18n("Check cooling and heavy applications"),
            trailing: { type: "text", text: Math.round(temp) + "°", color: theme.red },
            duration: 6000
        });
    }

    Connections {
        target: provider.backend
        enabled: provider.enabled
        function onCpuTempChanged() {
            const t = provider.backend.cpuTemp;
            if (t >= provider.cpuThreshold && !provider.cpuWarned) {
                provider.cpuWarned = true;
                provider.warn(Lang.i18nc("@label processor", "CPU"), t);
            } else if (t > 0 && t < provider.cpuThreshold - 5) {
                provider.cpuWarned = false;
            }
        }
        function onGpuTempChanged() {
            const t = provider.backend.gpuTemp;
            if (t >= provider.gpuThreshold && !provider.gpuWarned) {
                provider.gpuWarned = true;
                provider.warn(Lang.i18nc("@label graphics card", "GPU"), t);
            } else if (t > 0 && t < provider.gpuThreshold - 5) {
                provider.gpuWarned = false;
            }
        }
    }
}
