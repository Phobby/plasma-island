/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Warning thresholds.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_lowBatteryThreshold: lowSpin.value
    property alias cfg_criticalBatteryThreshold: criticalSpin.value
    property alias cfg_deviceBatteryThreshold: deviceSpin.value
    property alias cfg_cpuTempThreshold: cpuSpin.value
    property alias cfg_gpuTempThreshold: gpuSpin.value
    property alias cfg_calendarLeadMinutes: calendarSpin.value

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Battery")
        }
        QQC2.SpinBox {
            id: lowSpin
            Kirigami.FormData.label: i18n("Low battery warning at:")
            from: 5; to: 50
            textFromValue: (v) => v + "%"
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: criticalSpin
            Kirigami.FormData.label: i18n("Critical warning at:")
            from: 1; to: 30
            textFromValue: (v) => v + "%"
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: deviceSpin
            Kirigami.FormData.label: i18n("Bluetooth device / phone low at:")
            from: 5; to: 50
            textFromValue: (v) => v + "%"
            valueFromText: (t) => parseInt(t)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Temperature")
        }
        QQC2.SpinBox {
            id: cpuSpin
            Kirigami.FormData.label: i18n("Warn when the CPU reaches:")
            from: 60; to: 110
            textFromValue: (v) => v + " °C"
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: gpuSpin
            Kirigami.FormData.label: i18n("Warn when the GPU reaches:")
            from: 60; to: 110
            textFromValue: (v) => v + " °C"
            valueFromText: (t) => parseInt(t)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Calendar")
        }
        QQC2.SpinBox {
            id: calendarSpin
            Kirigami.FormData.label: i18n("Count down to the next event:")
            from: 1; to: 120
            textFromValue: (v) => i18n("%1 min before", v)
            valueFromText: (t) => parseInt(t)
        }
    }
}
