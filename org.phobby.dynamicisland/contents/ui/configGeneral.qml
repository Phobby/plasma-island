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

    property alias cfg_surfaceOpacity: opacitySlider.value
    property alias cfg_blurEnabled: blurCheck.checked
    property alias cfg_themeMode: themeCombo.currentIndex
    property alias cfg_showClock: clockCheck.checked
    property alias cfg_topMargin: topMarginSpin.value
    property alias cfg_avoidPanels: avoidPanelsCheck.checked
    property alias cfg_showNotifications: notificationsCheck.checked
    property alias cfg_notificationDuration: durationSpin.value
    property alias cfg_hoverDelay: hoverSpin.value
    property alias cfg_collapseDelay: collapseSpin.value
    property alias cfg_preferredPlayer: playerField.text
    property alias cfg_showMediaModule: mediaCheck.checked
    property alias cfg_showSystemModule: systemCheck.checked
    property alias cfg_showVolumeModule: volumeCheck.checked
    property alias cfg_showNotificationModule: notifModuleCheck.checked

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Appearance")
        }

        QQC2.ComboBox {
            id: themeCombo
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Follow color scheme"), i18n("Always dark (graphite)"), i18n("Always light (aluminium)")]
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Opacity:")
            QQC2.Slider {
                id: opacitySlider
                from: 30
                to: 100
                stepSize: 1
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            }
            QQC2.Label {
                text: Math.round(opacitySlider.value) + "%"
            }
        }

        QQC2.CheckBox {
            id: blurCheck
            Kirigami.FormData.label: i18n("Background:")
            text: i18n("Blur what is behind the island")
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Needs the optional native helper (install.sh --with-blur) and the KWin Blur effect. Without it the surface stays opaque.")
        }

        QQC2.CheckBox {
            id: clockCheck
            Kirigami.FormData.label: i18n("Idle:")
            text: i18n("Show clock")
        }

        QQC2.SpinBox {
            id: topMarginSpin
            Kirigami.FormData.label: i18n("Distance from top:")
            from: 0
            to: 200
            textFromValue: (v) => i18n("%1 px", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.CheckBox {
            id: avoidPanelsCheck
            text: i18n("Place below top panels")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Behavior")
        }

        QQC2.CheckBox {
            id: notificationsCheck
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("Show incoming notifications in the island")
        }
        QQC2.SpinBox {
            id: durationSpin
            Kirigami.FormData.label: i18n("Show for:")
            enabled: notificationsCheck.checked
            from: 1000
            to: 20000
            stepSize: 500
            textFromValue: (v) => i18n("%1 s", (v / 1000).toLocaleString(Qt.locale(), 'f', 1))
            valueFromText: (t) => Math.round(Number.fromLocaleString(Qt.locale(), t.replace(/[^\d.,]/g, "")) * 1000)
        }
        QQC2.SpinBox {
            id: hoverSpin
            Kirigami.FormData.label: i18n("Expand after hovering:")
            from: 0
            to: 2000
            stepSize: 50
            textFromValue: (v) => i18n("%1 ms", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: collapseSpin
            Kirigami.FormData.label: i18n("Collapse after leaving:")
            from: 0
            to: 3000
            stepSize: 50
            textFromValue: (v) => i18n("%1 ms", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.TextField {
            id: playerField
            Kirigami.FormData.label: i18n("Preferred player:")
            placeholderText: i18n("e.g. spotify, elisa, firefox (empty = automatic)")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Modules")
        }

        QQC2.CheckBox {
            id: mediaCheck
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("Media (also enables the live activity)")
        }
        QQC2.CheckBox {
            id: systemCheck
            text: i18n("System status (CPU, RAM, battery, network)")
        }
        QQC2.CheckBox {
            id: volumeCheck
            text: i18n("Volume")
        }
        QQC2.CheckBox {
            id: notifModuleCheck
            text: i18n("Recent notifications")
        }
    }
}
