/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Settings → Diagnostics: what the island's features need and whether it is
    there (RequirementCatalog.qml), where it was looked for, the path and
    version of what was found, a path given by hand for a command
    (commandPaths), whether the island's native and effects modules loaded,
    and this computer's session, Plasma and Qt. "Copy diagnostics" puts all
    of it on the clipboard for a bug report, with the user's name, the
    computer's name and the home folder left out (Diagnostics.js). Feedback
    (FeedbackForm.qml) sends a few lines to the author, only with its button.

    Commands are looked for as the island looks for them (native module:
    userpaths.h); a version is asked of a command (`--version`) only here,
    when the page opens or "Check again" is pressed. Nothing is installed or
    started.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "Diagnostics.js" as Diagnostics

KCM.SimpleKCM {
    id: page
    header: SettingsSearch { page: page; pageName: "configDiagnostics"; revealHere: false }

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }
    property string cfg_commandPaths
    property string cfg_installedVersion

    function widget(): var { try { return Plasmoid.configuration; } catch (e) { return null; } }

    // The native module's LocalTools, of this window's own (the island's is in the shell's other engine).
    Loader { id: localLoader; source: "LocalBridge.qml" }
    readonly property var local: localLoader.status === Loader.Ready ? localLoader.item : null
    Loader { id: effectsProbe; source: "probes/EffectsProbe.qml" }
    Loader { id: multimediaProbe; source: "probes/MultimediaProbe.qml" }
    Loader { id: layerShellProbe; source: "probes/LayerShellProbe.qml" }
    Loader { id: kdeConnectProbe; source: "probes/KdeConnectProbe.qml" }

    readonly property var given: { try { const v = JSON.parse(page.cfg_commandPaths || "{}"); return v && typeof v === "object" ? v : {}; } catch (e) { return {}; } }
    function setGiven(id: string, path: string): void {
        const next = Object.assign({}, given);
        if (path.trim().length > 0) next[id] = path.trim(); else delete next[id];
        page.cfg_commandPaths = Object.keys(next).length > 0 ? JSON.stringify(next) : "";
    }

    // What was found: id → { state ("found", "missing", "unknown"), path, via, version, given, givenUsable }
    property var rows: ({})
    property var info: ({})
    property var searched: []
    property bool looking: false

    function moduleState(loader: var): string { return loader.status === Loader.Ready ? "found" : loader.status === Loader.Error ? "missing" : "unknown"; }
    function look(): void {
        Requirements.recheck();
        const out = {};
        for (const id of RequirementCatalog.order) {
            const item = RequirementCatalog.item(id);
            if (id === "native") { out[id] = { state: page.local !== null ? "found" : "missing", path: "", via: "" }; continue; }
            if (id === "multimedia") { out[id] = { state: moduleState(multimediaProbe), path: "", via: "" }; continue; }
            if (id === "layershell") { out[id] = { state: moduleState(layerShellProbe), path: "", via: "" }; continue; }
            if (page.local === null) { out[id] = { state: "unknown", path: "", via: "" }; continue; }
            // (the module's QML part is what the island uses; the app is looked for besides)
            const command = (item.commands || [])[0] || (id === "kwallet" ? "kwalletd6" : "");
            const where = command.length === 0 ? { path: "" } : typeof page.local.locate === "function"
                ? page.local.locate(command, String(page.given[id] || ""), String(page.given[id] || "").length > 0)
                : { path: page.local.findExecutable(command), via: "" };
            const found = id === "kdeconnect" ? kdeConnectProbe.status === Loader.Ready : String(where.path || "").length > 0;
            out[id] = { state: found ? "found" : "missing", path: String(where.path || ""), via: String(where.via || ""),
                        given: String(where.given || ""), givenUsable: where.givenUsable === true, version: "" };
        }
        rows = out;
        searched = page.local !== null && typeof page.local.searchedDirectories === "function" ? page.local.searchedDirectories() : [];
        const system = page.local !== null && typeof page.local.systemInfo === "function" ? page.local.systemInfo() : {};
        info = Object.assign({ island: page.islandVersion, session: Qt.platform.pluginName.startsWith("wayland") ? "Wayland" : Qt.platform.pluginName === "xcb" ? "X11" : Qt.platform.pluginName,
                               native: page.local !== null, effects: effectsProbe.status === Loader.Ready, plasma: "" }, system,
                             { session: Qt.platform.pluginName.startsWith("wayland") ? "Wayland" : Qt.platform.pluginName === "xcb" ? "X11" : Qt.platform.pluginName });
        if (page.local === null) return;
        // versions: asked of what was found, one after another
        page.local.run("plasmashell", ["--version"], (code, text) => {
            page.info = Object.assign({}, page.info, { plasma: code === 0 ? Diagnostics.versionOf(text).replace(/^plasmashell\s*/, "") : "" });
        });
        for (const id of RequirementCatalog.order) {
            const r = out[id];
            if (r.state !== "found" || r.path.length === 0 || id === "kdeconnect" || id === "kwallet") continue;
            const args = id === "pipewire" || id === "pwrecord" ? ["--version"] : ["--version"];
            page.local.run(r.path, args, (code, text, err) => {
                const next = Object.assign({}, page.rows);
                next[id] = Object.assign({}, next[id], { version: Diagnostics.versionOf(text || err) });
                page.rows = next;
            });
        }
    }
    readonly property string islandVersion: { try { return String(Plasmoid.metaData.version || page.cfg_installedVersion || ""); } catch (e) { return page.cfg_installedVersion; } }
    readonly property var who: page.local !== null && typeof page.local.systemInfo === "function" ? page.local.systemInfo() : ({})
    function reportText(): string {
        return Diagnostics.report(page.info, RequirementCatalog.order.map(id => Object.assign({ id: id }, page.rows[id] || { state: "unknown" })), page.searched, page.who);
    }
    function copy(value: string): void {
        clip.text = value;
        clip.selectAll();
        clip.copy();
        clip.text = "";
    }
    TextEdit { id: clip; visible: false; textFormat: TextEdit.PlainText }

    // Come here from the island or a "Set the path by hand": that row, its field in focus.
    function reveal(id: string): void {
        let row = null;
        for (let i = 0; i < rowsColumn.children.length; ++i) if (rowsColumn.children[i].requirement === id) row = rowsColumn.children[i];
        if (row === null) {
            // (the list as a whole: where a command's path is given by hand)
            if (id === "commandPaths") page.flickable.contentY = Math.max(0, needsHeading.mapToItem(page.flickable.contentItem, 0, 0).y - Kirigami.Units.gridUnit);
            return;
        }
        page.flickable.contentY = Math.max(0, row.mapToItem(page.flickable.contentItem, 0, 0).y - Kirigami.Units.gridUnit);
        row.flash();
        if (row.pathField) row.pathField.forceActiveFocus();
    }
    Connections {
        target: SettingsNav
        function onRevealRequested(target, key) { if (target === "configDiagnostics") Qt.callLater(() => { const k = SettingsNav.take("configDiagnostics"); if (k.trim().length > 0) page.reveal(k); }); }
    }
    Component.onCompleted: {
        Qt.callLater(look);
        Qt.callLater(() => { const k = SettingsNav.take("configDiagnostics"); if (k.trim().length > 0) Qt.callLater(() => page.reveal(k)); });
    }
    component Hint: QQC2.Label {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 28
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.8
    }
    readonly property var viaWords: ({ setting: Lang.i18n("set by hand"), path: Lang.i18n("on the shell's PATH"), folder: Lang.i18n("in a folder of the user's own commands"),
                                       appimage: Lang.i18n("an AppImage") })

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            id: form
            Layout.fillWidth: true
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: Lang.i18n("This computer") }
            QQC2.Label { textFormat: Text.PlainText; Kirigami.FormData.label: Lang.i18n("Island:"); text: page.islandVersion || Lang.i18n("unknown") }
            QQC2.Label { textFormat: Text.PlainText; Kirigami.FormData.label: Lang.i18n("Session:"); text: String(page.info.session || "") }
            QQC2.Label { textFormat: Text.PlainText; Kirigami.FormData.label: Lang.i18n("Plasma:"); text: String(page.info.plasma || "") || Lang.i18n("unknown") }
            QQC2.Label { textFormat: Text.PlainText; Kirigami.FormData.label: Lang.i18n("Qt:"); text: String(page.info.qt || "") || Lang.i18n("unknown") }
            QQC2.Label { textFormat: Text.PlainText; Kirigami.FormData.label: Lang.i18n("System:"); text: String(page.info.os || "") || Lang.i18n("unknown") }
            QQC2.Label {
                textFormat: Text.PlainText
                Kirigami.FormData.label: Lang.i18n("Island's modules:")
                text: (page.local !== null ? Lang.i18n("native module loaded") : Lang.i18n("native module not loaded")) + " · "
                      + (effectsProbe.status === Loader.Ready ? Lang.i18n("effects module loaded") : Lang.i18n("effects module not loaded"))
            }
            RowLayout {
                Kirigami.FormData.label: Lang.i18n("Report:")
                QQC2.Button {
                    objectName: "recheckButton"
                    icon.name: "view-refresh"
                    text: Lang.i18n("Check again")
                    onClicked: page.look()
                }
                QQC2.Button {
                    objectName: "copyReport"
                    icon.name: "edit-copy"
                    text: copied.running ? Lang.i18n("Copied") : Lang.i18n("Copy diagnostics")
                    onClicked: { page.copy(page.reportText()); copied.restart(); }
                    Timer { id: copied; interval: 2500 }
                }
            }
            Hint {
                text: Lang.i18n("For a bug report: your user name, the computer's name and your home folder are left out of what is copied (written as <user>, <host> and ~).")
            }
        }

        Kirigami.Heading {
            id: needsHeading
            objectName: "setting-commandPaths"
            Layout.fillWidth: true
            level: 3
            text: Lang.i18n("What the features need")
            textFormat: Text.PlainText
        }
        Hint {
            text: page.local === null ? Lang.i18n("Without the native module nothing can be looked for: install it first (below).")
                : Lang.i18n("Looked for where the island looks: the shell's PATH, the folders of the user's own commands (~/.local/bin, ~/.cargo/bin, npm's, /usr/local/bin, /snap/bin, Flatpak's…) and AppImages in ~/Applications. A path given here comes first.")
        }

        ColumnLayout {
            id: rowsColumn
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            Repeater {
                model: RequirementCatalog.order
                delegate: Rectangle {
                    id: entry
                    required property string modelData
                    readonly property string requirement: modelData
                    readonly property var item: RequirementCatalog.item(modelData)
                    readonly property var row: page.rows[modelData] || ({ state: "unknown" })
                    readonly property bool isCommand: item !== null && (item.kind === "command") && page.local !== null
                    property alias pathField: pathField
                    property bool open: false
                    Layout.fillWidth: true
                    implicitHeight: entryColumn.implicitHeight + 2 * Kirigami.Units.smallSpacing
                    radius: Kirigami.Units.cornerRadius
                    // (come here from elsewhere: the row lights up for a moment)
                    property bool lit: false
                    color: lit ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
                    function flash(): void { open = true; lit = true; fade.restart(); }
                    Timer { id: fade; interval: 1800; onTriggered: entry.lit = false }
                    ColumnLayout {
                    id: entryColumn
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing
                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: entry.row.state === "found" ? "dialog-ok-apply" : entry.row.state === "missing" ? (entry.item.optional ? "dialog-information" : "dialog-warning") : "question"
                        }
                        QQC2.Label {
                            textFormat: Text.PlainText
                            font.weight: Font.DemiBold
                            text: entry.item.name
                        }
                        QQC2.Label {
                            textFormat: Text.PlainText
                            objectName: "state-" + entry.modelData
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: entry.row.state === "found" ? Lang.i18n("found") + (entry.row.version ? " · " + entry.row.version : "")
                                : entry.row.state === "missing" ? (entry.modelData === "native" ? Lang.i18n("not installed") : Lang.i18n("not found"))
                                : page.local === null ? Lang.i18n("cannot be looked for without the native module") : Lang.i18n("not looked for yet")
                            opacity: 0.85
                        }
                        QQC2.ToolButton {
                            visible: entry.row.state !== "found" || entry.isCommand
                            icon.name: entry.open ? "arrow-up" : "arrow-down"
                            text: entry.open ? Lang.i18n("Less") : entry.row.state === "found" ? Lang.i18n("Path") : Lang.i18n("How to get it")
                            Accessible.name: text + ": " + entry.item.name
                            onClicked: entry.open = !entry.open
                        }
                    }
                    Hint {
                        Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                        text: entry.item.features
                              + (entry.row.path ? "\n" + entry.row.path + (page.viaWords[entry.row.via] ? " (" + page.viaWords[entry.row.via] + ")" : "") : "")
                    }
                    RowLayout {
                        Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                        Layout.fillWidth: true
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 30
                        visible: entry.open && entry.isCommand
                        QQC2.Label { textFormat: Text.PlainText; text: Lang.i18n("Command path:") }
                        QQC2.TextField {
                            id: pathField
                            objectName: "path-" + entry.modelData
                            Layout.fillWidth: true
                            placeholderText: Lang.i18n("Found by itself; or a full path, e.g. ~/Applications/%1", (entry.item.commands || [""])[0])
                            text: String(page.given[entry.modelData] || "")
                            Accessible.name: Lang.i18n("Command path of %1", entry.item.name)
                            onEditingFinished: if (text.trim() !== String(page.given[entry.modelData] || "")) { page.setGiven(entry.modelData, text); page.look(); }
                        }
                    }
                    Hint {
                        Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                        visible: entry.open && String(entry.row.given || "").length > 0 && !entry.row.givenUsable
                        color: Kirigami.Theme.negativeTextColor
                        opacity: 1
                        text: Lang.i18n("There is no program at the path given; it is looked for elsewhere as usual.")
                    }
                    RequirementNotice {
                        Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                        visible: entry.open && entry.row.state !== "found"
                        requirement: entry.modelData
                        offerPath: false
                        onRecheck: page.look()
                    }
                    }
                }
            }
        }

        // A few lines to the author, sent only with its button (FeedbackForm.qml).
        FeedbackForm {
            id: feedback
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            reportText: () => page.reportText()
            meta: ({ island: page.islandVersion, language: Lang.language, session: String(page.info.session || "") })
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            twinFormLayouts: [form]
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: Lang.i18n("Where commands are looked for") }
            QQC2.Label {
                textFormat: Text.PlainText
                Kirigami.FormData.label: Lang.i18n("Folders:")
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.WrapAnywhere
                font: Kirigami.Theme.smallFont
                text: page.searched.length > 0 ? Diagnostics.redact(page.searched.join("\n"), page.who) : Lang.i18n("unknown")
            }
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: Lang.i18n("About") }
            RowLayout {
                Kirigami.FormData.label: Lang.i18n("The island:")
                QQC2.Button { icon.name: "internet-services"; text: Lang.i18n("GitHub page"); onClicked: Qt.openUrlExternally(RequirementCatalog.repoUrl) }
                QQC2.Button { icon.name: "tools-report-bug"; text: Lang.i18n("Report a problem"); onClicked: Qt.openUrlExternally(RequirementCatalog.issuesUrl) }
            }
            RowLayout {
                Kirigami.FormData.label: Lang.i18n("First opening:")
                QQC2.Button {
                    id: tourButton
                    objectName: "tourAgain"
                    icon.name: "help-hint"
                    text: tourAsked ? Lang.i18n("Shown at the island's next opening") : Lang.i18n("Show the tour again")
                    enabled: !tourAsked
                    property bool tourAsked: false
                    // (written at once, not with Apply: like the statistics of Tools, it is the island's own state)
                    onClicked: { const c = page.widget(); if (c) { c.tourShown = false; tourAsked = true; } }
                }
            }
        }
    }
}
