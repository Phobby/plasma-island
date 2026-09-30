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
        eventDuration: root.cfg.eventDuration
        notificationDuration: root.cfg.notificationDuration
    }

    // Every provider feeds the manager independently.
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
            doNotDisturb: dndBackend.active
        }
        PowerProvider {
            manager: activities
            backend: backend
            power: powerBackend
            theme: theme
            enabled: root.cfg.showPowerEvents
            lowThreshold: root.cfg.lowBatteryThreshold
            criticalThreshold: root.cfg.criticalBatteryThreshold
        }
        BluetoothProvider {
            manager: activities
            bluetooth: bluetoothBackend
            theme: theme
            enabled: root.cfg.showBluetoothEvents
            lowBattery: root.cfg.deviceBatteryThreshold
        }
        OsdProvider {
            manager: activities
            backend: backend
            display: displayBackend
            theme: theme
            enabled: root.cfg.showOsdEvents
        }
        KeyboardProvider {
            manager: activities
            keyboard: keyboardBackend
            theme: theme
            enabled: root.cfg.showKeyboardEvents
        }
        NetworkProvider {
            manager: activities
            network: networkBackend
            theme: theme
            enabled: root.cfg.showNetworkEvents
        }
        DndProvider {
            manager: activities
            dnd: dndBackend
            theme: theme
            enabled: root.cfg.showDndEvents
            missed: notificationProvider.missedWhileDnd
        }
        RecordingProvider {
            manager: activities
            theme: theme
            tasks: tasksBackend
            core: root.core
            enabled: root.cfg.showRecording
        }
        PrivacyProvider {
            manager: activities
            backend: backend
            theme: theme
            core: root.core
            enabled: root.cfg.showPrivacy
        }
        JobsProvider {
            manager: activities
            jobs: jobsBackend
            theme: theme
            enabled: root.cfg.showJobs
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
        CalendarProvider {
            manager: activities
            calendar: calendarBackend
            theme: theme
            leadMinutes: root.cfg.calendarLeadMinutes
            enabled: root.cfg.showCalendar
        }
        UnlockProvider {
            manager: activities
            theme: theme
            core: root.core
            enabled: root.cfg.showUnlock
        }
    }

    // ---- native core (optional: native/core) ------------------------------------
    Loader {
        id: coreLoader
        source: "NativeBridge.qml"
        onStatusChanged: if (status === Loader.Error) {
            console.info("org.phobby.dynamicisland: native core not installed; screen recording, privacy indicators, unlock, D-Bus API and updates are disabled");
        }
    }
    readonly property var core: coreLoader.status === Loader.Ready ? coreLoader.item : null

    // Private-API backends (see PlasmaBackend.qml / backend/).
    PowerBackend { id: powerBackend }
    BluetoothBackend { id: bluetoothBackend }
    DisplayBackend { id: displayBackend }
    KeyboardBackend { id: keyboardBackend }
    NetworkBackend { id: networkBackend }
    DndBackend { id: dndBackend }
    TasksBackend { id: tasksBackend }
    JobsBackend { id: jobsBackend }
    CalendarBackend { id: calendarBackend; enabled: root.cfg.showCalendar }

    // Timer / alarm sound (QtMultimedia; optional).
    Loader {
        id: soundLoader
        source: "SoundPlayer.qml"
    }
    readonly property var sound: soundLoader.status === Loader.Ready ? soundLoader.item : null

    // Everything shown on the "Devices" page.
    readonly property var deviceList: {
        const list = [];
        for (const d of bluetoothBackend.connectedDevices) {
            list.push({ icon: bluetoothBackend.iconFor(d), name: d.name, battery: bluetoothBackend.batteryOf(d), charging: false, detail: i18n("Bluetooth") });
        }
        return list;
    }

    Component {
        id: toolsPage
        ToolsPage {
            theme: theme
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
            theme: theme
            devices: root.deviceList
            lowBattery: root.cfg.deviceBatteryThreshold
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

    PlasmaCore.Dialog {
        id: dialog

        type: PlasmaCore.Dialog.Notification
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
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
                extraPages: [
                    { key: "tools", icon: "chronometer", title: i18n("Tools"), component: toolsPage, visible: root.cfg.showTools },
                    { key: "devices", icon: "network-bluetooth", title: i18n("Devices"), component: devicesPage,
                      visible: root.cfg.showDevicesModule && (bluetoothBackend.available || root.deviceList.length > 0) }
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
