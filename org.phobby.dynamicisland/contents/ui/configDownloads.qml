/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Download tracking: which downloads the island shows beyond the file
    transfers of KDE's own job list (browsers through their download folder,
    apt and PackageKit, git clone, command-line downloaders), what counts as
    too small or too short to show, the folders and the commands looked at.
    Everything here only reads files, processes and D-Bus of this computer.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "TransferFormat.js" as Fmt

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }
    property alias cfg_trackDownloads: mainSwitch.checked
    property alias cfg_watchDownloads: browserCheck.checked
    property alias cfg_trackPackages: packagesCheck.checked
    property alias cfg_trackGit: gitCheck.checked
    property alias cfg_trackTools: toolsCheck.checked
    property alias cfg_trackBackground: backgroundCheck.checked
    property alias cfg_trackAnnounceEnd: announceCheck.checked
    property alias cfg_trackMinSeconds: secondsSpin.value
    property alias cfg_trackMinKilobytes: sizeSpin.value
    property alias cfg_trackSettleSeconds: settleSpin.value
    property alias cfg_trackFolders: foldersArea.text
    property alias cfg_trackCommandsAdded: addedArea.text
    property string cfg_trackCommandsRemoved

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

    Kirigami.FormLayout {
        QQC2.Switch {
            id: mainSwitch
            Kirigami.FormData.label: Lang.i18n("Download tracking:")
            text: Lang.i18n("Show downloads that have no window of their own")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.Wrap
            opacity: 0.7
            text: Lang.i18n("Seen from outside: files, processes and D-Bus of this computer are read, nothing is asked of the network and no command is wrapped, stopped or changed. Where the size of a download cannot be known, no percentage and no remaining time are shown.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Sources")
        }
        QQC2.CheckBox { id: browserCheck; enabled: mainSwitch.checked; Kirigami.FormData.label: Lang.i18n("Show:"); text: Lang.i18n("Browser downloads (the download folder)") }
        QQC2.CheckBox { id: packagesCheck; enabled: mainSwitch.checked; text: Lang.i18n("Packages (apt, Discover / PackageKit)") }
        QQC2.CheckBox { id: gitCheck; enabled: mainSwitch.checked; text: Lang.i18n("git clone") }
        QQC2.CheckBox { id: toolsCheck; enabled: mainSwitch.checked; text: Lang.i18n("Command-line downloaders (wget, curl, pip…)") }
        QQC2.CheckBox {
            id: backgroundCheck
            enabled: mainSwitch.checked && (packagesCheck.checked || gitCheck.checked || toolsCheck.checked)
            text: Lang.i18n("Also what runs in the background (automatic updates, scripts without a terminal)")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("What is shown")
        }
        QQC2.SpinBox {
            id: secondsSpin
            enabled: mainSwitch.checked
            Kirigami.FormData.label: Lang.i18n("Shown once it has lasted:")
            from: 0; to: 30
            textFromValue: (v) => Lang.i18n("%1 s", v)
            valueFromText: (t) => parseInt(t.replace(/\D+/g, "")) || 0
        }
        QQC2.SpinBox {
            id: sizeSpin
            enabled: mainSwitch.checked && toolsCheck.checked
            Kirigami.FormData.label: Lang.i18n("Command-line downloads from:")
            from: 0; to: 1048576; stepSize: 256
            textFromValue: (v) => Fmt.bytes(v * 1024, Lang.language === "tr")
            valueFromText: (t) => Math.round((parseFloat(t.replace(",", ".")) || 0) * (/GB/i.test(t) ? 1048576 : /MB/i.test(t) ? 1024 : 1))
        }
        QQC2.CheckBox {
            id: announceCheck
            enabled: mainSwitch.checked
            Kirigami.FormData.label: Lang.i18n("When it ends:")
            text: Lang.i18n("Say so (\"Downloaded\", with the name, the size and the time it took)")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.Wrap
            opacity: 0.7
            text: Lang.i18n("A download that is over sooner only gets its end. A command whose result cannot be seen from outside ends as \"Finished\", not as a success or a failure.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Browser downloads")
        }
        QQC2.TextArea {
            id: foldersArea
            enabled: mainSwitch.checked && browserCheck.checked
            Kirigami.FormData.label: Lang.i18n("Watched folders:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            Layout.preferredHeight: Kirigami.Units.gridUnit * 4
            placeholderText: Lang.i18n("One folder per line. Empty: your download folder.")
            wrapMode: TextEdit.NoWrap
        }
        QQC2.SpinBox {
            id: settleSpin
            enabled: mainSwitch.checked && browserCheck.checked
            Kirigami.FormData.label: Lang.i18n("Wait for the finished file:")
            from: 1; to: 30
            textFromValue: (v) => Lang.i18n("%1 s", v)
            valueFromText: (t) => parseInt(t.replace(/\D+/g, "")) || 3
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Watched commands")
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
                    enabled: mainSwitch.checked && (modelData.kind === "packages" ? packagesCheck.checked : modelData.kind === "clone" ? gitCheck.checked : toolsCheck.checked)
                    text: modelData.name
                    checked: page.removed.indexOf(modelData.name) < 0
                    onToggled: page.setRemoved(modelData.name, !checked)
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: page.kindName(modelData.kind)
                }
            }
        }
        QQC2.TextArea {
            id: addedArea
            enabled: mainSwitch.checked && toolsCheck.checked
            Kirigami.FormData.label: Lang.i18n("Your own:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            Layout.preferredHeight: Kirigami.Units.gridUnit * 3
            placeholderText: Lang.i18n("A command's name per line, e.g. rsync. Shown as a download.")
            wrapMode: TextEdit.NoWrap
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            wrapMode: Text.Wrap
            opacity: 0.7
            text: Lang.i18n("Of a command only its name, its sub-command, the host and a repository's name are ever read out: never the whole command line, which may hold a password.")
        }
    }
}
