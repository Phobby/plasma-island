/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property int cfg_appearanceMode
    property alias cfg_showClock: clockCheck.checked
    property alias cfg_topMargin: topMarginSpin.value
    property alias cfg_avoidPanels: avoidPanelsCheck.checked
    property alias cfg_showNotifications: notificationsCheck.checked
    property alias cfg_notificationDuration: durationSpin.value
    property alias cfg_hoverDelay: hoverSpin.value
    property alias cfg_collapseDelay: collapseSpin.value
    property alias cfg_preferredPlayer: playerField.text
    property alias cfg_systemView: systemViewCombo.currentIndex
    property alias cfg_showVolumeModule: volumeCheck.checked

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Appearance")
        }

        QQC2.Label {
            Kirigami.FormData.label: Lang.i18n("Look:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            text: Lang.i18n("Colours, opacity, blur, size and shape are set in Appearance.")
        }

        QQC2.CheckBox {
            id: clockCheck
            Kirigami.FormData.label: Lang.i18n("Idle:")
            text: Lang.i18n("Show clock")
        }

        QQC2.SpinBox {
            id: topMarginSpin
            Kirigami.FormData.label: Lang.i18n("Distance from top:")
            // A custom look brings its own distance (Appearance).
            enabled: page.cfg_appearanceMode === 0
            from: 0
            to: 200
            textFromValue: (v) => Lang.i18n("%1 px", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.CheckBox {
            id: avoidPanelsCheck
            text: Lang.i18n("Place below top panels")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Behavior")
        }

        QQC2.CheckBox {
            id: notificationsCheck
            Kirigami.FormData.label: Lang.i18n("Notifications:")
            text: Lang.i18n("Show incoming notifications in the island")
        }
        QQC2.SpinBox {
            id: durationSpin
            Kirigami.FormData.label: Lang.i18n("Show for:")
            enabled: notificationsCheck.checked
            from: 1000
            to: 20000
            stepSize: 500
            textFromValue: (v) => Lang.i18n("%1 s", (v / 1000).toLocaleString(Lang.locale, 'f', 1))
            valueFromText: (t) => Math.round(Number.fromLocaleString(Lang.locale, t.replace(/[^\d.,]/g, "")) * 1000)
        }
        QQC2.SpinBox {
            id: hoverSpin
            Kirigami.FormData.label: Lang.i18n("Expand after hovering:")
            from: 0
            to: 2000
            stepSize: 50
            textFromValue: (v) => Lang.i18n("%1 ms", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: collapseSpin
            Kirigami.FormData.label: Lang.i18n("Collapse after leaving:")
            from: 0
            to: 3000
            stepSize: 50
            textFromValue: (v) => Lang.i18n("%1 ms", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.TextField {
            id: playerField
            Kirigami.FormData.label: Lang.i18n("Preferred player:")
            placeholderText: Lang.i18n("e.g. spotify, elisa, firefox (empty = automatic)")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Modules")
        }

        QQC2.Label {
            Kirigami.FormData.label: Lang.i18n("Pages:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            text: Lang.i18n("Which pages are shown, and in what order, is set in Layout.")
        }
        QQC2.ComboBox {
            id: systemViewCombo
            Kirigami.FormData.label: Lang.i18n("System view:")
            model: [Lang.i18n("Fixed (5 cards)"), Lang.i18n("Dynamic (active metrics grow)")]
        }
        QQC2.CheckBox {
            id: volumeCheck
            Kirigami.FormData.label: Lang.i18n("Show:")
            text: Lang.i18n("Volume (in Controls)")
        }
    }
}
