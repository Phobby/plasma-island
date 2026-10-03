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

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: cfg_language; restoreMode: Binding.RestoreNone }
    property alias cfg_lowBatteryThreshold: lowSpin.value
    property alias cfg_criticalBatteryThreshold: criticalSpin.value
    property alias cfg_deviceBatteryThreshold: deviceSpin.value
    property alias cfg_cpuTempThreshold: cpuSpin.value
    property alias cfg_gpuTempThreshold: gpuSpin.value

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Battery")
        }
        QQC2.SpinBox {
            id: lowSpin
            Kirigami.FormData.label: Lang.i18n("Low battery warning at:")
            from: 5; to: 50
            textFromValue: (v) => Lang.percent(v)
            valueFromText: (t) => parseInt(t.replace(/\D+/g, ""))
        }
        QQC2.SpinBox {
            id: criticalSpin
            Kirigami.FormData.label: Lang.i18n("Critical warning at:")
            from: 1; to: 30
            textFromValue: (v) => Lang.percent(v)
            valueFromText: (t) => parseInt(t.replace(/\D+/g, ""))
        }
        QQC2.SpinBox {
            id: deviceSpin
            Kirigami.FormData.label: Lang.i18n("Bluetooth device / phone low at:")
            from: 5; to: 50
            textFromValue: (v) => Lang.percent(v)
            valueFromText: (t) => parseInt(t.replace(/\D+/g, ""))
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Temperature")
        }
        QQC2.SpinBox {
            id: cpuSpin
            Kirigami.FormData.label: Lang.i18n("Warn when the CPU reaches:")
            from: 60; to: 110
            textFromValue: (v) => v + " °C"
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: gpuSpin
            Kirigami.FormData.label: Lang.i18n("Warn when the GPU reaches:")
            from: 60; to: 110
            textFromValue: (v) => v + " °C"
            valueFromText: (t) => parseInt(t)
        }
    }
}
