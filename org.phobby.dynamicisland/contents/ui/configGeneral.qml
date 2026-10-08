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
    property alias cfg_dotMode: dotModeCheck.checked
    property alias cfg_dotStart: dotStartCombo.currentIndex
    property alias cfg_dotSize: dotSizeSpin.value
    property alias cfg_dotHoverExpand: dotHoverCheck.checked
    property alias cfg_dotEvents: dotEventsCombo.currentIndex
    property alias cfg_dotCriticalExpand: dotCriticalCheck.checked
    property alias cfg_systemView: systemViewCombo.currentIndex
    property alias cfg_updateMode: updateModeCombo.currentIndex

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Appearance")
        }

        QQC2.Label {
            textFormat: Text.PlainText
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
            Kirigami.FormData.label: Lang.i18n("Dot mode")
        }
        QQC2.CheckBox {
            id: dotModeCheck
            Kirigami.FormData.label: Lang.i18n("Click:")
            text: Lang.i18n("A click shrinks the island to a dot")
        }
        QQC2.Label {
            textFormat: Text.PlainText
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            text: Lang.i18n("Click the small island, use the button at the top of the open island, or right-click it. A click on the dot brings the pill back. Off: a click opens the island.")
        }
        QQC2.ComboBox {
            id: dotStartCombo
            Kirigami.FormData.label: Lang.i18n("Start as:")
            enabled: dotModeCheck.checked
            model: [Lang.i18n("As it was left"), Lang.i18n("Always the pill"), Lang.i18n("Always the dot")]
        }
        QQC2.SpinBox {
            id: dotSizeSpin
            Kirigami.FormData.label: Lang.i18n("Dot size:")
            enabled: dotModeCheck.checked
            from: 10
            to: 28
            textFromValue: (v) => Lang.i18n("%1 px", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.CheckBox {
            id: dotHoverCheck
            Kirigami.FormData.label: Lang.i18n("Hovering the dot:")
            enabled: dotModeCheck.checked
            text: Lang.i18n("Opens the island")
        }
        QQC2.ComboBox {
            id: dotEventsCombo
            Kirigami.FormData.label: Lang.i18n("Events in dot mode:")
            enabled: dotModeCheck.checked
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            model: [Lang.i18n("Only the dot shows them"), Lang.i18n("Open for them, then back to the dot"), Lang.i18n("Show nothing")]
        }
        QQC2.CheckBox {
            id: dotCriticalCheck
            enabled: dotModeCheck.checked
            text: Lang.i18n("Always open for critical events (incoming call, alarm, low battery)")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Modules")
        }

        QQC2.Label {
            textFormat: Text.PlainText
            Kirigami.FormData.label: Lang.i18n("Pages:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            text: Lang.i18n("Which pages are shown, in what order, and the parts inside them, is set in Layout.")
        }
        QQC2.ComboBox {
            id: systemViewCombo
            Kirigami.FormData.label: Lang.i18n("System view:")
            model: [Lang.i18n("Fixed (5 cards)"), Lang.i18n("Dynamic (active metrics grow)")]
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("New versions of the island")
        }
        QQC2.ComboBox {
            id: updateModeCombo
            Kirigami.FormData.label: Lang.i18n("When there is one:")
            model: [Lang.i18n("Never look"), Lang.i18n("Ask me"), Lang.i18n("Install by itself")]
        }
        QQC2.Label {
            textFormat: Text.PlainText
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            opacity: 0.7
            text: updateModeCombo.currentIndex === 0 ? Lang.i18n("The island asks nobody about new versions. To update by hand: git pull in its folder, then ./install.sh.")
                : Lang.i18n("Once a day the island reads the newest version number from its repository on GitHub; nothing about you is sent. An update is fetched from there, built and installed for your user only, and keeps your settings. Installing needs the native module.")
                  + (updateModeCombo.currentIndex === 2 ? " " + Lang.i18n("By itself it installs without asking, and asks only before the desktop shell restarts.") : "")
        }
    }
}
