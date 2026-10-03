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

    Theme {
        id: theme
        mode: root.cfg.themeMode
        surfaceOpacity: root.cfg.surfaceOpacity / 100
        blurActive: blur.active
    }

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

    readonly property real windowWidth: (island.needsLargeWindow
                                         ? Math.max(theme.expandedWidth, theme.notificationWidth, theme.eventWidth)
                                         : 2 * theme.smallHalfWidth) + 2 * theme.windowSidePad
    readonly property real windowHeight: (island.needsLargeWindow
                                          ? Math.max(theme.expandedHeight, theme.notificationHeight)
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

        x: Math.round(root.screenRect.x + (root.screenRect.width - width) / 2)
        y: Math.round(root.screenRect.y + root.cfg.topMargin - theme.windowTopPad)

        mainItem: Item {
            width: Math.round(root.windowWidth)
            height: Math.round(root.windowHeight)

            Island {
                id: island
                anchors.fill: parent
                theme: theme
                backend: backend
                manager: activities
                showClock: root.cfg.showClock
                hoverDelay: root.cfg.hoverDelay
                collapseDelay: root.cfg.collapseDelay
                showMediaModule: root.cfg.showMediaModule
                showSystemModule: root.cfg.showSystemModule
                showVolumeModule: root.cfg.showVolumeModule
                showNotificationModule: root.cfg.showNotificationModule
                pageOrder: root.cfg.pageOrder
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
                    { key: "quicksettings", icon: "configure", title: Lang.i18n("Controls"), component: quickSettingsPage, visible: root.cfg.showQuickSettings },
                    { key: "tools", icon: "chronometer", title: Lang.i18n("Tools"), component: toolsPage, visible: root.cfg.showTools },
                    { key: "calendar", icon: "view-calendar", title: Lang.i18n("Calendar"), component: calendarPage,
                      visible: root.cfg.showCalendar && calendarProviderLoader.item !== null },
                    { key: "notes", icon: "view-pim-notes", title: Lang.i18n("Notes"), component: notesPage, visible: root.cfg.showNotes },
                    { key: "clipboard", icon: "edit-paste", title: Lang.i18n("Clipboard"), component: clipboardPage,
                      visible: root.cfg.showClipboard && root.clipboardBackend !== null },
                    { key: "devices", icon: "network-bluetooth", title: Lang.i18n("Devices"), component: devicesPage,
                      visible: root.cfg.showDevicesModule && ((root.bluetoothBackend && root.bluetoothBackend.available) || root.deviceList.length > 0) }
                ]
            }
        }
    }

    // ---- optional native blur -------------------------------------------------
    // BlurBridge.qml imports the native module; if it is not installed the
    // Loader simply errors out and we keep the opaque fallback.
    Loader {
        id: blur
        readonly property bool active: status === Loader.Ready && item && item.available
        source: root.cfg.blurEnabled ? "BlurBridge.qml" : ""
        onLoaded: {
            item.window = dialog;
            item.rect = Qt.binding(() => island.surfaceRect);
            item.radius = Qt.binding(() => island.surfaceRadius);
            item.rect2 = Qt.binding(() => island.bubbleRect);
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
