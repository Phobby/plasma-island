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
                                         ? Math.max(theme.expandedWidth, theme.notificationWidth)
                                         : Math.max(theme.liveWidth, theme.pillWidth)) + 2 * theme.windowSidePad
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
                showClock: root.cfg.showClock
                showNotifications: root.cfg.showNotifications
                notificationDuration: root.cfg.notificationDuration
                hoverDelay: root.cfg.hoverDelay
                collapseDelay: root.cfg.collapseDelay
                showMediaModule: root.cfg.showMediaModule
                showSystemModule: root.cfg.showSystemModule
                showVolumeModule: root.cfg.showVolumeModule
                showNotificationModule: root.cfg.showNotificationModule
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
