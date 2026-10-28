/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Window strategy
    ---------------
    Desktop widgets live below normal windows and panels only get the theme's
    blur, so the island is rendered in its own frameless PlasmaCore.Dialog:
      * type Notification + WindowDoesNotAcceptFocus → stays above windows,
        never steals focus;
      * NoBackground → we paint the glass ourselves (IslandShape);
      * positioned with x/y. On Wayland plasmashell may do that through the
        plasma-shell protocol, exactly like the notification popups do.
    The window only has two sizes (small pill / large card) and switches
    between them outside of the animation, so the morph itself never resizes
    the window. The plasmoid's own representation is just a small handle.

    Real blur: KWin blurs a window only inside the region the window asks
    for. Plasma's Dialog derives that region from the theme frame, so for a
    pill-shaped region we use the optional native helper (see native/).
    Without it, the surface falls back to a near-opaque metal finish.
*/
import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "providers"
import "backend"
import "companion"
import "SettingsMigration.js" as Migration
import "Fullscreen.js" as Fullscreen

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    // The widget's language (Settings → Language), for every text of the island.
    Binding { target: Lang; property: "setting"; value: root.cfg.language }
    Binding { target: Lang; property: "clockSetting"; value: root.cfg.clockFormat }

    Plasmoid.icon: "view-media-track"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: Lang.i18n("Dynamic Island")
    toolTipSubText: !root.leads ? Lang.i18n("Another Dynamic Island is already on this screen, so this one stays hidden. Remove one of the two.")
                    : backend.hasMedia ? backend.track : ""
    // (a title is whatever a player or a web page says it is)
    toolTipTextFormat: Text.PlainText

    // The handle on the desktop: seen only while the desktop is edited (to move or remove the widget).
    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: mouse.containsMouse
            visible: !!Plasmoid.containment && !!Plasmoid.containment.corona && Plasmoid.containment.corona.editMode
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: island.expanded = !island.expanded
            }
        }
    }
    fullRepresentation: Item {}

    // Settings → Appearance. While that page is open, what it is editing shows at
    // once: the settings window runs in a QML engine of its own, so the page hands
    // its working values over through the configuration (preview*); what is kept
    // is only written on Apply.
    readonly property bool previewing: root.cfg.previewActive
    Theme {
        id: theme
        follow: (root.previewing ? root.cfg.previewMode : root.cfg.appearanceMode) === 0
        style: root.previewing ? Styles.parse(root.cfg.previewStyle, null) : root.storedStyle
        systemSource: root.previewing ? root.cfg.previewSource : root.cfg.followSource
        systemScheme: colorSchemes.colors
        systemTop: root.previewing ? root.cfg.previewTop : root.cfg.topMargin
        systemOffsetX: Math.max(-100, Math.min(100, root.previewing ? root.cfg.previewOffsetX : root.cfg.horizontalOffset))
        systemStyle: Styles.parseFollow(root.previewing ? root.cfg.previewFollowStyle : root.cfg.followStyle)
        blurActive: blur.active
        notch: root.notchWanted
        notchBlack: root.cfg.notchColor === 0
        notchLook: root.cfg.notchColor === 2
        notchEars: root.cfg.notchEars
        notchBorderEnabled: root.cfg.notchBorderEnabled
        notchBorderWidth: root.cfg.notchBorderWidth
        notchBorderColor: root.cfg.notchBorderColor
        notchBorderOpacity: root.cfg.notchBorderOpacity
        notchPixels: root.notchPixels
        // (the notch over a window that fills the screen: shrunk to a nub, or, come down and open there, a size of its
        // own for that if set; drawn up to the edge it keeps the size it has)
        drawnIn: peek.shrunk
        scaleOverride: peek.shrunk ? 0.5 : root.notchWanted && peek.shown && root.cfg.notchDodgeSize > 0 ? root.cfg.notchDodgeSize / 100 : 0
        // (the size is kept within the screen the island is on)
        screenWidth: root.notchWanted ? root.notchScreen.width : root.screenRect.width
        screenHeight: root.notchWanted ? root.notchScreen.height : root.screenRect.height
    }
    // For the settings page: the largest size the screen has room for, percent (0 = all of the range).
    readonly property int scaleLimitSeen: theme.scaleLimit * 100 >= Styles.scaleMax ? 0 : Math.floor(theme.scaleLimit * 100)
    onScaleLimitSeenChanged: if (root.cfg.scaleLimitSeen !== scaleLimitSeen) root.cfg.scaleLimitSeen = scaleLimitSeen
    // No settings window can be open when the shell starts: a preview left behind
    // (the shell was stopped while one was open) ends here.
    Component.onCompleted: {
        if (root.cfg.previewActive) root.cfg.previewActive = false;
        if (root.cfg.scaleLimitSeen !== root.scaleLimitSeen) root.cfg.scaleLimitSeen = root.scaleLimitSeen;
        Islands.join(root);
        Requirements.openSettings = root.openSettingsAt;
    }
    Component.onDestruction: Islands.leave(root)
    // The custom style as stored; before one was ever stored, the look of the
    // earlier settings (opacity, blur, distance from top, light metal).
    readonly property var storedStyle: Styles.parse(root.cfg.customStyle, {
        opacity: root.cfg.surfaceOpacity, blur: root.cfg.blurEnabled, top: root.cfg.topMargin, light: root.cfg.themeMode === 2 })

    PlasmaBackend {
        id: backend
        preferredPlayer: root.cfg.preferredPlayer
    }

    // ---- activities -----------------------------------------------------------
    ActivityManager {
        id: activities
        order: String(root.cfg.priorityOrder).split(",").map(s => s.trim()).filter(s => s.length > 0)
        splitEnabled: root.cfg.splitIsland
        keepMediaVisible: root.cfg.keepMediaVisible
        eventDuration: root.cfg.eventDuration
        notificationDuration: root.cfg.notificationDuration
    }

    // ---- backends -------------------------------------------------------------------
    // Private-API backends (see PlasmaBackend.qml / backend/). Each one is loaded
    // through a Loader: if its Plasma/KDE module is missing on this system only
    // that feature disappears (e.g. no KDE Connect, no bluez-qt, no plasma-nm).
    component OptionalBackend: Loader {
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: optional backend unavailable:", source)
    }
    OptionalBackend { id: powerLoader; source: "backend/PowerBackend.qml" }
    OptionalBackend { id: bluetoothLoader; source: "backend/BluetoothBackend.qml" }
    OptionalBackend { id: displayLoader; source: "backend/DisplayBackend.qml" }
    OptionalBackend { id: keyboardLoader; source: "backend/KeyboardBackend.qml" }
    OptionalBackend { id: networkLoader; source: "backend/NetworkBackend.qml" }
    OptionalBackend { id: dndLoader; source: "backend/DndBackend.qml" }
    OptionalBackend { id: tasksLoader; source: "backend/TasksBackend.qml" }
    OptionalBackend { id: jobsLoader; source: "backend/JobsBackend.qml" }
    // Weather: Open-Meteo, for the place chosen on the Weather page (nothing is asked before one is).
    OptionalBackend { id: weatherLoader; source: root.cfg.showWeather ? "backend/WeatherBackend.qml" : "" }
    Binding { target: root.weatherBackend; property: "location"; value: root.cfg.weatherLocation; when: root.weatherBackend !== null }
    Binding { target: root.weatherBackend; property: "imperial"; value: root.cfg.weatherUnits === 1; when: root.weatherBackend !== null }
    // The application list: Plasma's own data engine (plasma-workspace).
    OptionalBackend { id: appsLoader; source: root.cfg.showApps ? "backend/AppsBackend.qml" : "" }
    // Calendar: .ics links (no Akonadi).
    OptionalBackend { id: calendarLoader; source: root.cfg.showCalendar ? "backend/IcsCalendarBackend.qml" : "" }
    Binding { target: root.calendarBackend; property: "sourcesJson"; value: root.cfg.calendarSources; when: root.calendarBackend !== null }
    Binding { target: root.calendarBackend; property: "client"; value: calendarClient; when: root.calendarBackend !== null }
    Binding { target: root.calendarBackend; property: "google"; value: googleCalendar; when: root.calendarBackend !== null }
    Binding { target: root.calendarBackend; property: "refreshMinutes"; value: root.cfg.calendarRefreshMinutes; when: root.calendarBackend !== null }
    Connections {
        target: root.calendarBackend
        function onStatusJsonChanged() { root.cfg.calendarStatus = root.calendarBackend.statusJson; }
    }
    // Adding events needs the account itself (CalDAV); the links above are read-only.
    CalDavClient {
        id: calendarClient
        core: root.core
        accountJson: root.cfg.calendarAccount
        onAccountJsonChanged: if (root.cfg.calendarAccount !== accountJson) root.cfg.calendarAccount = accountJson
    }
    GoogleCalendar {
        id: googleCalendar
        core: root.core
        clientId: root.cfg.googleClientId
        clientSecret: root.cfg.googleClientSecret
        accountJson: root.cfg.googleAccount
        onAccountJsonChanged: if (root.cfg.googleAccount !== accountJson) root.cfg.googleAccount = accountJson
    }
    // Notes apps (Joplin, Simplenote, Memos); only a page, never a live activity.
    NotesBackend {
        id: notesBackend
        core: root.core
        enabled: root.cfg.showNotes
        sourcesJson: root.cfg.notesSources
        defaultId: root.cfg.notesDefault
        refreshMinutes: root.cfg.notesRefreshMinutes
        onSourcesJsonChanged: if (root.cfg.notesSources !== sourcesJson) root.cfg.notesSources = sourcesJson
    }
    // Changes made in the settings dialog reach the backend too.
    Connections {
        target: root.cfg
        function onNotesSourcesChanged() { if (notesBackend.sourcesJson !== root.cfg.notesSources) notesBackend.sourcesJson = root.cfg.notesSources; }
    }
    // The AI tab: quick questions to Claude Code on this computer, a local model or a service
    // with a key. Only a page, and loaded by name only when it is switched on: while it is off
    // nothing of it is read, and while no question is being answered nothing of it runs.
    OptionalBackend {
        id: aiLoader
        source: root.cfg.showAi ? "backend/AiBackend.qml" : ""
        onLoaded: {
            item.core = Qt.binding(() => root.core);
            item.enabled = Qt.binding(() => root.cfg.showAi);
            item.defaultId = Qt.binding(() => root.cfg.aiDefault);
            item.maxTokens = Qt.binding(() => root.cfg.aiMaxTokens);
            item.maxChars = Qt.binding(() => root.cfg.aiMaxChars);
            item.keepHistory = Qt.binding(() => root.cfg.aiKeepHistory);
            item.sourcesJson = root.cfg.aiSources;
            item.acknowledgedJson = root.cfg.aiAcknowledged;
        }
    }
    readonly property var aiBackend: aiLoader.item
    // What the island changes reaches the settings, and what the settings window changes reaches the island.
    Connections {
        target: root.aiBackend
        function onSourcesJsonChanged() { if (root.cfg.aiSources !== root.aiBackend.sourcesJson) root.cfg.aiSources = root.aiBackend.sourcesJson; }
        function onAcknowledgedJsonChanged() { if (root.cfg.aiAcknowledged !== root.aiBackend.acknowledgedJson) root.cfg.aiAcknowledged = root.aiBackend.acknowledgedJson; }
    }
    Connections {
        target: root.cfg
        function onAiSourcesChanged() { if (root.aiBackend !== null && root.aiBackend.sourcesJson !== root.cfg.aiSources) root.aiBackend.sourcesJson = root.cfg.aiSources; }
        function onAiAcknowledgedChanged() { if (root.aiBackend !== null && root.aiBackend.acknowledgedJson !== root.cfg.aiAcknowledged) root.aiBackend.acknowledgedJson = root.cfg.aiAcknowledged; }
    }
    // The Cloud tab: the user's rclone remotes and what sync clients say. Loaded by name, only while it is on.
    OptionalBackend {
        id: cloudLoader
        source: root.cfg.showCloud ? "backend/CloudBackend.qml" : ""
        onLoaded: {
            item.core = Qt.binding(() => root.core);
            item.hub = transferHub;
            item.enabled = Qt.binding(() => root.cfg.showCloud);
            item.hiddenJson = Qt.binding(() => root.cfg.cloudHidden);
            item.aliasesJson = Qt.binding(() => root.cfg.cloudAliases);
            item.warnPercent = Qt.binding(() => root.cfg.cloudWarnPercent);
            item.criticalPercent = Qt.binding(() => root.cfg.cloudCriticalPercent);
            item.alerts = Qt.binding(() => root.cfg.cloudAlerts);
            item.alertPauseHours = Qt.binding(() => root.cfg.cloudAlertPauseHours);
            item.confirmUpload = Qt.binding(() => root.cfg.cloudConfirmUpload);
            item.autoFetchMB = Qt.binding(() => root.cfg.cloudAutoFetchMB);
            item.cacheMB = Qt.binding(() => root.cfg.cloudCacheMB);
            item.indicator = Qt.binding(() => root.cfg.cloudIndicator);
            item.alertedJson = root.cfg.cloudAlerted;
            item.lastTarget = root.cfg.cloudLastTarget;
        }
    }
    readonly property var cloudBackend: cloudLoader.item
    Connections {
        target: root.cloudBackend
        function onAlertedJsonChanged() { if (root.cfg.cloudAlerted !== root.cloudBackend.alertedJson) root.cfg.cloudAlerted = root.cloudBackend.alertedJson; }
        function onLastTargetChanged() { if (root.cfg.cloudLastTarget !== root.cloudBackend.lastTarget) root.cfg.cloudLastTarget = root.cloudBackend.lastTarget; }
    }
    // Clipboard history: Plasma's own (Klipper), loaded only when the page is wanted.
    OptionalBackend { id: clipboardLoader; source: root.cfg.showClipboard ? "backend/ClipboardBackend.qml" : "" }
    OptionalBackend { id: kdeconnectLoader; source: root.cfg.showKdeConnect ? "backend/KdeConnectBackend.qml" : "" }

    readonly property var powerBackend: powerLoader.item
    readonly property var bluetoothBackend: bluetoothLoader.item
    readonly property var displayBackend: displayLoader.item
    readonly property var keyboardBackend: keyboardLoader.item
    readonly property var networkBackend: networkLoader.item
    readonly property var dndBackend: dndLoader.item
    readonly property var tasksBackend: tasksLoader.item
    readonly property var jobsBackend: jobsLoader.item
    readonly property var weatherBackend: weatherLoader.item
    readonly property var appsBackend: appsLoader.item
    readonly property var calendarBackend: calendarLoader.item
    readonly property var clipboardBackend: clipboardLoader.item
    readonly property var kdeconnectBackend: kdeconnectLoader.item
    // "Dark mode" in Controls; remembers the schemes it switches between.
    ColorSchemeBackend {
        id: colorSchemes
        core: root.core
        darkScheme: root.cfg.darkColorScheme
        lightScheme: root.cfg.lightColorScheme
        onRemember: (dark, name) => { if (dark) root.cfg.darkColorScheme = name; else root.cfg.lightColorScheme = name; }
    }
    // The applied colour scheme, for the settings page (its preset samples and swatches).
    readonly property string schemeText: Styles.schemeText(colorSchemes.colors)
    onSchemeTextChanged: if (root.cfg.systemScheme !== schemeText) root.cfg.systemScheme = schemeText

    // ---- native core (optional: native/core) ------------------------------------
    Loader {
        id: coreLoader
        source: "NativeBridge.qml"
        onStatusChanged: if (status === Loader.Error) {
            console.info("org.phobby.dynamicisland: native core not installed; screen recording, privacy indicators, unlock, calls, D-Bus API and updates are disabled");
        }
    }
    readonly property var core: coreLoader.status === Loader.Ready ? coreLoader.item : null
    Binding { target: Requirements; property: "nativeAvailable"; value: root.core !== null && !!root.core.local }
    // Paths given by hand for commands (Settings › Diagnostics), for everything the shell finds or starts.
    Binding {
        target: root.core !== null ? root.core.local : null
        property: "commandPaths"
        value: { try { const v = JSON.parse(root.cfg.commandPaths || "{}"); return v && typeof v === "object" ? v : {}; } catch (e) { return {}; } }
        when: root.core !== null && !!root.core.local && root.core.local.commandPaths !== undefined
    }
    // A card's "Set the path by hand" or a message's click: the settings window, at that page and row.
    function openSettingsAt(target: string): void {
        island.expanded = false;
        root.cfg.settingsJump = target;
        Plasmoid.internalAction("configure").trigger();
    }
    Connections {
        target: root.cfg
        function onCommandPathsChanged() { Requirements.recheck(); }
    }
    Binding { target: root.core; property: "updatesEnabled"; value: root.cfg.showUpdates; when: root.core !== null }
    // The settings outlive the widget: taken off the desktop and put back, it comes as it was.
    SettingsKeeper {
        cfg: root.cfg
        local: root.core !== null ? root.core.local : null
        appletId: Plasmoid.id
        onRestored: count => console.info("org.phobby.dynamicisland: " + count + " settings of an earlier island were brought back")
        // (what an earlier island left is in place now: the settings can be brought up to date)
        onSettled: (wasNew, count) => root.migrateSettings(!wasNew, count > 0)
    }

    // ---- the settings' versions (SettingsMigration.js) ---------------------------------
    // Brought up to date once, after SettingsKeeper has looked (it says whether this widget ran
    // before); without the native module it never does, and a moment after the start will do.
    function settingsNow(kept: bool): var {
        return { settingsSchema: root.cfg.settingsSchema, islandLayout: root.cfg.islandLayout, notchMode: root.cfg.notchMode,
                 installedVersion: root.cfg.installedVersion, settingsKept: kept, layoutNotice: root.cfg.layoutNotice,
                 fullscreenMode: root.cfg.fullscreenMode, notchFullscreen: root.cfg.notchFullscreen, tourShown: root.cfg.tourShown };
    }
    function migrateSettings(kept: bool, restored: bool): void {
        const changes = Migration.migrate(root.settingsNow(kept), restored);
        for (const key in changes) root.cfg[key] = changes[key];
        if (changes.settingsSchema !== undefined)
            console.info("org.phobby.dynamicisland: settings brought up to version " + changes.settingsSchema
                         + (changes.islandLayout !== undefined ? ", layout " + (changes.islandLayout === 0 ? "notch" : "oval") : "")
                         + (changes.fullscreenMode !== undefined ? ", full-screen mode " + changes.fullscreenMode : "")
                         + (changes.tourShown !== undefined ? ", no first-run tour (ran before)" : ""));
    }
    Timer {
        interval: 4000
        running: root.cfg.settingsSchema < Migration.CURRENT
        onTriggered: root.migrateSettings(root.cfg.settingsKept === true, false)
    }
    // Told once, after the island's first seconds, to who was moved to the oval layout: the notch is there.
    Timer {
        interval: 8000
        running: root.cfg.layoutNotice === 1 && root.leads
        onTriggered: {
            activities.flash({ key: "layout-notice", icon: "preferences-desktop-theme-global-symbolic", color: theme.live, feel: "done",
                               title: Lang.i18n("A new notch design is here"), subtitle: Lang.i18n("Appearance › Layout"),
                               width: theme.notificationWidth, duration: 8000,
                               activate: () => Plasmoid.internalAction("configure").trigger() });
            root.cfg.layoutNotice = 2;
        }
    }

    // Timer / alarm sound (QtMultimedia; optional). Loaded on first use only,
    // so an idle island never initialises the multimedia stack.
    Loader {
        id: soundLoader
        active: false
        source: "SoundPlayer.qml"
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: QtMultimedia (qml6-module-qtmultimedia) not found; the timer, alarm and calendar sounds are not played")
    }
    QtObject {
        id: soundProxy
        function play(source) {
            if (!source) return;
            soundLoader.active = true;
            if (soundLoader.item) soundLoader.item.play(source);
        }
        function stop() { if (soundLoader.item) soundLoader.item.stop(); }
        readonly property bool playing: soundLoader.item !== null && soundLoader.item.playing
    }
    readonly property var sound: soundProxy

    // ---- providers --------------------------------------------------------------------
    // Every provider feeds the manager independently. Providers that need an
    // optional backend only exist while that backend is available.
    // Inside these implicit components a bare `theme` / `backend` would resolve
    // to the provider's own property, so they reference these instead.
    readonly property Theme islandTheme: theme
    readonly property PlasmaBackend plasmaBackend: backend

    component WhenAvailable: Loader {
        required property var dependency
        active: dependency !== null && dependency !== undefined
    }

    Item {
        id: providers

        MediaProvider {
            manager: activities
            backend: backend
            enabled: root.cfg.showMediaModule
        }
        NotificationProvider {
            id: notificationProvider
            manager: activities
            backend: backend
            enabled: root.cfg.showNotifications
            doNotDisturb: root.dndBackend ? root.dndBackend.active : false
        }
        WhenAvailable {
            dependency: root.powerBackend
            sourceComponent: PowerProvider {
                manager: activities
                backend: root.plasmaBackend
                power: root.powerBackend
                theme: root.islandTheme
                enabled: root.cfg.showPowerEvents
                lowThreshold: root.cfg.lowBatteryThreshold
                criticalThreshold: root.cfg.criticalBatteryThreshold
            }
        }
        WhenAvailable {
            dependency: root.bluetoothBackend
            sourceComponent: BluetoothProvider {
                manager: activities
                bluetooth: root.bluetoothBackend
                theme: root.islandTheme
                enabled: root.cfg.showBluetoothEvents
                lowBattery: root.cfg.deviceBatteryThreshold
            }
        }
        OsdProvider {
            manager: activities
            backend: backend
            display: root.displayBackend
            theme: theme
            enabled: root.cfg.showOsdEvents
        }
        WhenAvailable {
            dependency: root.keyboardBackend
            sourceComponent: KeyboardProvider {
                manager: activities
                keyboard: root.keyboardBackend
                theme: root.islandTheme
                enabled: root.cfg.showKeyboardEvents
            }
        }
        WhenAvailable {
            dependency: root.networkBackend
            sourceComponent: NetworkProvider {
                manager: activities
                network: root.networkBackend
                theme: root.islandTheme
                enabled: root.cfg.showNetworkEvents
            }
        }
        WhenAvailable {
            dependency: root.dndBackend
            sourceComponent: DndProvider {
                manager: activities
                dnd: root.dndBackend
                theme: root.islandTheme
                enabled: root.cfg.showDndEvents
                missed: notificationProvider.missedWhileDnd
            }
        }
        WhenAvailable {
            dependency: root.core
            sourceComponent: RecordingProvider {
                manager: activities
                theme: root.islandTheme
                tasks: root.tasksBackend
                core: root.core
                enabled: root.cfg.showRecording
            }
        }
        PrivacyProvider {
            manager: activities
            backend: backend
            theme: theme
            core: root.core
            enabled: root.cfg.showPrivacy
        }
        // ---- transfers: one hub, one provider per source -----------------------
        TransferHub {
            id: transferHub
            manager: activities
            theme: theme
            enabled: root.cfg.showJobs
        }
        WhenAvailable {
            dependency: root.jobsBackend
            sourceComponent: JobsProvider {                  // KIO: Dolphin, kioclient, Ark, remote uploads
                jobs: root.jobsBackend
                hub: transferHub
                enabled: root.cfg.showJobs
            }
        }
        WhenAvailable {
            dependency: root.jobsBackend
            sourceComponent: KdeConnectTransferProvider {    // phone ⇄ computer
                jobs: root.jobsBackend
                hub: transferHub
                enabled: root.cfg.showJobs && root.cfg.showKdeConnect
            }
        }
        WhenAvailable {
            dependency: root.jobsBackend
            sourceComponent: RemovableTransferProvider {     // USB sticks, external disks
                jobs: root.jobsBackend
                hub: transferHub
                enabled: root.cfg.showJobs
            }
        }
        BrowserDownloadProvider {                            // Browser Integration jobs + download folder
            jobs: root.jobsBackend
            hub: transferHub
            core: root.core
            enabled: root.cfg.showJobs && root.cfg.trackDownloads && root.cfg.watchDownloads
            minSeconds: root.cfg.trackMinSeconds
            announce: root.cfg.trackAnnounceEnd
        }
        Binding {
            target: root.core; when: root.core !== null; property: "downloadDirectories"; restoreMode: Binding.RestoreNone
            value: String(root.cfg.trackFolders || "").split("\n").map(s => s.trim()).filter(s => s.length > 0)
        }
        Binding { target: root.core; when: root.core !== null; property: "downloadSettleTime"; value: Math.max(1, root.cfg.trackSettleSeconds) * 1000; restoreMode: Binding.RestoreNone }
        CommandTransferProvider {                            // apt, PackageKit, git clone, wget, curl, pip…
            hub: transferHub
            core: root.core
            enabled: root.cfg.showJobs && root.cfg.trackDownloads
            packages: root.cfg.trackPackages
            clones: root.cfg.trackGit
            tools: root.cfg.trackTools
            background: root.cfg.trackBackground
            minSeconds: root.cfg.trackMinSeconds
            minBytes: root.cfg.trackMinKilobytes * 1024
            addedCommands: root.cfg.trackCommandsAdded
            removedCommands: root.cfg.trackCommandsRemoved
            announce: root.cfg.trackAnnounceEnd
        }
        TimerProvider {
            id: timerProvider
            manager: activities
            theme: theme
            cfg: root.cfg
            sound: root.sound
            enabled: root.cfg.showTools
        }
        StopwatchProvider {
            id: stopwatchProvider
            manager: activities
            theme: theme
            cfg: root.cfg
            enabled: root.cfg.showTools
        }
        PomodoroProvider {
            id: pomodoroProvider
            manager: activities
            theme: theme
            cfg: root.cfg
            sound: root.sound
            enabled: root.cfg.showTools
        }
        AlarmProvider {
            id: alarmProvider
            manager: activities
            theme: theme
            cfg: root.cfg
            sound: root.sound
            enabled: root.cfg.showTools
        }
        HabitsProvider {
            id: habitsProvider
            manager: activities
            theme: theme
            cfg: root.cfg
            core: root.core
            enabled: root.cfg.showHabits
            // The evening question's button, or the waiting activity: the island opens on the review.
            onOpened: island.openPage("habits")
        }
        WhenAvailable {
            id: calendarProviderLoader
            dependency: root.calendarBackend
            sourceComponent: CalendarProvider {
                manager: activities
                calendar: root.calendarBackend
                theme: root.islandTheme
                dismissedJson: root.cfg.calendarDismissed
                onDismissedEdited: json => root.cfg.calendarDismissed = json
                sound: root.sound
                soundSource: root.cfg.calendarSound && root.cfg.timerSoundEnabled ? root.cfg.timerSound : ""
                leadMinutes: root.cfg.calendarLeadMinutes
                lingerMinutes: root.cfg.calendarLingerMinutes
                showAllDay: root.cfg.calendarShowAllDay
                enabled: root.cfg.showCalendar
            }
        }
        WhenAvailable {
            dependency: root.weatherBackend
            sourceComponent: WeatherProvider {
                manager: activities
                theme: root.islandTheme
                weather: root.weatherBackend
                enabled: root.cfg.showWeather && root.cfg.showWeatherAlerts
                announced: root.cfg.weatherAnnounced
                onAnnouncedEdited: text => root.cfg.weatherAnnounced = text
            }
        }
        // Whether an application fills the screen: only looked at while suggestions are on.
        Loader {
            id: fullscreenWatch
            source: root.cfg.suggestionsEnabled ? "backend/FullscreenBackend.qml" : ""
        }
        // What a suggestion needs of the other parts; a part that is off or missing takes its rule with it.
        SuggestionProvider {
            id: suggestionProvider
            manager: activities
            theme: theme
            cfg: root.cfg
            backend: backend
            core: root.core
            dnd: root.dndBackend
            power: root.powerBackend
            bluetooth: root.bluetoothBackend
            pomodoro: root.cfg.showTools ? pomodoroProvider : null
            calendar: root.cfg.showCalendar ? calendarProviderLoader.item : null
            recordingWatched: root.cfg.showRecording
            microphoneWatched: root.cfg.showPrivacy
            powerWatched: root.cfg.showPowerEvents
            mediaWatched: root.cfg.showMediaModule
            enabled: root.cfg.suggestionsEnabled
            fullscreen: fullscreenWatch.item !== null && fullscreenWatch.item.active
            level: root.cfg.suggestionLevel
            dailyCards: root.cfg.suggestionDailyCards
            cooldownMinutes: root.cfg.suggestionCooldownMinutes
            halfLifeDays: root.cfg.suggestionHalfLifeDays
            gapMinutes: root.cfg.suggestionGapMinutes
            lowBattery: root.cfg.lowBatteryThreshold
        }
        // The AI tab's answer on its way (three dots) and "Answer ready"; loaded by name, only while the tab is on.
        Loader {
            id: aiActivity
            readonly property bool wanted: root.aiBackend !== null
            function reload(): void {
                if (wanted) setSource("providers/AiActivityProvider.qml", { manager: activities, theme: root.islandTheme, ai: root.aiBackend });
                else source = "";
            }
            onWantedChanged: reload()
            Component.onCompleted: reload()
            onLoaded: item.notify = Qt.binding(() => root.cfg.aiNotify)
            Connections {
                target: aiActivity.item
                function onOpened() { island.openPage("ai"); }
            }
        }
        // The Cloud tab's sync indicator and alerts; loaded by name, only while the tab is on.
        Loader {
            id: cloudActivity
            readonly property bool wanted: root.cloudBackend !== null
            function reload(): void {
                if (wanted) setSource("providers/CloudActivityProvider.qml", { manager: activities, theme: root.islandTheme, cloud: root.cloudBackend });
                else source = "";
            }
            onWantedChanged: reload()
            Component.onCompleted: reload()
            Connections {
                target: cloudActivity.item
                function onOpened(id) { island.openPage("cloud"); }
            }
        }
        KdeConnectProvider {
            manager: activities
            backend: backend
            theme: theme
            kdeconnect: root.kdeconnectBackend
            core: root.core
            enabled: root.cfg.showKdeConnect
            lowBattery: root.cfg.deviceBatteryThreshold
        }
        ThermalProvider {
            manager: activities
            backend: backend
            theme: theme
            enabled: root.cfg.showThermalWarning
            cpuThreshold: root.cfg.cpuTempThreshold
            gpuThreshold: root.cfg.gpuTempThreshold
        }
        UpdatesProvider {
            manager: activities
            theme: theme
            core: root.core
            enabled: root.cfg.showUpdates
            announced: root.cfg.updatesAnnounced
            onAnnouncedEdited: value => root.cfg.updatesAnnounced = value
        }
        // The island's own new versions (the system's are UpdatesProvider's).
        SelfUpdateProvider {
            manager: activities
            theme: theme
            core: root.core
            mode: root.cfg.updateMode
            current: Plasmoid.metaData.version
            previous: root.cfg.installedVersion
            onVersionSeen: version => root.cfg.installedVersion = version
            asked: root.cfg.updateAsked
            onAskedAbout: mark => root.cfg.updateAsked = mark
        }
        DbusProvider {
            manager: activities
            theme: theme
            core: root.core
            enabled: root.cfg.enableDbusApi
        }
        UnlockProvider {
            manager: activities
            theme: theme
            core: root.core
            enabled: root.cfg.showUnlock
        }
    }

    Component {
        id: quickSettingsPage
        QuickSettingsPage {
            theme: root.islandTheme
            dnd: root.dndBackend
            display: root.displayBackend
            power: root.powerBackend
            bluetooth: root.bluetoothBackend
            network: root.networkBackend
            core: root.core
            kdeconnect: root.kdeconnectBackend
            schemes: colorSchemes
            backend: root.plasmaBackend
            showUpdates: root.cfg.showUpdates
            showVolume: root.cfg.showVolumeModule
            tiles: root.cfg.controlTiles
            onColour: root.cfg.controlOnColor
            offColour: root.cfg.controlOffColor
            tileColours: { try { const v = JSON.parse(root.cfg.controlTileColors || "{}"); return v && typeof v === "object" && !Array.isArray(v) ? v : {}; } catch (e) { return {}; } }
            onTilesEdited: tiles => root.cfg.controlTiles = tiles
        }
    }

    Component {
        id: toolsPage
        ToolsPage {
            theme: root.islandTheme
            timer: timerProvider
            stopwatch: stopwatchProvider
            pomodoro: pomodoroProvider
            alarm: alarmProvider
            active: island.expanded
        }
    }

    Component {
        id: habitsPage
        HabitsPage {
            theme: root.islandTheme
            habits: habitsProvider
            accentColors: root.cfg.habitsColorSource === 1
        }
    }

    Component {
        id: weatherPage
        WeatherPage {
            theme: root.islandTheme
            weather: root.weatherBackend
            earlierName: root.cfg.weatherPlaceName
            onLocationPicked: json => root.cfg.weatherLocation = json
        }
    }

    Component {
        id: appsPage
        AppsPage {
            theme: root.islandTheme
            apps: root.appsBackend
            shortcuts: root.cfg.appShortcuts
            onEdited: json => root.cfg.appShortcuts = json
            onLaunched: island.expanded = false
        }
    }

    readonly property var calendarSourceList: {
        try {
            const list = JSON.parse(root.cfg.calendarSources || "[]");
            return Array.isArray(list) ? list.filter(s => s && typeof s.url === "string") : [];
        } catch (e) { return []; }
    }

    Component {
        id: clipboardPage
        ClipboardPage {
            theme: root.islandTheme
            clipboard: root.clipboardBackend
        }
    }

    Component {
        id: notesPage
        NotesPage {
            theme: root.islandTheme
            notes: notesBackend
            onDefaultPicked: id => root.cfg.notesDefault = id
            resume: root.cfg.notesResume
            lastOpen: root.cfg.notesLastOpen
            onLastOpenEdited: json => root.cfg.notesLastOpen = json
        }
    }

    Component {
        id: aiPage
        // The page itself is loaded by name, like its backend; what the island asks of a page is handed on.
        Loader {
            readonly property bool interacting: item !== null && item.interacting
            readonly property bool holdOpen: item !== null && item.holdOpen
            readonly property bool asking: item !== null && item.asking === true
            readonly property bool tall: item !== null && item.tall
            Component.onCompleted: setSource("AiPage.qml", { theme: root.islandTheme, ai: root.aiBackend })
            Connections {
                target: item
                function onDefaultPicked(id) { root.cfg.aiDefault = id; }
            }
        }
    }

    Component {
        id: cloudPage
        Loader {
            readonly property bool interacting: item !== null && item.interacting
            readonly property bool holdOpen: item !== null && item.holdOpen
            readonly property bool asking: item !== null && item.asking === true
            readonly property bool tall: item !== null && item.tall
            Component.onCompleted: setSource("CloudPage.qml", { theme: root.islandTheme, cloud: root.cloudBackend })
        }
    }

    Component {
        id: calendarPage
        CalendarPage {
            theme: root.islandTheme
            provider: calendarProviderLoader.item
            client: calendarClient
            google: googleCalendar
            onGoogleClientSaved: (id, secret) => { root.cfg.googleClientId = id; root.cfg.googleClientSecret = secret; }
            sources: root.calendarSourceList
            onSourceAdded: source => { root.cfg.calendarSources = JSON.stringify(root.calendarSourceList.concat([source])); }
        }
    }

    // ---- placement --------------------------------------------------------------
    readonly property rect screenRect: {
        const c = Plasmoid.containment;
        const g = c ? c.screenGeometry : Qt.rect(0, 0, 0, 0);
        // Containments that are not bound to a screen (plasmawindowed,
        // plasmoidviewer) report an empty geometry: use the host screen.
        if (g.width <= 0 || g.height <= 0) {
            return Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height);
        }
        if (!root.cfg.avoidPanels) return g;
        const a = c.availableScreenRect;
        return Qt.rect(g.x + a.x, g.y + a.y, a.width, a.height);
    }

    // Added twice to one screen, only the first island shows (see Islands.qml).
    // (the notch counts as being on the screen it is on)
    readonly property string screenKey: {
        if (root.notchWanted) return root.notchScreen.x + "," + root.notchScreen.y;
        const c = Plasmoid.containment;
        const g = c ? c.screenGeometry : Qt.rect(0, 0, 0, 0);
        return g.width > 0 && g.height > 0 ? g.x + "," + g.y : Screen.virtualX + "," + Screen.virtualY;
    }

    // ---- notch mode -----------------------------------------------------------------
    // The island welded to the top edge of a screen, over the panel there. On Wayland it moves
    // into a window of its own (NotchWindow.qml, a layer-shell overlay surface); elsewhere, or
    // without LayerShellQt, the Dialog goes to the edge. See docs/ARCHITECTURE.md, "Notch mode".
    // (until the settings are brought up to date: the layout they will have then, so nothing jumps)
    readonly property bool notchWanted: Migration.layoutOf(root.settingsNow(root.cfg.settingsKept === true), false) === 0
    PanelWatch {
        id: panels
        core: root.core
        enabled: root.notchWanted
        hint: Plasmoid.containment ? Plasmoid.containment.availableScreenRegion : null
    }
    // The whole of the island's own screen (the panels not left out).
    readonly property rect ownScreen: {
        const c = Plasmoid.containment;
        const g = c ? c.screenGeometry : Qt.rect(0, 0, 0, 0);
        return g.width > 0 && g.height > 0 ? g : Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height);
    }
    // Its screen: the top panel's (that on the island's own screen first), or the primary one;
    // the island's own when there is no such.
    readonly property rect notchScreen: {
        const r = s => Qt.rect(s.x, s.y, s.width, s.height);
        if (root.cfg.notchScreen === 1 && panels.screens.length > 0) return r(panels.screens[0]);
        if (root.cfg.notchScreen === 0 && panels.topPanels.length > 0)
            return r((panels.topPanelAt(root.ownScreen.x, root.ownScreen.y) || panels.topPanels[0]).screen);
        return root.ownScreen;
    }
    readonly property var notchPanel: root.notchWanted ? panels.topPanelAt(root.notchScreen.x, root.notchScreen.y) : null
    // (for the settings page: what was found there)
    readonly property int notchPanelSeen: !panels.ready ? -1 : root.notchPanel !== null ? root.notchPanel.height : 0
    onNotchPanelSeenChanged: if (root.notchWanted && root.cfg.notchPanelSeen !== notchPanelSeen) root.cfg.notchPanelSeen = notchPanelSeen
    // Its height in px: as set, or the top panel's; 0 = the island's own.
    readonly property int notchPixels: root.cfg.notchHeightMode === 1 ? root.cfg.notchHeight : root.notchPanel !== null ? root.notchPanel.height : 0
    function qtScreenAt(r: rect): var {
        for (const s of Qt.application.screens)
            if (s.virtualX === r.x && s.virtualY === r.y) return s;
        return null;
    }
    readonly property var notchQtScreen: root.qtScreenAt(root.notchScreen)
    Loader {
        id: screenPlacer
        active: root.notchWanted
        source: "ScreenBridge.qml"
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: the native module is missing (or too old) to put the notch on another screen; install.sh builds it");
    }
    // Its window, made anew when the notch goes to another screen (a layer surface keeps the one it was made on).
    Loader {
        id: notchLoader
        // (the oval island too, while it peeks over a window that fills the screen: see the full-screen mode)
        readonly property var target: !root.leads || !root.waylandShell ? null
                                      : root.notchWanted ? root.notchQtScreen : root.ovalOverlay ? root.qtScreenAt(root.ownScreen) : null
        onTargetChanged: reload()
        Component.onCompleted: reload()
        function reload(): void {
            if (target === null) { source = ""; return; }
            // (two objects can stand for one screen: known by name)
            if (item !== null && item.screen !== null && item.screen.name === target.name) return;
            // (made anew once the old one is gone: made in the same turn, it lands on the old screen)
            source = "";
            Qt.callLater(() => { if (target !== null && String(source) === "") source = "NotchWindow.qml"; });
        }
        onLoaded: {
            // (before it is shown: its surface is made on the screen it has then)
            item.screen = target;
            if (screenPlacer.item !== null) screenPlacer.item.place(item, target.name);
            item.width = Qt.binding(() => Math.round(root.windowWidth * theme.scale) + 2 * Math.abs(theme.offsetX));
            item.height = Qt.binding(() => Math.round(root.windowHeight * theme.scale));
            item.keyboard = Qt.binding(() => island.wantsKeyboard);
            item.visible = Qt.binding(() => !peek.hidden);
        }
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: LayerShellQt (org.kde.layershell) not found; the notch stays in the island's usual window, which may lie under a panel");
    }
    readonly property var notchWindow: notchLoader.status === Loader.Ready ? notchLoader.item : null
    // ---- over a window that fills the screen: the full-screen mode ----------------------------
    // Appearance › Layout, both layouts (states: FullscreenPeek.qml). 0 = hide; 1 = normal: as it is (the
    // notch stays over such a window, the oval layout's Dialog lies under it); 2 = peek: drawn up to the top
    // edge with a small part showing, the pointer at the edge brings it down and opens it; 3 = shrink: drawn
    // in to a small nub, the pointer on it opens it. Only for a window on the island's own screen.
    // (until the settings are brought up to date: the mode they will have then, so nothing jumps)
    readonly property int fullscreenMode: Migration.fullscreenOf(root.settingsNow(root.cfg.settingsKept === true))
    readonly property bool waylandShell: Qt.platform.pluginName.startsWith("wayland")
    readonly property rect islandScreen: root.notchWanted ? root.notchScreen : root.ownScreen
    Loader {
        id: fullscreenSeen
        active: root.leads && root.fullscreenMode !== 1
        source: "backend/FullscreenBackend.qml"
        onLoaded: {
            item.screen = Qt.binding(() => root.islandScreen);
            item.maximized = Qt.binding(() => root.cfg.peekMaximized);
            // (the notch, peeking or shrunk: a window that reaches under it too, as a panel's "Dodge windows" looks)
            item.area = Qt.binding(() => root.notchWanted && root.fullscreenMode >= 2 && root.cfg.notchDodgeWindows ? root.notchArea : Qt.rect(0, 0, 0, 0));
        }
    }
    readonly property rect notchArea: {
        const w = Math.round(island.pillWidth * theme.scale), h = Math.round(theme.pillHeight * theme.scale);
        return Qt.rect(root.notchScreen.x + (root.notchScreen.width - w) / 2 + theme.offsetX, root.notchScreen.y, w, h);
    }
    readonly property bool overFullscreen: fullscreenSeen.item !== null && fullscreenSeen.item.active
    readonly property bool overWindow: root.overFullscreen || fullscreenSeen.item !== null && fullscreenSeen.item.covered
    readonly property string overSeen: root.overFullscreen + ", reaches under the notch: " + (fullscreenSeen.item !== null && fullscreenSeen.item.covered)
    onOverSeenChanged: console.info("org.phobby.dynamicisland: a window fills the screen: " + root.overSeen)
    // A call ringing (it opens the island there, if wanted), and what the strip says: Fullscreen.js.
    readonly property bool ringing: activities.live.some(a => a.category === "call" && a.pulse)
    readonly property string peekSignal: !(peek.away || peek.shrunk) ? "" : Fullscreen.signalOf({
        ringing: root.ringing, calling: activities.live.some(a => a.category === "call"),
        recording: activities.live.some(a => a.category === "recording"),
        critical: activities.waitingCritical, privacy: activities.indicators.length > 0 })
    readonly property color peekSignalColor: root.peekSignal === "call" ? "#30d158"
                                            : root.peekSignal === "recording" ? theme.danger
                                            : root.peekSignal === "critical" ? "#ffd60a"
                                            : root.peekSignal === "privacy" ? activities.indicators[0].color
                                            : "transparent"
    FullscreenPeek {
        id: peek
        mode: root.fullscreenMode
        // (hiding: only for a window that fills the screen; one reaching under the notch is only looked at for the others)
        over: root.fullscreenMode === 0 ? root.overFullscreen : root.overWindow
        edgeHovered: edgeHover.hovered || peek.shrunk && island.hovered
        hovered: island.hovered
        open: island.expanded
        busy: island.wantsKeyboard
        delay: root.cfg.peekDelay
        ringing: root.ringing
        callOpens: root.cfg.peekEvents
        // On the desktop too, where wanted: nothing in it, nothing open over it, the pointer not on it
        // (drawn up or shrunk, the pointer there is the edge's: see edgeHovered).
        idle: island.mode === "idle" && !island.menuOpen && !island.wantsKeyboard && (!island.hovered || peek.away || peek.shrunk)
        idleDelay: root.cfg.peekIdle ? root.cfg.peekIdleDelay * 1000 : 0
        onOpenRequested: island.expanded = true
    }
    // Opened otherwise while it is drawn up or in (a click on the nub, the menu, a shortcut): it comes down.
    Connections {
        target: island
        function onExpandedChanged() { if (island.expanded && (peek.away || peek.shrunk)) peek.show(); }
    }
    // The oval island peeks from a window of the notch's kind (an overlay layer surface, the one kind of
    // window over one that fills the screen), on Wayland; kept a moment after, to come down in it.
    readonly property bool ovalOverlay: !root.notchWanted && root.fullscreenMode >= 2 && (peek.active || ovalReturn.running)
    Connections {
        target: peek
        function onActiveChanged() { if (!peek.active && !root.notchWanted && root.notchWindow !== null) ovalReturn.restart(); }
    }
    Timer { id: ovalReturn; interval: 420 }
    // There, where its Dialog would be (px below the top of the screen).
    readonly property real ovalDown: root.ovalOverlay && root.notchWindow !== null ? Math.max(0, dialog.y - root.ownScreen.y) : 0
    // Drawn up: only cfg.peekSize px of the small island below the edge (its lower edge, the notch's rounded
    // corners or the pill's), the island as large as it is.
    readonly property real peekAwayY: root.cfg.peekSize - island.restBottom * theme.scale - root.ovalDown
    readonly property int peekMove: 260
    // How far the island is moved down in its window now (for where it takes the pointer and is blurred).
    readonly property real hostShift: ovalShift.y + peekShift.y
    // Where the window the island is in has its left edge (for the companion's room).
    readonly property real windowX: root.notchWindow !== null ? root.islandScreen.x + (root.islandScreen.width - root.notchWindow.width) / 2 : dialog.x

    // Switched on or off, the island slides from where it was to where it goes instead of jumping.
    // The window keeps room below for it while it slides down.
    readonly property real usualTop: root.screenRect.y + theme.topOffset
    property real slideRoom: 0
    onNotchWantedChanged: {
        const from = root.notchWanted ? root.usualTop - root.notchScreen.y : root.notchScreen.y - root.usualTop;
        slideAnim.stop();
        root.slideRoom = Math.max(0, from);
        slide.y = from;
        slideAnim.start();
    }
    SequentialAnimation {
        id: slideAnim
        NumberAnimation { target: slide; property: "y"; to: 0; duration: 320; easing.type: Easing.OutCubic }
        ScriptAction { script: root.slideRoom = 0 }
    }
    readonly property bool leads: Islands.leads(root)
    onLeadsChanged: if (!leads) console.info("org.phobby.dynamicisland: another island is already on this screen; this one stays hidden")

    // The island is laid out at its designed size and scaled as a whole (the size
    // setting); the window and the blur region are that much larger or smaller.
    // (with a companion beside it the window keeps room for it on both sides, so the island stays in the middle)
    // (a notch set wider than the open island keeps its room while it morphs to and from it)
    readonly property real windowWidth: (island.needsWideWindow ? Math.max(island.openWideWidth, 2 * island.smallHalfWidth)
                                         : island.needsLargeWindow ? Math.max(island.openWidth, theme.notificationWidth, theme.eventWidth, 2 * island.smallHalfWidth)
                                         : Math.max(2 * island.smallHalfWidth, peek.away ? root.cfg.peekWidth : 0)) + 2 * theme.windowSidePad + 2 * companion.reserve
    readonly property real windowHeight: (island.needsTallWindow ? theme.tallHeight
                                          : island.needsLargeWindow ? Math.max(theme.expandedHeight, theme.notificationHeight)
                                          : theme.pillHeight) + theme.windowTopPad + theme.windowBottomPad + (root.slideRoom + root.ovalDown) / theme.scale

    Connections {
        target: island
        function onWantsKeyboardChanged() { if (island.wantsKeyboard) (root.notchWindow !== null ? root.notchWindow : dialog).requestActivate(); }
    }

    PlasmaCore.Dialog {
        id: dialog

        type: PlasmaCore.Dialog.Notification
        // Never takes focus, except while typing a quick reply (the same
        // trick as Plasma's notification popups).
        flags: Qt.WindowStaysOnTopHint | (island.wantsKeyboard ? 0 : Qt.WindowDoesNotAcceptFocus)
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        // (in notch mode the island is in its own window, when there is one)
        visible: root.leads && root.notchWindow === null && !peek.hidden

        // In notch mode without its window: at the top edge itself.
        x: root.notchWanted ? Math.round(root.notchScreen.x + (root.notchScreen.width - width) / 2 + theme.offsetX)
                            : Math.round(root.screenRect.x + (root.screenRect.width - width) / 2 + theme.offsetX)
        y: root.notchWanted ? root.notchScreen.y : Math.round(root.screenRect.y + theme.topOffset - theme.windowTopPad * theme.scale)

        mainItem: Item {
            id: dialogBody
            width: Math.round(root.windowWidth * theme.scale)
            height: Math.round(root.windowHeight * theme.scale)
        }
    }

    // The island, in the Dialog or in the notch's window; moved between them without being made anew.
    Item {
        id: islandHost
        parent: root.notchWindow !== null ? root.notchWindow.contentItem : dialogBody
        // (the notch's window is centred by the compositor: it is wider by the offset on both sides)
        x: root.notchWindow !== null ? Math.abs(theme.offsetX) + theme.offsetX : 0
        width: Math.round(root.windowWidth * theme.scale)
        height: Math.round(root.windowHeight * theme.scale)
        transform: [
            Translate { id: slide },
            // (the oval island peeking from the overlay window: where its Dialog would be, when down)
            Translate { id: ovalShift; y: root.ovalDown },
            // (peeking: up to the edge, and down again the same way; only moved, never resized)
            Translate {
                id: peekShift
                objectName: "peekShift"
                y: peek.away ? root.peekAwayY : 0
                Behavior on y { NumberAnimation { duration: root.peekMove; easing.type: Easing.OutCubic } }
            }
        ]

        // Drawn up or in, what matters says itself on the part that shows: a bar in its colour, pulsing
        // (in steps, 12 a second, and only while there is something to say: see Island's dot).
        Rectangle {
            objectName: "peekSignal"
            visible: root.peekSignal !== ""
            readonly property real room: peek.away ? root.cfg.peekSize : 6
            width: Math.min(island.surfaceRect.width * theme.scale * 0.5, 120)
            height: Math.max(2, room - 2)
            radius: height / 2
            x: (island.surfaceRect.x + island.surfaceRect.width / 2) * theme.scale - width / 2
            y: island.restBottom * theme.scale - room + (room - height) / 2
            z: 10
            color: root.peekSignalColor
            property int pulseAt: 0
            opacity: pulseAt >= 1100 ? 1 : 0.55 + 0.45 * Math.cos(2 * Math.PI * pulseAt / 1100)
            Timer {
                interval: 83
                repeat: true
                running: parent.visible
                onRunningChanged: parent.pulseAt = 0
                onTriggered: parent.pulseAt = (parent.pulseAt + interval) % 2000
            }
        }
        Island {
            id: island
            width: parent.width / theme.scale
            height: parent.height / theme.scale
            transformOrigin: Item.TopLeft
            scale: theme.scale
            theme: theme
            backend: backend
            network: root.networkBackend
            manager: activities
            showClock: root.cfg.showClock && !peek.shrunk
            resting: peek.away || peek.hidden
            restingHolds: peek.over
            hoverAbove: root.peekBridge && edgeHover.hovered
            hoverDelay: root.cfg.hoverDelay
            collapseDelay: root.cfg.collapseDelay
            // (come down and open over a window that fills the screen: a width of its own for that, if set)
            // (shrunk: as narrow as it gets, two of its heights)
            maxWidth: peek.shrunk ? 1 : root.notchWanted && peek.shown && root.cfg.notchDodgeWidth > 0 ? root.cfg.notchDodgeWidth : root.cfg.notchMaxWidth
            openFollowsWidth: root.cfg.notchOpenWidth
            dotMode: root.cfg.dotMode
            dotSize: Math.max(10, Math.min(28, root.cfg.dotSize))
            dotHoverExpand: root.cfg.dotHoverExpand
            dotEvents: root.cfg.dotEvents
            dotCriticalExpand: root.cfg.dotCriticalExpand
            // as it was left, always the pill, or always the dot
            Component.onCompleted: dot = root.cfg.dotMode && (root.cfg.dotStart === 2 || (root.cfg.dotStart === 0 && root.cfg.dotState))
            onDotChanged: if (root.cfg.dotState !== dot) root.cfg.dotState = dot
            showMediaModule: root.cfg.showMediaModule
            showSystemModule: root.cfg.showSystemModule
            showVolumeModule: root.cfg.showVolumeModule
            showNotificationModule: root.cfg.showNotificationModule
            pageOrder: root.cfg.pageOrder
            debugRegion: root.debugRegion
            suggestions: suggestionProvider
            dropPage: root.cfg.showCloud && root.cloudBackend !== null ? "cloud" : ""
            ambientGlow: root.cfg.ambientGlow
            onAmbientGlowToggled: root.cfg.ambientGlow = !root.cfg.ambientGlow
            // A new island's first opening: the tour (once the settings are brought up to date, which
            // says whether it ran before: one that did never sees it).
            tourConfig: root.cfg.settingsSchema >= 3 && root.cfg.tourShown !== true ? root.cfg : null
            nativeAvailable: root.core !== null
            onDiagnosticsRequested: { island.expanded = false; root.openSettingsAt("configDiagnostics:"); }
            systemView: root.cfg.systemView === 0 ? "fixed" : "dynamic"
            // The gear in the expanded header: Plasma's settings window of this widget.
            onSettingsRequested: {
                island.expanded = false;
                Plasmoid.internalAction("configure").trigger();
            }
            // A System card was clicked: btop with only that metric's graph (what is missing for it is said).
            onSystemMetricClicked: key => {
                const missing = root.core === null || !root.core.local ? "native" : !Requirements.find(root.core.local, "btop").found ? "btop" : "";
                if (missing.length > 0) {
                    const item = RequirementCatalog.item(missing);
                    activities.flash({ key: "requirement-" + missing, icon: "dialog-warning-symbolic", color: theme.warning, title: item.what,
                                       subtitle: Lang.i18n("Settings › Diagnostics says how to install it"), width: theme.notificationWidth,
                                       duration: 6000, activate: () => Requirements.openSettings("configDiagnostics:" + missing) });
                    return;
                }
                root.core.startDetached("sh", [String(Qt.resolvedUrl("../scripts/btop-view.sh")).replace(/^file:\/\//, ""), key]);
            }
            extraPages: [
                // The weather tab shows the weather itself: its icon and, where there is room, the temperature.
                { key: "weather", icon: "weather:" + (root.weatherBackend ? root.weatherBackend.icon : "cloud-sun"),
                  label: root.weatherBackend && root.weatherBackend.ready ? root.weatherBackend.degrees(root.weatherBackend.temperature) : "",
                  title: Lang.i18n("Weather"), component: weatherPage, visible: root.cfg.showWeather && root.weatherBackend !== null },
                { key: "apps", icon: "view-app-grid-symbolic", title: Lang.i18n("Apps"), component: appsPage, visible: root.cfg.showApps && root.appsBackend !== null },
                { key: "quicksettings", icon: "configure", title: Lang.i18n("Controls"), component: quickSettingsPage, visible: root.cfg.showQuickSettings },
                { key: "tools", icon: "chronometer", title: Lang.i18n("Tools"), component: toolsPage, visible: root.cfg.showTools },
                // The dot: a day's evening review is waiting.
                { key: "habits", icon: "view-calendar-tasks", title: Lang.i18n("Habits"), component: habitsPage, visible: root.cfg.showHabits,
                  dot: habitsProvider.pending !== "" },
                { key: "calendar", icon: "view-calendar", title: Lang.i18n("Calendar"), component: calendarPage,
                  visible: root.cfg.showCalendar && calendarProviderLoader.item !== null },
                { key: "notes", icon: "view-pim-notes", title: Lang.i18n("Notes"), component: notesPage, visible: root.cfg.showNotes },
                // The dot: an answer arrived while another page (or none) was shown.
                { key: "ai", icon: "lucide:sparkles", title: Lang.i18n("AI"), component: aiPage, visible: root.cfg.showAi && root.aiBackend !== null,
                  dot: root.aiBackend !== null && root.aiBackend.unseen },
                // The dot: a cloud is nearly full, or a sync has an error.
                { key: "cloud", icon: "folder-cloud", title: Lang.i18n("Cloud"), component: cloudPage, visible: root.cfg.showCloud && root.cloudBackend !== null,
                  dot: root.cloudBackend !== null && (root.cloudBackend.storageWarning || root.cloudBackend.syncError) },
                { key: "clipboard", icon: "edit-paste", title: Lang.i18n("Clipboard"), component: clipboardPage,
                  visible: root.cfg.showClipboard && root.clipboardBackend !== null }
            ]

            // The companion: a cat beside the pill (contents/ui/companion). It reads from the island and
            // the activities; it changes nothing of them, keeps nothing and asks nothing of the network.
            Companion {
                id: companion
                island: island
                theme: root.islandTheme
                // (in notch mode it would stand on the panel's widgets beside it, unless the user wants it there)
                // (not while the notch is shrunk to a nub over a window that fills the screen; drawn up to the
                // edge it goes up with the island, its feet no lower than the island's, and keeps still)
                enabled: root.cfg.catEnabled && !(root.notchWanted && root.cfg.notchHideCat) && !(root.fullscreenMode === 3 && peek.active)
                tucked: peek.away
                tuckMove: root.peekMove
                sideSetting: root.cfg.catSide
                sizePercent: root.cfg.catSize
                fur: root.cfg.catFur
                furColor: root.cfg.catFurColor
                music: root.cfg.catMusic
                thoughts: root.cfg.catThoughts
                events: root.cfg.catEvents
                petting: root.cfg.catPetting
                clicks: root.cfg.catClicks
                noAnger: root.cfg.catNoAnger
                sulkSeconds: root.cfg.catSulkSeconds
                sleepSeconds: root.cfg.catSleepSeconds
                dotBehaviour: root.cfg.catDot
                reduceMotion: root.cfg.catReduceMotion
                ai: root.aiBackend
                spaceLeft: (root.windowX + islandHost.x + islandHost.width / 2 - root.screenRect.x) / root.islandTheme.scale
                spaceRight: (root.screenRect.x + root.screenRect.width - root.windowX - islandHost.x - islandHost.width / 2) / root.islandTheme.scale
                onHideRequested: root.cfg.catEnabled = false
                onSettingsRequested: Plasmoid.internalAction("configure").trigger()
            }
        }
    }

    // Peeking, drawn up: the strip along the top edge where the island is (as wide as it, or as set) takes
    // the pointer, as deep as what shows; the topmost row of pixels too, so the pointer pushed against the
    // edge finds it. Everything else of the screen, and of the island's window, is the full-screen window's.
    // Come down, the oval island is a little below the edge: the strip then reaches from the edge to it
    // (a bridge), and the pointer there is on the island, so the pointer left at the edge keeps it open.
    readonly property bool peekBridge: peek.shown && root.ovalOverlay && root.notchWindow !== null
    Item {
        id: peekEdge
        parent: root.notchWindow !== null ? root.notchWindow.contentItem : dialogBody
        visible: peek.away || root.peekBridge
        readonly property real centre: islandHost.x + (island.surfaceRect.x + island.surfaceRect.width / 2) * theme.scale
        width: Math.min(parent ? parent.width : 0, (root.cfg.peekWidth > 0 && peek.away ? root.cfg.peekWidth : island.surfaceRect.width) * theme.scale)
        x: Math.max(0, Math.min((parent ? parent.width : 0) - width, centre - width / 2))
        // (drawn up: what shows of it, from the topmost row of pixels down; nothing below it takes the pointer)
        height: peek.away ? root.cfg.peekSize : Math.max(1, root.hostShift + island.surfaceRect.y * theme.scale + 2)
        HoverHandler { id: edgeHover }
        Rectangle {
            anchors.fill: parent
            visible: root.debugRegion
            color: "transparent"; border.width: 1; border.color: "red"
        }
    }
    readonly property rect peekEdgeRect: Qt.rect(peekEdge.x, 0, peekEdge.width, peekEdge.height)

    // ---- where the island takes the pointer ------------------------------------------
    // The window is larger than what is drawn (room for the shadow, the morph, the larger
    // states). Only the island's own shape takes the pointer; the rest of the window lets a
    // click through to what is underneath. Follows the shape while it morphs.
    Loader {
        id: mask
        source: "MaskBridge.qml"
        onLoaded: {
            item.window = Qt.binding(() => root.notchWindow !== null ? root.notchWindow : dialog);
            const scaled = r => Qt.rect(islandHost.x + r.x * theme.scale, root.hostShift + r.y * theme.scale, r.width * theme.scale, r.height * theme.scale);
            // (peeking, drawn up: only the strip along the edge)
            item.region = Qt.binding(() => peek.away ? root.peekEdgeRect : scaled(island.maskRect));
            item.radius = Qt.binding(() => peek.away ? 0 : island.hitRadius * theme.scale);
            item.region2 = Qt.binding(() => peek.away ? Qt.rect(0, 0, 0, 0) : scaled(island.maskBubbleRect));
            // the companion's body (a module from before it: the cat is only looked at)
            // (and the bridge from the edge down to the oval island, come down over a full-screen window)
            if (item.shapes !== undefined) item.shapes = Qt.binding(() => peek.away ? [] : companion.maskShapes.map(scaled).concat(root.peekBridge ? [root.peekEdgeRect] : []));
            item.enabled = true;
        }
        onStatusChanged: if (status === Loader.Error) {
            console.info("org.phobby.dynamicisland: the native effects module is missing (or too old): the whole window takes the pointer; install.sh builds it");
        }
    }
    // (to look at it: DYNAMICISLAND_DEBUG_REGION=1 when the shell starts draws its outline)
    readonly property bool debugRegion: mask.item !== null && mask.item.debug

    // ---- optional native blur -------------------------------------------------
    // BlurBridge.qml imports the native module; if it is not installed the
    // Loader simply errors out and we keep the opaque fallback.
    Loader {
        id: blur
        readonly property bool active: status === Loader.Ready && item && item.available
        source: theme.blurWanted ? "BlurBridge.qml" : ""
        onLoaded: {
            // (the notch in the island's own look is blurred in its window too)
            item.window = Qt.binding(() => root.notchWindow !== null ? root.notchWindow : dialog);
            const scaled = r => Qt.rect(islandHost.x + r.x * theme.scale, root.hostShift + r.y * theme.scale, r.width * theme.scale, r.height * theme.scale);
            // The notch has no upper corners: as the mask's, its rounded rectangles reach above the window by their radius.
            const above = (r, radius) => theme.notch && r.width > 0 ? Qt.rect(r.x, r.y - radius, r.width, r.height + radius) : r;
            item.rect = Qt.binding(() => scaled(above(island.surfaceRect, island.surfaceRadius)));
            item.radius = Qt.binding(() => island.surfaceRadius * theme.scale);
            item.rect2 = Qt.binding(() => scaled(above(island.bubbleRect, Math.min(island.bubbleRect.width, island.bubbleRect.height) / 2)));
            item.enabled = true;
        }
        onStatusChanged: if (status === Loader.Error) {
            console.info("org.phobby.dynamicisland: native blur helper not installed, using opaque fallback");
        }
    }

    // ---- the cat's poses, to look at (DYNAMICISLAND_CAT_GALLERY=1 when the shell starts) ---------
    Loader {
        // (a native module from before this has no `environment`: then there is no such switch)
        active: root.core !== null && !!root.core.local && typeof root.core.local.environment === "function"
                && root.core.local.environment("DYNAMICISLAND_CAT_GALLERY").length > 0
        sourceComponent: Window {
            visible: true
            width: 1180
            height: 760
            title: "Dynamic Island: cat poses"
            color: theme.surface
            IslandFlickable {
                anchors.fill: parent
                anchors.margins: 12
                contentHeight: gallery.height
                CatGallery {
                    id: gallery
                    width: parent.width
                    fur: root.cfg.catFur
                    furColor: root.cfg.catFurColor
                    accent: theme.accent
                    labelColor: theme.text
                    bubbleFill: theme.surface
                    bubbleRim: theme.mix(theme.surface, theme.text, 0.3)
                    bubbleInk: theme.text
                }
            }
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: island.expanded ? Lang.i18n("Collapse Island") : Lang.i18n("Expand Island")
            icon.name: island.expanded ? "collapse" : "expand"
            onTriggered: island.expanded = !island.expanded
        }
    ]
}
