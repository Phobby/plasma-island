/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Row of ring gauges: CPU · CPU temperature · GPU · RAM · network (· battery).
    Sensor polling is gated by PlasmaBackend.systemActive, which the island
    sets only while this page is shown.
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: sys

    required property Theme theme
    required property PlasmaBackend backend

    implicitHeight: row.implicitHeight

    // Network ring: usage relative to a slowly decaying recent peak, so the
    // arc reads as "how busy is the link right now" at any bandwidth.
    readonly property real netTotal: backend.netDownRate + backend.netUpRate
    property real netPeak: 256 * 1024
    onNetTotalChanged: netPeak = Math.max(256 * 1024, netTotal, netPeak * 0.9)

    function levelColor(v: real): color {
        return v > 0.9 ? theme.danger : v > 0.75 ? theme.warning : theme.text;
    }
    function tempColor(c: real): color {
        return c >= 85 ? theme.danger : c >= 72 ? theme.warning : theme.text;
    }

    component Gauge: RingGauge {
        Layout.fillWidth: true
        Layout.maximumWidth: 60
        Layout.preferredWidth: 54
        lineWidth: 4
        trackColor: sys.theme.track
        textColor: sys.theme.text
        captionColor: sys.theme.subText
        fontSize: sys.theme.fontSmall
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 6

        Gauge {
            value: sys.backend.cpuUsage / 100
            label: Math.round(sys.backend.cpuUsage) + "%"
            caption: i18nc("@label short for processor", "CPU")
            color: sys.levelColor(value)
        }
        Gauge {
            visible: sys.backend.cpuTemp > 0
            value: sys.backend.cpuTemp / 100
            label: Math.round(sys.backend.cpuTemp) + "°"
            caption: i18nc("@label processor temperature, short", "CPU °C")
            color: sys.tempColor(sys.backend.cpuTemp)
        }
        Gauge {
            visible: sys.backend.hasGpu
            value: sys.backend.gpuUsage / 100
            label: Math.round(sys.backend.gpuUsage) + "%"
            caption: sys.backend.gpuTemp > 0
                     ? i18nc("@label GPU with temperature, short", "GPU %1°", Math.round(sys.backend.gpuTemp))
                     : i18nc("@label short for graphics card", "GPU")
            color: sys.backend.gpuTemp >= 85 ? sys.theme.danger : sys.levelColor(value)
        }
        Gauge {
            value: sys.backend.memUsage / 100
            label: Math.round(sys.backend.memUsage) + "%"
            caption: i18nc("@label short for memory", "RAM")
            color: sys.levelColor(value)
        }
        Gauge {
            value: sys.netTotal / sys.netPeak
            label: "↓" + sys.backend.compactRate(sys.backend.netDownRate)
            secondaryLabel: "↑" + sys.backend.compactRate(sys.backend.netUpRate)
            caption: i18nc("@label network", "Network")
            color: sys.theme.network
        }
        Gauge {
            visible: sys.backend.hasBattery
            value: sys.backend.batteryPercent / 100
            label: sys.backend.batteryPercent + "%"
            caption: sys.backend.batteryCharging ? i18n("Charging") : i18n("Battery")
            color: sys.backend.batteryCharging ? sys.theme.live
                 : sys.backend.batteryPercent <= 10 ? sys.theme.danger
                 : sys.backend.batteryPercent <= 20 ? sys.theme.warning : sys.theme.text
        }
    }
}
