/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The island's own updates (not the system's: that is UpdatesProvider).

    Once after the shell has started and once a day it reads the version in the
    repository's metadata.json (one request to raw.githubusercontent.com; nothing
    is sent but the request itself). A newer one is asked about on the island:
    "Update" runs contents/scripts/island-update.sh, which fetches that version,
    builds and installs it and restarts the shell; the island shows how far it
    is while it runs. Settings and data are not touched by an update.

      mode 0  never looks (no request at all)
      mode 1  asks before it installs anything
      mode 2  installs by itself, then asks only whether the shell may restart

    Installing needs the native module (it starts the script). Without it the
    island only says that there is a newer version, and how to get it.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    property var core: null                 // NativeBridge
    property int mode: 1
    // The version that runs, and the one that ran before (""= not known): a change is said once.
    property string current: ""
    property string previous: ""
    signal versionSeen(string version)
    // "version|when (ms)": the last version asked about, so that a restart of the shell does not ask again.
    property string asked: ""
    signal askedAbout(string mark)

    property string source: "https://raw.githubusercontent.com/Phobby/plasma-island/main/org.phobby.dynamicisland/metadata.json"
    property string script: decodeURIComponent(String(Qt.resolvedUrl("../../scripts/island-update.sh")).replace(/^file:\/\//, ""))
    property int firstCheckAfter: 60 * 1000
    property int checkEvery: 24 * 3600 * 1000
    property var now: () => Date.now()
    // done(status, text)
    property var request: (url, done) => {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => { if (xhr.readyState === XMLHttpRequest.DONE) done(xhr.status, xhr.responseText || ""); };
        xhr.open("GET", url);
        xhr.send();
    }

    property string latest: ""              // the repository's version, once it was read
    property string step: ""                // "" | download | unpack | build | install | restart
    property real built: -1                 // 0..1 while the native module builds
    readonly property bool running: stream !== null && stream.running
    readonly property bool canInstall: core !== null && typeof core.newStream === "function"
    property var stream: null

    function valid(version: string): bool { return /^\d+(\.\d+){0,3}$/.test(version); }
    // a is newer than b
    function newer(a: string, b: string): bool {
        if (!valid(a) || !valid(b)) return false;
        const x = a.split(".").map(Number), y = b.split(".").map(Number);
        for (let i = 0; i < Math.max(x.length, y.length); ++i) {
            const d = (x[i] || 0) - (y[i] || 0);
            if (d !== 0) return d > 0;
        }
        return false;
    }

    function check(): void {
        if (mode === 0 || running) return;
        request(source, (status, text) => {
            if (status !== 200) return;
            let version = "";
            try { version = String(JSON.parse(text).KPlugin.Version || ""); } catch (e) { return; }
            if (!valid(version)) return;
            latest = version;
            if (!newer(version, current) || running) return;
            const mark = asked.split("|");
            if (mark[0] === version && now() - Number(mark[1] || 0) < checkEvery - 60000) return;
            askedAbout(version + "|" + now());
            if (mode === 2 && canInstall) install(version, false); else offer(version);
        });
    }
    function offer(version: string): void {
        if (!canInstall) {
            manager.flash({
                key: "island-update", icon: "system-software-update-symbolic", color: theme.live,
                title: Lang.i18n("Dynamic Island %1 is available.", version),
                subtitle: Lang.i18n("In its folder: git pull, then ./install.sh"),
                width: theme.notificationWidth, duration: 9000
            });
            return;
        }
        manager.flash({
            key: "island-update", icon: "system-software-update-symbolic", color: theme.live,
            title: Lang.i18n("Dynamic Island %1 is available.", version),
            subtitle: Lang.i18n("You have %1. Your settings stay; the desktop shell restarts at the end.", current),
            width: theme.notificationWidth, height: theme.questionHeight, duration: 45000,
            buttons: [
                { text: Lang.i18n("Update"), primary: true, trigger: () => provider.install(version, true) },
                { text: Lang.i18n("Later"), trigger: () => {} }
            ]
        });
    }
    function restartShell(): void {
        if (core !== null) core.startDetached("sh", [script, "--restart-only"]);
    }
    // Fetches, builds and installs `version`; restart: the shell is restarted at the end without another question.
    function install(version: string, restart: bool): bool {
        if (!canInstall || running || !valid(version)) return false;
        if (stream === null) {
            stream = core.newStream(provider);
            if (stream === null) return false;
            stream.lines.connect(read);
            stream.finished.connect(ended);
        }
        step = "download"; built = -1; failure = ""; installed = "";
        wantsRestart = restart;
        const home = core.local && typeof core.local.environment === "function" ? core.local.environment("HOME") : "";
        if (!stream.start("sh", [script, version].concat(restart ? ["--restart"] : []), "", (home || "/tmp") + "/.cache/dynamicisland/update")) { step = ""; return false; }
        return true;
    }
    property bool wantsRestart: false
    property string failure: ""
    property string installed: ""
    function read(lines: var): void {
        for (const line of lines) {
            const m = /^(STEP|PROGRESS|DONE|ERROR) (.*)$/.exec(line);
            if (!m) continue;
            if (m[1] === "STEP") step = m[2];
            else if (m[1] === "PROGRESS") built = Math.max(0, Math.min(100, Number(m[2]) || 0)) / 100;
            else if (m[1] === "DONE") installed = m[2];
            else failure = m[2];
        }
    }
    function ended(code: int, errors: string): void {
        step = ""; built = -1;
        if (installed.length > 0) {
            if (wantsRestart) return;       // (the shell is on its way down)
            manager.flash({
                key: "island-update", icon: "system-software-update-symbolic", color: theme.live, feel: "done",
                title: Lang.i18n("Dynamic Island %1 is installed.", installed),
                subtitle: Lang.i18n("It is used from the next start of the desktop shell."),
                width: theme.notificationWidth, height: theme.questionHeight, duration: 45000,
                buttons: [
                    { text: Lang.i18n("Restart now"), primary: true, trigger: () => provider.restartShell() },
                    { text: Lang.i18n("Later"), trigger: () => {} }
                ]
            });
            return;
        }
        manager.flash({
            key: "island-update", icon: "dialog-warning-symbolic", color: theme.warning,
            title: Lang.i18n("The update did not work"),
            subtitle: failure.length > 0 ? failure : Lang.i18n("The updater stopped (code %1).", code),
            width: theme.notificationWidth, duration: 9000
        });
    }

    readonly property string stepText: step === "download" ? Lang.i18n("Downloading…") : step === "unpack" ? Lang.i18n("Unpacking…")
        : step === "build" ? Lang.i18n("Building…") : step === "install" ? Lang.i18n("Installing…")
        : step === "restart" ? Lang.i18n("Restarting the shell…") : ""

    readonly property alias activity: updating
    Activity {
        id: updating
        activityId: "island-update"
        category: "transfer"
        priority: 5
        active: provider.step.length > 0
        icon: "system-software-update-symbolic"
        color: provider.theme.live
        title: Lang.i18n("Updating the island")
        compactWidth: Math.round(provider.theme.gu * 15)
        subtitle: provider.stepText
        // the build is most of the time and says how far it is; around it the ring only turns
        progress: provider.step === "build" && provider.built >= 0 ? provider.built : -2
        trailingText: provider.step === "build" && provider.built >= 0 ? Lang.percent(Math.round(provider.built * 100)) : ""
        Component.onCompleted: provider.manager.register(this)
    }

    Timer { interval: provider.firstCheckAfter; running: provider.mode !== 0; onTriggered: provider.check() }
    Timer { interval: provider.checkEvery; repeat: true; running: provider.mode !== 0; onTriggered: provider.check() }

    // A new version runs for the first time: said once (after the island's first seconds,
    // in which the manager takes no events).
    property int greetAfter: 6000
    Timer {
        interval: provider.greetAfter
        running: provider.current.length > 0
        onTriggered: {
            if (provider.previous.length > 0 && provider.newer(provider.current, provider.previous))
                provider.manager.flash({ key: "island-update", icon: "system-software-update-symbolic", color: provider.theme.live, feel: "done",
                                         title: Lang.i18n("Dynamic Island was updated"), subtitle: Lang.i18n("Version %1", provider.current),
                                         width: provider.theme.notificationWidth, duration: 6000 });
            if (provider.previous !== provider.current) provider.versionSeen(provider.current);
        }
    }
}
