/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Activity priorities, split island, event duration and per-module switches
    (the pages of the expanded island are in Layout).
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

    property string cfg_priorityOrder
    property alias cfg_splitIsland: splitCheck.checked
    property alias cfg_keepMediaVisible: keepMediaCheck.checked
    property alias cfg_eventDuration: eventSpin.value
    property alias cfg_showPowerEvents: powerCheck.checked
    property alias cfg_showBluetoothEvents: btCheck.checked
    property alias cfg_showOsdEvents: osdCheck.checked
    property alias cfg_showKeyboardEvents: keyboardCheck.checked
    property alias cfg_showNetworkEvents: networkCheck.checked
    property alias cfg_showDndEvents: dndCheck.checked
    property alias cfg_showRecording: recordingCheck.checked
    property alias cfg_showPrivacy: privacyCheck.checked
    property alias cfg_showUnlock: unlockCheck.checked
    property alias cfg_showJobs: jobsCheck.checked
    property alias cfg_watchDownloads: downloadsCheck.checked
    property alias cfg_showKdeConnect: kdeconnectCheck.checked
    property alias cfg_showUpdates: updatesCheck.checked
    property alias cfg_showThermalWarning: thermalCheck.checked
    property alias cfg_enableDbusApi: dbusCheck.checked

    readonly property var categoryNames: ({
        privacy: Lang.i18n("Privacy indicators"),
        call: Lang.i18n("Phone calls"),
        recording: Lang.i18n("Screen recording"),
        event: Lang.i18n("Transient events"),
        timer: Lang.i18n("Timers, Pomodoro, calendar"),
        transfer: Lang.i18n("File operations & custom activities"),
        media: Lang.i18n("Media")
    })
    readonly property var order: cfg_priorityOrder.split(",").map(s => s.trim()).filter(s => s.length > 0)

    function move(index: int, delta: int): void {
        const list = order.slice();
        const target = index + delta;
        if (target < 0 || target >= list.length) return;
        const item = list.splice(index, 1)[0];
        list.splice(target, 0, item);
        cfg_priorityOrder = list.join(",");
    }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Priority")
        }

        ColumnLayout {
            Kirigami.FormData.label: Lang.i18n("Highest first:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            spacing: 2
            Repeater {
                model: page.order
                delegate: RowLayout {
                    required property int index
                    required property string modelData
                    QQC2.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                        text: (index + 1) + ". " + (page.categoryNames[modelData] ?? modelData)
                    }
                    QQC2.ToolButton {
                        icon.name: "go-up"
                        enabled: index > 0
                        onClicked: page.move(index, -1)
                        QQC2.ToolTip.text: Lang.i18n("Move up")
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: index < page.order.length - 1
                        onClicked: page.move(index, 1)
                        QQC2.ToolTip.text: Lang.i18n("Move down")
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }
            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("The highest active item takes the island. Transient events cover everything ranked below \"Transient events\" and wait while something ranked above it is active.")
            }
        }

        QQC2.CheckBox {
            id: splitCheck
            Kirigami.FormData.label: Lang.i18n("Split island:")
            text: Lang.i18n("Show a second activity in a separate bubble")
        }
        QQC2.CheckBox {
            id: keepMediaCheck
            enabled: splitCheck.checked
            text: Lang.i18n("Keep playing media visible (album art takes the bubble if needed)")
        }
        QQC2.SpinBox {
            id: eventSpin
            Kirigami.FormData.label: Lang.i18n("Transient events stay:")
            from: 1000
            to: 10000
            stepSize: 500
            textFromValue: (v) => Lang.i18n("%1 s", (v / 1000).toLocaleString(Lang.locale, 'f', 1))
            valueFromText: (t) => Math.round(Number.fromLocaleString(Lang.locale, t.replace(/[^\d.,]/g, "")) * 1000)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("System events")
        }
        QQC2.CheckBox { id: powerCheck; Kirigami.FormData.label: Lang.i18n("Show:"); text: Lang.i18n("Charging, battery and power profile") }
        QQC2.CheckBox { id: btCheck; text: Lang.i18n("Bluetooth devices") }
        QQC2.CheckBox { id: osdCheck; text: Lang.i18n("Volume, brightness and audio output") }
        QQC2.CheckBox { id: keyboardCheck; text: Lang.i18n("Caps Lock, Num Lock and keyboard layout") }
        QQC2.CheckBox { id: networkCheck; text: Lang.i18n("Wi-Fi, VPN and hotspot") }
        QQC2.CheckBox { id: dndCheck; text: Lang.i18n("Do Not Disturb") }
        QQC2.CheckBox { id: unlockCheck; text: Lang.i18n("\"Unlocked\" after the screen is unlocked") }
        QQC2.CheckBox { id: thermalCheck; text: Lang.i18n("High temperature warning") }
        QQC2.CheckBox { id: updatesCheck; text: Lang.i18n("Available updates") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Live activities")
        }
        QQC2.CheckBox { id: recordingCheck; Kirigami.FormData.label: Lang.i18n("Show:"); text: Lang.i18n("Screen recording / sharing") }
        QQC2.CheckBox { id: privacyCheck; text: Lang.i18n("Microphone and camera indicators") }
        QQC2.CheckBox { id: jobsCheck; text: Lang.i18n("File transfers (Dolphin, KDE Connect, USB drives, downloads)") }
        QQC2.CheckBox { id: downloadsCheck; enabled: jobsCheck.checked; text: Lang.i18n("Watch the download folder for browser downloads") }
        QQC2.CheckBox { id: kdeconnectCheck; text: Lang.i18n("KDE Connect (calls, phone battery)") }
        QQC2.CheckBox { id: dbusCheck; text: Lang.i18n("Activities from other programs (D-Bus, island-push)") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Expanded pages")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            text: Lang.i18n("Which pages are shown, and in what order, is set in Layout.")
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("Screen recording, privacy indicators, unlock, calls, updates and the D-Bus API need the native module (install.sh builds it).")
        }
    }
}
