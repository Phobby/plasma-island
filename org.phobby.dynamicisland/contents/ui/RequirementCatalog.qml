/*
    SPDX-License-Identifier: GPL-2.0-or-later

    What the island's features need beyond Plasma itself, and how to get it:
    one entry each, shown alike wherever something is missing (RequirementCard
    in the island, RequirementNotice in the settings, the Diagnostics page).

      id: { name, kind ("native", "command", "module", "service"),
            commands: the commands looked for (the first found counts),
            what:  "<name> was not found" (or is not installed),
            why:   one sentence: what it is needed for,
            link:  its own page (the project's, or the tool's official one),
            install: the command to copy, or a list of { distro, command },
            features: which of the island's parts use it,
            optional: true when a feature works without it, only less }

    Nothing here is run: the commands are for the user to copy into a
    terminal of their own. Every address of the island itself comes from
    Project.js.
*/
pragma Singleton
import QtQuick
import "Project.js" as Project

QtObject {
    id: catalog

    readonly property string repoUrl: Project.REPO_URL
    readonly property string installUrl: Project.INSTALL_URL
    readonly property string issuesUrl: Project.ISSUES_URL

    // What install.sh needs to build the native module, per distribution, then the install itself.
    readonly property var buildPackages: [
        { distro: "Kubuntu / Debian", command: "sudo apt install git build-essential cmake extra-cmake-modules qt6-base-dev qt6-declarative-dev libkf6windowsystem-dev" },
        { distro: "Fedora", command: "sudo dnf install git gcc-c++ cmake extra-cmake-modules qt6-qtbase-devel qt6-qtdeclarative-devel kf6-kwindowsystem-devel" },
        { distro: "Arch", command: "sudo pacman -S --needed git base-devel cmake extra-cmake-modules qt6-base qt6-declarative kwindowsystem" }
    ]
    readonly property string installCommand: Project.INSTALL_COMMAND

    readonly property var items: ({
        "native": {
            name: Lang.i18n("The island's native module"), kind: "native",
            what: Lang.i18n("The native module is not installed"),
            why: Lang.i18n("This feature needs the full installation: the island's native module runs commands, keeps keys in KDE Wallet and watches the system."),
            more: Lang.i18n("Install the island from its GitHub page with install.sh, which builds the native module. It needs these packages to build:"),
            link: Project.INSTALL_URL,
            install: catalog.buildPackages,
            then: Project.INSTALL_COMMAND,
            features: Lang.i18n("Claude Code, Antigravity and local models (AI), BetterNotes (Notes), the Cloud tab, screen recording, privacy indicators, calls, unlock, updates, the D-Bus API, theme files, the blur and clicks passing beside the island")
        },
        "claude": {
            name: "Claude Code", kind: "command", commands: ["claude"],
            what: Lang.i18n("Claude Code was not found"),
            why: Lang.i18n("The AI tab asks Claude Code on this computer through its claude command."),
            link: "https://docs.anthropic.com/en/docs/claude-code/setup",
            install: "curl -fsSL https://claude.ai/install.sh | bash",
            features: Lang.i18n("AI tab: Claude Code")
        },
        "agy": {
            name: "Antigravity", kind: "command", commands: ["agy"], optional: true,
            what: Lang.i18n("Antigravity was not found"),
            why: Lang.i18n("The AI tab asks Antigravity on this computer through its agy command."),
            link: "https://antigravity.google",
            install: "",
            features: Lang.i18n("AI tab: Antigravity")
        },
        "ollama": {
            name: "Ollama", kind: "command", commands: ["ollama"], optional: true,
            what: Lang.i18n("Ollama was not found"),
            why: Lang.i18n("The AI tab can use models that run on this computer through Ollama: no account, and nothing leaves the device."),
            link: "https://ollama.com/download/linux",
            install: "curl -fsSL https://ollama.com/install.sh | sh",
            features: Lang.i18n("AI tab: a local model")
        },
        "betternotes": {
            name: "BetterNotes", kind: "command", commands: ["betternotes"],
            what: Lang.i18n("BetterNotes was not found"),
            why: Lang.i18n("The notes list is read with BetterNotes' command-line tool."),
            link: "https://github.com/thebanri/BetterNotes",
            install: "curl -fsSL https://raw.githubusercontent.com/thebanri/BetterNotes/main/install.sh | sh",
            features: Lang.i18n("Notes tab: BetterNotes")
        },
        "rclone": {
            name: "rclone", kind: "command", commands: ["rclone"],
            what: Lang.i18n("rclone was not found"),
            why: Lang.i18n("The Cloud tab reaches Google Drive, OneDrive, Dropbox, Nextcloud and others through rclone."),
            link: "https://rclone.org/install/",
            install: [{ distro: "Kubuntu / Debian", command: "sudo apt install rclone" }, { distro: "Fedora", command: "sudo dnf install rclone" },
                      { distro: "Arch", command: "sudo pacman -S rclone" }, { distro: Lang.i18n("Newest"), command: "sudo -v ; curl https://rclone.org/install.sh | sudo bash" }],
            features: Lang.i18n("Cloud tab")
        },
        "syncthing": {
            name: "Syncthing", kind: "command", commands: ["syncthing"], optional: true,
            what: Lang.i18n("Syncthing was not found"),
            why: Lang.i18n("The Cloud tab shows how Syncthing's folders are syncing, when Syncthing runs on this computer."),
            link: "https://syncthing.net/downloads/",
            install: [{ distro: "Kubuntu / Debian", command: "sudo apt install syncthing" }, { distro: "Fedora", command: "sudo dnf install syncthing" },
                      { distro: "Arch", command: "sudo pacman -S syncthing" }],
            features: Lang.i18n("Cloud tab: Syncthing's state")
        },
        "dropbox": {
            name: "Dropbox", kind: "command", commands: ["dropbox"], optional: true,
            what: Lang.i18n("Dropbox was not found"),
            why: Lang.i18n("The Cloud tab shows whether Dropbox's own client has synced, when it is installed."),
            link: "https://www.dropbox.com/install-linux",
            install: "",
            features: Lang.i18n("Cloud tab: Dropbox's sync state")
        },
        "pipewire": {
            name: Lang.i18n("PipeWire's tools"), kind: "command", commands: ["pw-dump"],
            what: Lang.i18n("pw-dump was not found"),
            why: Lang.i18n("Which program uses the microphone or the camera, and a screen recording, are read from PipeWire with pw-dump."),
            link: "https://pipewire.org",
            install: [{ distro: "Kubuntu / Debian", command: "sudo apt install pipewire-bin" }, { distro: "Fedora", command: "sudo dnf install pipewire-utils" },
                      { distro: "Arch", command: "sudo pacman -S pipewire" }],
            features: Lang.i18n("Privacy indicators, screen recording")
        },
        "pwrecord": {
            name: "pw-record", kind: "command", commands: ["pw-record"], optional: true,
            what: Lang.i18n("pw-record was not found"),
            why: Lang.i18n("The ambient glow follows the music's beat by listening to what plays, with pw-record."),
            link: "https://pipewire.org",
            install: [{ distro: "Kubuntu / Debian", command: "sudo apt install pipewire-bin" }, { distro: "Fedora", command: "sudo dnf install pipewire-utils" },
                      { distro: "Arch", command: "sudo pacman -S pipewire" }],
            features: Lang.i18n("Ambient glow: following the music")
        },
        "btop": {
            name: "btop", kind: "command", commands: ["btop"], optional: true,
            what: Lang.i18n("btop was not found"),
            why: Lang.i18n("A click on a card of the System page opens btop in a terminal with that measurement."),
            link: "https://github.com/aristocratos/btop",
            install: [{ distro: "Kubuntu / Debian", command: "sudo apt install btop" }, { distro: "Fedora", command: "sudo dnf install btop" },
                      { distro: "Arch", command: "sudo pacman -S btop" }],
            features: Lang.i18n("System page: details in btop")
        },
        "kdeconnect": {
            name: "KDE Connect", kind: "module", commands: ["kdeconnect-app"], optional: true,
            what: Lang.i18n("KDE Connect is not installed"),
            why: Lang.i18n("A paired phone's calls, battery and \"find my phone\" come through KDE Connect."),
            link: "https://kdeconnect.kde.org",
            install: [{ distro: "Kubuntu / Debian", command: "sudo apt install kdeconnect" }, { distro: "Fedora", command: "sudo dnf install kde-connect" },
                      { distro: "Arch", command: "sudo pacman -S kdeconnect" }],
            features: Lang.i18n("Calls, the phone's battery, find my phone")
        },
        "multimedia": {
            name: "Qt Multimedia", kind: "module", optional: true,
            what: Lang.i18n("Qt Multimedia is not installed"),
            why: Lang.i18n("The timer's, the alarm's and the calendar's sounds are played with Qt Multimedia."),
            link: "https://doc.qt.io/qt-6/qtmultimedia-index.html",
            install: [{ distro: "Kubuntu / Debian", command: "sudo apt install qml6-module-qtmultimedia" }, { distro: "Fedora", command: "sudo dnf install qt6-qtmultimedia" },
                      { distro: "Arch", command: "sudo pacman -S qt6-multimedia" }],
            features: Lang.i18n("Sounds of the timer, the alarm and the calendar")
        },
        "layershell": {
            name: "LayerShellQt", kind: "module", optional: true,
            what: Lang.i18n("LayerShellQt is not installed"),
            why: Lang.i18n("The notch stays over a top panel, and the island peeks over full-screen windows, from a window of KDE's layer-shell."),
            link: "https://invent.kde.org/plasma/layer-shell-qt",
            install: [{ distro: "Kubuntu / Debian", command: "sudo apt install layer-shell-qt" }, { distro: "Fedora", command: "sudo dnf install layer-shell-qt" },
                      { distro: "Arch", command: "sudo pacman -S layer-shell-qt" }],
            features: Lang.i18n("The notch over a top panel, peeking over full screen (Wayland)")
        },
        "kwallet": {
            name: Lang.i18n("KDE Wallet"), kind: "service", optional: true,
            what: Lang.i18n("KDE Wallet does not answer"),
            why: Lang.i18n("Keys, passwords and sign-ins (AI services, calendars, notes, Syncthing) are kept in KDE Wallet; without it they last only until the shell restarts."),
            link: "https://apps.kde.org/kwalletmanager5/",
            install: [{ distro: "Kubuntu / Debian", command: "sudo apt install kwalletmanager" }, { distro: "Fedora", command: "sudo dnf install kwalletmanager5" },
                      { distro: "Arch", command: "sudo pacman -S kwalletmanager" }],
            features: Lang.i18n("Kept keys and sign-ins")
        }
    })
    // In the order the Diagnostics page lists them.
    readonly property var order: ["native", "claude", "agy", "ollama", "betternotes", "rclone", "syncthing", "dropbox", "pipewire", "pwrecord",
                                  "btop", "kdeconnect", "multimedia", "layershell", "kwallet"]
    function item(id: string): var { return items[id] || null; }
    // The install commands as a list of { distro, command } (one entry without a distro for a single command).
    function installs(id: string): var {
        const it = item(id);
        if (it === null) return [];
        if (Array.isArray(it.install)) return it.install;
        return it.install ? [{ distro: "", command: it.install }] : [];
    }
}
