/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Settings → Activities: what the small island shows besides the clock.
    Up front the split island and download tracking; folded: which events
    and live activities are shown, their priority, the warning thresholds
    (battery, temperature) and what download tracking looks at (browsers
    through their download folder, apt and PackageKit, git clone,
    command-line downloaders; what is too small or too short to show).
    Download tracking only reads files, processes and D-Bus of this computer.
    How long an event stays is General's Response.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "TransferFormat.js" as Fmt

KCM.SimpleKCM {
    id: page
    header: SettingsSearch { page: page; pageName: "configActivities" }
    Loader { id: nativeCheck; source: "LocalBridge.qml" }

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property string cfg_priorityOrder
    property bool cfg_splitIsland
    property bool cfg_keepMediaVisible
    property bool cfg_showPowerEvents
    property bool cfg_showBluetoothEvents
    property bool cfg_showOsdEvents
    property bool cfg_showKeyboardEvents
    property bool cfg_showNetworkEvents
    property bool cfg_showDndEvents
    property bool cfg_showRecording
    property bool cfg_showPrivacy
    property bool cfg_showUnlock
    property bool cfg_showJobs
    property bool cfg_showKdeConnect
    property bool cfg_showUpdates
    property bool cfg_showThermalWarning
    property bool cfg_enableDbusApi
    // Warning thresholds.
    property int cfg_lowBatteryThreshold
    property int cfg_criticalBatteryThreshold
    property int cfg_deviceBatteryThreshold
    property int cfg_cpuTempThreshold
    property int cfg_gpuTempThreshold
    // Download tracking.
    property bool cfg_trackDownloads
    property bool cfg_watchDownloads
    property bool cfg_trackPackages
    property bool cfg_trackGit
    property bool cfg_trackTools
    property bool cfg_trackBackground
    property bool cfg_trackAnnounceEnd
    property int cfg_trackMinSeconds
    property int cfg_trackMinKilobytes
    property int cfg_trackSettleSeconds
    property string cfg_trackFolders
    property string cfg_trackCommandsAdded
    property string cfg_trackCommandsRemoved

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

    // The commands looked for by default, with a switch each (off = named in trackCommandsRemoved).
    readonly property var removed: cfg_trackCommandsRemoved.split(/[\n,]/).map(s => s.trim()).filter(s => s.length > 0)
    function setRemoved(name: string, off: bool): void {
        const list = removed.filter(n => n !== name);
        if (off) list.push(name);
        cfg_trackCommandsRemoved = list.join("\n");
    }
    function kindName(kind: string): string {
        return kind === "packages" ? Lang.i18n("Packages") : kind === "clone" ? Lang.i18n("Repository") : Lang.i18n("Download");
    }

    component Hint: QQC2.Label {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }

    Kirigami.FormLayout {
        id: form

        SettingCheck {
            settings: page; key: "splitIsland"
            Kirigami.FormData.label: Lang.i18n("Split island:")
            text: Lang.i18n("Show a second activity in a separate bubble")
        }
        SettingCheck {
            settings: page; key: "keepMediaVisible"
            // (search needs: "splitIsland")
            visible: page.cfg_splitIsland
            text: Lang.i18n("Keep playing media visible (album art takes the bubble if needed)")
        }
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Download tracking:")
            SettingCheck {
                settings: page; key: "trackDownloads"
                text: Lang.i18n("Show downloads that have no window of their own")
            }
            Kirigami.ContextualHelpButton {
                toolTipText: Lang.i18n("Seen from outside: files, processes and D-Bus of this computer are read, nothing is asked of the network and no command is wrapped, stopped or changed. Where the size of a download cannot be known, no percentage and no remaining time are shown.")
            }
        }

        // Screen recording, privacy indicators, unlock, calls, updates and the D-Bus API need the native module:
        // said only where it is missing.
        RequirementNotice {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            visible: nativeCheck.status === Loader.Error
            requirement: "native"
        }

        // ---- what is shown ---------------------------------------------------------------
        SettingsFold {
            title: Lang.i18n("Events shown")
            foldId: "activities.events"
            twin: form
            keys: ["showPowerEvents", "showBluetoothEvents", "showOsdEvents", "showKeyboardEvents", "showNetworkEvents",
                   "showDndEvents", "showUnlock", "showThermalWarning", "showUpdates", "showRecording", "showPrivacy",
                   "showJobs", "showKdeConnect", "enableDbusApi"]
            content: Kirigami.FormLayout {
                SettingCheck { settings: page; key: "showPowerEvents"; Kirigami.FormData.label: Lang.i18n("System events"); text: Lang.i18n("Charging, battery and power profile") }
                SettingCheck { settings: page; key: "showBluetoothEvents"; text: Lang.i18n("Bluetooth devices") }
                SettingCheck { settings: page; key: "showOsdEvents"; text: Lang.i18n("Volume, brightness and audio output") }
                SettingCheck { settings: page; key: "showKeyboardEvents"; text: Lang.i18n("Caps Lock, Num Lock and keyboard layout") }
                SettingCheck { settings: page; key: "showNetworkEvents"; text: Lang.i18n("Wi-Fi, VPN and hotspot") }
                SettingCheck { settings: page; key: "showDndEvents"; text: Lang.i18n("Do Not Disturb") }
                SettingCheck { settings: page; key: "showUnlock"; text: Lang.i18n("\"Unlocked\" after the screen is unlocked") }
                SettingCheck { settings: page; key: "showThermalWarning"; text: Lang.i18n("High temperature warning") }
                SettingCheck { settings: page; key: "showUpdates"; text: Lang.i18n("Available updates") }
                SettingCheck { settings: page; key: "showRecording"; Kirigami.FormData.label: Lang.i18n("Live activities"); text: Lang.i18n("Screen recording / sharing") }
                SettingCheck { settings: page; key: "showPrivacy"; text: Lang.i18n("Microphone and camera indicators") }
                SettingCheck { settings: page; key: "showJobs"; text: Lang.i18n("File transfers (Dolphin, KDE Connect, USB drives, downloads)") }
                SettingCheck { settings: page; key: "showKdeConnect"; text: Lang.i18n("KDE Connect (calls, phone battery)") }
                SettingCheck { settings: page; key: "enableDbusApi"; text: Lang.i18n("Activities from other programs (D-Bus, island-push)") }
            }
        }

        // ---- priority -------------------------------------------------------------------
        SettingsFold {
            title: Lang.i18n("Priority")
            foldId: "activities.priority"
            twin: form
            keys: ["priorityOrder"]
            content: Kirigami.FormLayout {
                ColumnLayout {
                    objectName: "setting-priorityOrder"
                    Kirigami.FormData.label: Lang.i18n("Highest first:")
                    Kirigami.FormData.labelAlignment: Qt.AlignTop
                    spacing: 2
                    Repeater {
                        model: page.order
                        delegate: RowLayout {
                            required property int index
                            required property string modelData
                            QQC2.Label {
                                textFormat: Text.PlainText
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                                text: (index + 1) + ". " + (page.categoryNames[modelData] ?? modelData)
                            }
                            QQC2.ToolButton {
                                icon.name: "go-up"
                                enabled: index > 0
                                onClicked: page.move(index, -1)
                                text: Lang.i18n("Move up")
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.visible: hovered
                            }
                            QQC2.ToolButton {
                                icon.name: "go-down"
                                enabled: index < page.order.length - 1
                                onClicked: page.move(index, 1)
                                text: Lang.i18n("Move down")
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.visible: hovered
                            }
                        }
                    }
                    Hint {
                        text: Lang.i18n("The highest active item takes the island. Transient events cover everything ranked below \"Transient events\" and wait while something ranked above it is active.")
                    }
                }
            }
        }

        // ---- warning thresholds ------------------------------------------------------------
        SettingsFold {
            title: Lang.i18n("Warning thresholds")
            foldId: "activities.alerts"
            twin: form
            keys: ["lowBatteryThreshold", "criticalBatteryThreshold", "deviceBatteryThreshold", "cpuTempThreshold", "gpuTempThreshold"]
            content: Kirigami.FormLayout {
                SettingSpin { settings: page; key: "lowBatteryThreshold"; Kirigami.FormData.label: Lang.i18n("Low battery warning at:"); from: 5; to: 50; textFromValue: v => Lang.percent(v); valueFromText: t => parseInt(t.replace(/\D+/g, "")) }
                SettingSpin { settings: page; key: "criticalBatteryThreshold"; Kirigami.FormData.label: Lang.i18n("Critical warning at:"); from: 1; to: 30; textFromValue: v => Lang.percent(v); valueFromText: t => parseInt(t.replace(/\D+/g, "")) }
                SettingSpin { settings: page; key: "deviceBatteryThreshold"; Kirigami.FormData.label: Lang.i18n("Bluetooth device / phone low at:"); from: 5; to: 50; textFromValue: v => Lang.percent(v); valueFromText: t => parseInt(t.replace(/\D+/g, "")) }
                SettingSpin { settings: page; key: "cpuTempThreshold"; Kirigami.FormData.label: Lang.i18n("Warn when the CPU reaches:"); from: 60; to: 110; unit: "%1 °C" }
                SettingSpin { settings: page; key: "gpuTempThreshold"; Kirigami.FormData.label: Lang.i18n("Warn when the GPU reaches:"); from: 60; to: 110; unit: "%1 °C" }
            }
        }

        // ---- what download tracking looks at (only while it is on) ---------------------------
        SettingsFold {
            title: Lang.i18n("Download tracking details")
            foldId: "activities.downloads"
            twin: form
            visible: page.cfg_trackDownloads
            needs: "trackDownloads"
            keys: ["watchDownloads", "trackPackages", "trackGit", "trackTools", "trackBackground", "trackMinSeconds",
                   "trackMinKilobytes", "trackAnnounceEnd", "trackFolders", "trackSettleSeconds", "trackCommandsAdded"]
            content: Kirigami.FormLayout {
                SettingCheck { settings: page; key: "watchDownloads"; Kirigami.FormData.label: Lang.i18n("Show:"); text: Lang.i18n("Browser downloads (the download folder)") }
                SettingCheck { settings: page; key: "trackPackages"; text: Lang.i18n("Packages (apt, Discover / PackageKit)") }
                SettingCheck { settings: page; key: "trackGit"; text: Lang.i18n("git clone") }
                SettingCheck { settings: page; key: "trackTools"; text: Lang.i18n("Command-line downloaders (wget, curl, pip…)") }
                SettingCheck {
                    settings: page; key: "trackBackground"
                    enabled: page.cfg_trackPackages || page.cfg_trackGit || page.cfg_trackTools
                    text: Lang.i18n("Also what runs in the background (automatic updates, scripts without a terminal)")
                }
                SettingSpin {
                    settings: page; key: "trackMinSeconds"
                    Kirigami.FormData.label: Lang.i18n("Shown once it has lasted:")
                    from: 0; to: 30
                    unit: Lang.i18n("%1 s")
                }
                QQC2.SpinBox {
                    id: sizeSpin
                    objectName: "setting-trackMinKilobytes"
                    enabled: page.cfg_trackTools
                    Kirigami.FormData.label: Lang.i18n("Command-line downloads from:")
                    from: 0; to: 1048576; stepSize: 256
                    editable: true
                    Binding { target: sizeSpin; property: "value"; value: page.cfg_trackMinKilobytes }
                    onValueModified: page.cfg_trackMinKilobytes = value
                    textFromValue: (v) => Fmt.bytes(v * 1024, Lang.language === "tr")
                    valueFromText: (t) => Math.round((parseFloat(t.replace(",", ".")) || 0) * (/GB/i.test(t) ? 1048576 : /MB/i.test(t) ? 1024 : 1))
                    Accessible.name: Lang.i18n("Command-line downloads from:")
                }
                RowLayout {
                    Kirigami.FormData.label: Lang.i18n("When it ends:")
                    SettingCheck {
                        settings: page; key: "trackAnnounceEnd"
                        text: Lang.i18n("Say so (\"Downloaded\", with the name, the size and the time it took)")
                    }
                    Kirigami.ContextualHelpButton {
                        toolTipText: Lang.i18n("A download that is over sooner only gets its end. A command whose result cannot be seen from outside ends as \"Finished\", not as a success or a failure.")
                    }
                }
                QQC2.TextArea {
                    objectName: "setting-trackFolders"
                    enabled: page.cfg_watchDownloads
                    Kirigami.FormData.label: Lang.i18n("Watched folders:")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 4
                    placeholderText: Lang.i18n("One folder per line. Empty: your download folder.")
                    wrapMode: TextEdit.NoWrap
                    text: page.cfg_trackFolders
                    onTextChanged: if (text !== page.cfg_trackFolders) page.cfg_trackFolders = text
                    Accessible.name: Lang.i18n("Watched folders:")
                }
                SettingSpin {
                    settings: page; key: "trackSettleSeconds"
                    enabled: page.cfg_watchDownloads
                    Kirigami.FormData.label: Lang.i18n("Wait for the finished file:")
                    from: 1; to: 30
                    unit: Lang.i18n("%1 s")
                }
                Flow {
                    Kirigami.FormData.label: Lang.i18n("Looked for:")
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 26
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: Fmt.COMMANDS
                        delegate: QQC2.CheckBox {
                            required property var modelData
                            objectName: "command-" + modelData.name
                            enabled: modelData.kind === "packages" ? page.cfg_trackPackages : modelData.kind === "clone" ? page.cfg_trackGit : page.cfg_trackTools
                            text: modelData.name
                            checked: page.removed.indexOf(modelData.name) < 0
                            onToggled: page.setRemoved(modelData.name, !checked)
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: page.kindName(modelData.kind)
                        }
                    }
                }
                QQC2.TextArea {
                    objectName: "setting-trackCommandsAdded"
                    enabled: page.cfg_trackTools
                    Kirigami.FormData.label: Lang.i18n("Your own:")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    placeholderText: Lang.i18n("A command's name per line, e.g. rsync. Shown as a download.")
                    wrapMode: TextEdit.NoWrap
                    text: page.cfg_trackCommandsAdded
                    onTextChanged: if (text !== page.cfg_trackCommandsAdded) page.cfg_trackCommandsAdded = text
                    Accessible.name: Lang.i18n("Your own:")
                }
                Hint {
                    text: Lang.i18n("Of a command only its name, its sub-command, the host and a repository's name are ever read out: never the whole command line, which may hold a password.")
                }
            }
        }
    }
}
