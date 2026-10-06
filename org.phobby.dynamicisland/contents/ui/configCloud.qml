/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Cloud: whether the tab is shown (off until switched on) and its indicator
    on the small island; the clouds rclone knows, each shown or hidden and
    with a name of one's own; the storage thresholds, the alerts and their
    pause; the question before an upload, up to which size a file is fetched
    when the pointer rests on it, the cache's limit, its size now and "Clear
    cache"; where each cloud's sync state comes from, or why it is not known;
    and how a cloud is added with rclone.

    The clouds are asked of the `rclone` command when this page opens (its
    configuration file is not read); nothing is asked of a cloud from here.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "cloud/Rclone.js" as Rclone

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property alias cfg_showCloud: enableCheck.checked
    property alias cfg_cloudIndicator: indicatorCheck.checked
    property alias cfg_cloudAlerts: alertsCheck.checked
    property alias cfg_cloudWarnPercent: warnSpin.value
    property alias cfg_cloudCriticalPercent: criticalSpin.value
    property alias cfg_cloudAlertPauseHours: pauseSpin.value
    property alias cfg_cloudConfirmUpload: confirmCheck.checked
    property alias cfg_cloudAutoFetchMB: fetchSpin.value
    property alias cfg_cloudCacheMB: cacheSpin.value
    property string cfg_cloudHidden: "[]"
    property string cfg_cloudAliases: "{}"

    function parsed(json: string, fallback: var): var {
        try { const v = JSON.parse(json); return v !== null && typeof v === "object" ? v : fallback; } catch (e) { return fallback; }
    }
    readonly property var hidden: { const l = parsed(cfg_cloudHidden, []); return Array.isArray(l) ? l : []; }
    readonly property var aliases: parsed(cfg_cloudAliases, ({}))
    function setHidden(name: string, hide: bool): void {
        const list = hidden.filter(n => n !== name);
        if (hide) list.push(name);
        cfg_cloudHidden = JSON.stringify(list);
    }
    function setAlias(name: string, alias: string): void {
        const all = Object.assign({}, aliases);
        if (alias.trim().length > 0 && alias.trim() !== name) all[name] = alias.trim().slice(0, 40); else delete all[name];
        cfg_cloudAliases = JSON.stringify(all);
    }

    // What is on this computer: asked once when the page opens.
    Loader { id: tools; source: "LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    property string commandName: "rclone"
    property var extra: []
    property bool looked: false
    property string command: ""
    property var remotes: []
    property var clients: ({ dropbox: false, syncthing: false })
    readonly property string cacheFolder: local ? local.dataHome().replace(/\/\.local\/share$/, "") + "/.cache/dynamicisland/cloud" : ""
    property real cacheBytes: -1
    function look(): void {
        if (local === null) { looked = true; return; }
        command = local.findExecutable(commandName);
        clients = { dropbox: local.findExecutable("dropbox").length > 0, syncthing: local.findExecutable("syncthing").length > 0 };
        measureCache();
        if (command.length === 0) { remotes = []; looked = true; return; }
        local.run(command, extra.concat(Rclone.remotesArguments()), (code, out) => { remotes = code === 0 ? Rclone.parseRemotes(out) : []; looked = true; });
    }
    function measureCache(): void {
        if (local === null) return;
        local.run("find", [cacheFolder, "-type", "f", "-printf", "%s\t%p\n"], (code, out) => {
            cacheFiles = code === 0 ? out.split("\n").map(l => l.split("\t")).filter(f => f.length === 2) : [];
            cacheBytes = cacheFiles.reduce((n, f) => n + Number(f[0]), 0);
        });
    }
    property var cacheFiles: []
    function clearCache(): void {
        for (const f of cacheFiles) if (f[1].indexOf(cacheFolder + "/") === 0) local.removeFile(f[1]);
        measureCache();
    }
    function size(bytes: real): string {
        if (!(bytes >= 0)) return "";
        const units = ["B", "kB", "MB", "GB"];
        let n = bytes, u = 0;
        while (n >= 1000 && u < units.length - 1) { n /= 1000; ++u; }
        return (u === 0 ? Math.round(n) : n.toFixed(1)) + " " + units[u];
    }
    // Where a cloud's sync state comes from; "" = from nowhere.
    function syncSource(remote: var): string { return remote.type === "dropbox" && clients.dropbox ? "Dropbox" : ""; }
    onLocalChanged: if (local !== null && !looked) look()

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.CheckBox {
                id: enableCheck
                Kirigami.FormData.label: Lang.i18n("Cloud:")
                text: Lang.i18n("Show the Cloud page in the island")
            }
            QQC2.CheckBox {
                id: indicatorCheck
                Kirigami.FormData.label: Lang.i18n("On the island:")
                enabled: enableCheck.checked
                text: Lang.i18n("Show a cloud while something is syncing, and “Synced” when it is done")
            }
            QQC2.CheckBox {
                id: alertsCheck
                Kirigami.FormData.label: Lang.i18n("Alerts:")
                enabled: enableCheck.checked
                text: Lang.i18n("Storage nearly full, sign-in run out, cloud unreachable, sync error")
            }
            RowLayout {
                Kirigami.FormData.label: Lang.i18n("Storage:")
                enabled: enableCheck.checked && alertsCheck.checked
                QQC2.Label { textFormat: Text.PlainText; text: Lang.i18n("nearly full from") }
                QQC2.SpinBox { id: warnSpin; from: 50; to: 100; textFromValue: value => Lang.percent(value); valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 90 }
                QQC2.Label { textFormat: Text.PlainText; text: Lang.i18n("full from") }
                QQC2.SpinBox { id: criticalSpin; from: 50; to: 100; textFromValue: value => Lang.percent(value); valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 98 }
            }
            QQC2.SpinBox {
                id: pauseSpin
                Kirigami.FormData.label: Lang.i18n("The same alert again:")
                enabled: enableCheck.checked && alertsCheck.checked
                from: 1
                to: 168
                textFromValue: value => Lang.i18np("after %1 hour", "after %1 hours", value)
                valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 6
            }
            QQC2.CheckBox {
                id: confirmCheck
                Kirigami.FormData.label: Lang.i18n("Uploading:")
                enabled: enableCheck.checked
                text: Lang.i18n("Ask before every upload")
            }
            QQC2.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("Off: dropped files are copied at once. A file that is there already and a very large upload are always asked about. Nothing is ever deleted, moved or renamed from the island.")
            }
            QQC2.SpinBox {
                id: fetchSpin
                Kirigami.FormData.label: Lang.i18n("Fetch for dragging:")
                enabled: enableCheck.checked
                from: 0
                to: 1000
                stepSize: 5
                textFromValue: value => value === 0 ? Lang.i18n("only when asked") : Lang.i18n("files up to %1 MB by themselves", value)
                valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 0
            }
            RowLayout {
                Kirigami.FormData.label: Lang.i18n("Cache:")
                enabled: enableCheck.checked
                QQC2.SpinBox {
                    id: cacheSpin
                    from: 50
                    to: 20000
                    stepSize: 50
                    textFromValue: value => Lang.i18n("at most %1 MB", value)
                    valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 500
                }
                QQC2.Label { textFormat: Text.PlainText; objectName: "cacheSize"; text: page.cacheBytes >= 0 ? Lang.i18n("now %1", page.size(page.cacheBytes)) : ""; opacity: 0.7 }
                QQC2.Button { objectName: "clearCache"; icon.name: "edit-clear"; text: Lang.i18n("Clear cache"); enabled: page.cacheBytes > 0; onClicked: page.clearCache() }
            }
            QQC2.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("A file has to be on this computer before it can be dragged out. It is fetched to ~/.cache/dynamicisland/cloud; the oldest files go when the limit is reached.")
            }
        }

        Kirigami.Heading { textFormat: Text.PlainText; level: 4; text: Lang.i18n("Clouds") }
        QQC2.Label {
            textFormat: Text.PlainText
            objectName: "cloudsNote"
            Layout.fillWidth: true
            visible: page.looked && page.remotes.length === 0
            wrapMode: Text.Wrap
            opacity: 0.7
            text: page.local === null ? Lang.i18n("The island's native helper is not installed: the clouds cannot be asked for.")
                : page.command.length === 0 ? Lang.i18n("rclone was not found on this computer. See below for how to install it.")
                : Lang.i18n("rclone is installed but knows no cloud yet. See below for how to add one.")
        }
        Repeater {
            model: page.remotes
            delegate: ColumnLayout {
                id: row
                required property var modelData
                readonly property string source: page.syncSource(modelData)
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    QQC2.Switch {
                        checked: page.hidden.indexOf(row.modelData.name) < 0
                        onToggled: page.setHidden(row.modelData.name, !checked)
                    }
                    QQC2.Label { Layout.fillWidth: true; text: row.modelData.name + " (" + row.modelData.type + ")"; textFormat: Text.PlainText; elide: Text.ElideRight }
                    QQC2.Label { textFormat: Text.PlainText; text: Lang.i18n("Shown as:"); opacity: 0.7 }
                    QQC2.TextField {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        text: page.aliases[row.modelData.name] || ""
                        placeholderText: row.modelData.name
                        onEditingFinished: page.setAlias(row.modelData.name, text)
                    }
                }
                QQC2.Label {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.gridUnit * 3
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    text: row.source.length > 0 ? Lang.i18n("Sync state: from the %1 client on this computer.", row.source)
                        : Lang.i18n("Sync state: unknown. rclone copies when asked and keeps no sync state, and no sync client for this cloud was found on this computer.")
                }
            }
        }
        QQC2.Label {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            visible: page.clients.syncthing
            wrapMode: Text.Wrap
            opacity: 0.7
            text: Lang.i18n("Syncthing was found: it has a card of its own on the Cloud page, which asks for its API key once.")
        }

        Kirigami.Heading { textFormat: Text.PlainText; level: 4; text: Lang.i18n("Adding a cloud") }
        QQC2.Label {
            objectName: "howTo"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: Lang.i18n("The clouds are those of rclone. In your own terminal:\n1. Install it:  sudo -v ; curl https://rclone.org/install.sh | sudo bash\n2. Run:  rclone config   then  n  (new remote) and give it a name.\n3. Choose the kind of storage: drive (Google Drive), onedrive (Microsoft OneDrive), dropbox (Dropbox), or webdav for Nextcloud and other WebDAV servers (then its address, the vendor nextcloud, your user name and password).\n4. For Google Drive, OneDrive and Dropbox leave the questions at their defaults; rclone opens the browser to sign in.\n5. Come back: the cloud appears here and on the island's Cloud page.\nA sign-in that has run out is renewed with:  rclone config reconnect NAME:")
        }
    }
}
