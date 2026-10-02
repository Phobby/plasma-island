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

    Plasmoid.icon: "view-media-track"
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation
    toolTipMainText: i18n("Dynamic Island")
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
    Binding { target: root.calendarBackend; property: "refreshMinutes"; value: root.cfg.calendarRefreshMinutes; when: root.calendarBackend !== null }
    Connections {
        target: root.calendarBackend
        function onStatusJsonChanged() { root.cfg.calendarStatus = root.calendarBackend.statusJson; }
    }
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
    readonly property var kdeconnectBackend: kdeconnectLoader.item

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
                list.push({ icon: bt.iconFor(d), name: d.name, battery: bt.batteryOf(d), charging: false, detail: i18n("Bluetooth") });
            }
        }
        const kc = root.kdeconnectBackend;
        if (kc) {
            for (const p of kc.phones) {
                list.push({ icon: p.icon, name: p.name, battery: p.charge, charging: p.charging, detail: i18n("KDE Connect") });
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
            core: root.cfg.showUpdates ? root.core : null
            backend: root.plasmaBackend
            showVolume: root.cfg.showVolumeModule
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

    Component {
        id: calendarPage
        CalendarPage {
            theme: root.islandTheme
            provider: calendarProviderLoader.item
            onConfigureRequested: Plasmoid.internalAction("configure").trigger()
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
                systemView: root.cfg.systemView === 0 ? "fixed" : "dynamic"
                // A System card was clicked: btop with only that metric's graph.
                onSystemMetricClicked: key => {
                    if (root.core) root.core.startDetached("sh", [String(Qt.resolvedUrl("../scripts/btop-view.sh")).replace(/^file:\/\//, ""), key]);
                }
                extraPages: [
                    { key: "quicksettings", icon: "configure", title: i18n("Controls"), component: quickSettingsPage, visible: root.cfg.showQuickSettings },
                    { key: "tools", icon: "chronometer", title: i18n("Tools"), component: toolsPage, visible: root.cfg.showTools },
                    { key: "calendar", icon: "view-calendar", title: i18n("Calendar"), component: calendarPage,
                      visible: root.cfg.showCalendar && calendarProviderLoader.item !== null },
                    { key: "devices", icon: "network-bluetooth", title: i18n("Devices"), component: devicesPage,
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
            text: island.expanded ? i18n("Collapse Island") : i18n("Expand Island")
            icon.name: island.expanded ? "collapse" : "expand"
            onTriggered: island.expanded = !island.expanded
        }
    ]
}
