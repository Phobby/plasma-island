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

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    // The widget's language (Settings → Language), for every text of the island.
    Binding { target: Lang; property: "setting"; value: root.cfg.language }

    Plasmoid.icon: "view-media-track"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: Lang.i18n("Dynamic Island")
    toolTipSubText: backend.hasMedia ? backend.track : ""

    compactRepresentation: Kirigami.Icon {
        source: Plasmoid.icon
        active: mouse.containsMouse
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: island.expanded = !island.expanded
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
        systemTop: root.cfg.topMargin
        blurActive: blur.active
    }
    // No settings window can be open when the shell starts: a preview left behind
    // (the shell was stopped while one was open) ends here.
    Component.onCompleted: if (root.cfg.previewActive) root.cfg.previewActive = false
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
    // Calendar: .ics links (no Akonadi). backend/CalendarBackend.qml is the
    // older PIM-plugin source, kept for reference but no longer loaded.
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
    Binding { target: root.core; property: "updatesEnabled"; value: root.cfg.showUpdates; when: root.core !== null }

    // Timer / alarm sound (QtMultimedia; optional). Loaded on first use only,
    // so an idle island never initialises the multimedia stack.
    Loader {
        id: soundLoader
        active: false
        source: "SoundPlayer.qml"
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
            enabled: root.cfg.showJobs && root.cfg.watchDownloads
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

    // Everything shown on the "Devices" page: Bluetooth devices + phones.
    readonly property var deviceList: {
        const list = [];
        const bt = root.bluetoothBackend;
        if (bt) {
            for (const d of bt.connectedDevices) {
                list.push({ icon: bt.iconFor(d), name: d.name, battery: bt.batteryOf(d), charging: false, detail: Lang.i18n("Bluetooth") });
            }
        }
        const kc = root.kdeconnectBackend;
        if (kc) {
            for (const p of kc.phones) {
                list.push({ icon: p.icon, name: p.name, battery: p.charge, charging: p.charging, detail: Lang.i18n("KDE Connect") });
            }
        }
        return list;
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

    Component {
        id: devicesPage
        DevicesPage {
            theme: root.islandTheme
            devices: root.deviceList
            lowBattery: root.cfg.deviceBatteryThreshold
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
            readonly property bool keepsWheel: item !== null && item.keepsWheel
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
            readonly property bool keepsWheel: item !== null && item.keepsWheel
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

    // The island is laid out at its designed size and scaled as a whole (the size
    // setting); the window and the blur region are that much larger or smaller.
    readonly property real windowWidth: (island.needsWideWindow ? theme.wideWidth
                                         : island.needsLargeWindow ? Math.max(theme.expandedWidth, theme.notificationWidth, theme.eventWidth)
                                         : 2 * theme.smallHalfWidth) + 2 * theme.windowSidePad
    readonly property real windowHeight: (island.needsTallWindow ? theme.tallHeight
                                          : island.needsLargeWindow ? Math.max(theme.expandedHeight, theme.notificationHeight)
                                          : theme.pillHeight) + theme.windowTopPad + theme.windowBottomPad

    Connections {
        target: island
        function onWantsKeyboardChanged() { if (island.wantsKeyboard) dialog.requestActivate(); }
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
        visible: true

        x: Math.round(root.screenRect.x + (root.screenRect.width - width) / 2 + theme.offsetX)
        y: Math.round(root.screenRect.y + theme.topOffset - theme.windowTopPad * theme.scale)

        mainItem: Item {
            width: Math.round(root.windowWidth * theme.scale)
            height: Math.round(root.windowHeight * theme.scale)

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
                showClock: root.cfg.showClock
                hoverDelay: root.cfg.hoverDelay
                collapseDelay: root.cfg.collapseDelay
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
                dropPage: root.cfg.showCloud && root.cloudBackend !== null ? "cloud" : ""
                ambientGlow: root.cfg.ambientGlow
                onAmbientGlowToggled: root.cfg.ambientGlow = !root.cfg.ambientGlow
                systemView: root.cfg.systemView === 0 ? "fixed" : "dynamic"
                // The gear in the expanded header: Plasma's settings window of this widget.
                onSettingsRequested: {
                    island.expanded = false;
                    Plasmoid.internalAction("configure").trigger();
                }
                // A System card was clicked: btop with only that metric's graph.
                onSystemMetricClicked: key => {
                    if (root.core) root.core.startDetached("sh", [String(Qt.resolvedUrl("../scripts/btop-view.sh")).replace(/^file:\/\//, ""), key]);
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
                    { key: "ai", icon: "dialog-messages", title: Lang.i18n("AI"), component: aiPage, visible: root.cfg.showAi && root.aiBackend !== null,
                      dot: root.aiBackend !== null && root.aiBackend.unseen },
                    // The dot: a cloud is nearly full, or a sync has an error.
                    { key: "cloud", icon: "folder-cloud", title: Lang.i18n("Cloud"), component: cloudPage, visible: root.cfg.showCloud && root.cloudBackend !== null,
                      dot: root.cloudBackend !== null && (root.cloudBackend.storageWarning || root.cloudBackend.syncError) },
                    { key: "clipboard", icon: "edit-paste", title: Lang.i18n("Clipboard"), component: clipboardPage,
                      visible: root.cfg.showClipboard && root.clipboardBackend !== null },
                    { key: "devices", icon: "network-bluetooth", title: Lang.i18n("Devices"), component: devicesPage,
                      visible: root.cfg.showDevicesModule && ((root.bluetoothBackend && root.bluetoothBackend.available) || root.deviceList.length > 0) }
                ]
            }
        }
    }

    // ---- where the island takes the pointer ------------------------------------------
    // The window is larger than what is drawn (room for the shadow, the morph, the larger
    // states). Only the island's own shape takes the pointer; the rest of the window lets a
    // click through to what is underneath. Follows the shape while it morphs.
    Loader {
        id: mask
        source: "MaskBridge.qml"
        onLoaded: {
            item.window = dialog;
            const scaled = r => Qt.rect(r.x * theme.scale, r.y * theme.scale, r.width * theme.scale, r.height * theme.scale);
            item.region = Qt.binding(() => scaled(island.hitRect));
            item.radius = Qt.binding(() => island.hitRadius * theme.scale);
            item.region2 = Qt.binding(() => scaled(island.bubbleRect));
            item.enabled = true;
        }
        onStatusChanged: if (status === Loader.Error) {
            console.info("org.phobby.dynamicisland: native module too old to shape where the island takes the pointer; run install.sh again");
        }
    }
    readonly property bool debugRegion: root.cfg.debugInputRegion || (mask.item !== null && mask.item.debug)

    // ---- optional native blur -------------------------------------------------
    // BlurBridge.qml imports the native module; if it is not installed the
    // Loader simply errors out and we keep the opaque fallback.
    Loader {
        id: blur
        readonly property bool active: status === Loader.Ready && item && item.available
        source: theme.blurWanted ? "BlurBridge.qml" : ""
        onLoaded: {
            item.window = dialog;
            const scaled = r => Qt.rect(r.x * theme.scale, r.y * theme.scale, r.width * theme.scale, r.height * theme.scale);
            item.rect = Qt.binding(() => scaled(island.surfaceRect));
            item.radius = Qt.binding(() => island.surfaceRadius * theme.scale);
            item.rect2 = Qt.binding(() => scaled(island.bubbleRect));
            item.enabled = true;
        }
        onStatusChanged: if (status === Loader.Error) {
            console.info("org.phobby.dynamicisland: native blur helper not installed, using opaque fallback");
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
