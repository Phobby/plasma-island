/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Island: state machine + morphing surface.

      idle          small pill (clock or status dot)
      live          compact view of the primary Live Activity (media: art · title · equalizer)
      split         primary in the pill + secondary in a detached bubble
      notification  banner with icon, title, first line          (queued)
      event         transient system event (charging, Bluetooth…) (queued)
      expanded      paged modules                                (hover)

    What is live / queued is decided by the ActivityManager. While a banner or
    event is shown, hovering pauses it instead of expanding, so it can be clicked.
    Privacy dots (mic / camera / screen) always sit right of the island.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: island

    required property Theme theme
    required property PlasmaBackend backend
    required property ActivityManager manager

    // configuration
    property bool showClock: true
    property int hoverDelay: 120
    property int collapseDelay: 400
    property bool showMediaModule: true
    property bool showSystemModule: true
    property bool showVolumeModule: true
    property bool showNotificationModule: true
    // Provider pages for the expanded view: [{ key, icon, title, component, visible }]
    property var extraPages: []

    // ---- state ----------------------------------------------------------------
    property bool expanded: false
    // Kept for the notification layer (the ActivityManager owns the queue).
    readonly property var currentEvent: manager.currentEvent
    readonly property var currentNotification: currentEvent?.kind === "notification" ? currentEvent.notification : null
    readonly property var primary: manager.primary
    readonly property var secondary: manager.secondary

    readonly property bool hovered: hover.hovered || bubbleHover.hovered
    readonly property string mode: expanded ? "expanded"
                                 : currentEvent ? (currentEvent.kind === "notification" ? "notification" : "event")
                                 : secondary ? "split"
                                 : primary ? "live"
                                 : "idle"

    readonly property real liveWidth: primary && primary.compactWidth > 0 ? primary.compactWidth : theme.liveWidth
    readonly property real targetWidth: mode === "expanded" ? theme.expandedWidth
                                      : mode === "notification" ? theme.notificationWidth
                                      : mode === "event" ? (currentEvent.width || theme.eventWidth)
                                      : mode === "split" ? theme.splitMainWidth
                                      : mode === "live" ? liveWidth
                                      : theme.pillWidth
    readonly property real targetHeight: mode === "expanded" ? theme.expandedHeight
                                       : mode === "notification" ? theme.notificationHeight
                                       : mode === "event" ? theme.eventHeight
                                       : theme.pillHeight
    readonly property real targetRadius: mode === "expanded" ? theme.expandedRadius
                                       : mode === "notification" ? theme.notificationRadius
                                       : mode === "event" ? theme.eventHeight / 2
                                       : theme.pillHeight / 2

    // The window has to stay large while the surface is still bigger than
    // the small window (i.e. until the collapse animation has finished).
    readonly property bool needsLargeWindow: mode === "expanded" || mode === "notification" || mode === "event"
                                             || surface.height > theme.pillHeight + 1
                                             || surface.width / 2 > theme.smallHalfWidth - theme.privacyAreaWidth
    // Geometry of the glass surfaces in window coordinates (for the blur region).
    readonly property rect surfaceRect: Qt.rect(surface.x, surface.y, surface.width, surface.height)
    readonly property real surfaceRadius: surface.radius
    readonly property rect bubbleRect: bubble.opacity > 0.05 ? Qt.rect(bubble.x, bubble.y, bubble.width, bubble.height) : Qt.rect(0, 0, 0, 0)

    Binding { target: island.manager; property: "holdEvents"; value: island.expanded }
    Binding { target: island.manager; property: "hovered"; value: island.hovered }
    onCurrentEventChanged: if (!currentEvent && hovered && !expanded) expandTimer.restart()

    // ---- hover → expand / collapse --------------------------------------------
    Timer {
        id: expandTimer
        interval: island.hoverDelay
        onTriggered: if (island.hovered && !island.currentEvent) island.expanded = true
    }
    Timer {
        id: collapseTimer
        interval: island.collapseDelay
        onTriggered: if (!island.hovered && !expandedContent.interacting) island.expanded = false
    }
    onHoveredChanged: {
        if (hovered) {
            collapseTimer.stop();
            if (!currentEvent && !expanded) expandTimer.restart();
        } else {
            expandTimer.stop();
            if (expanded) collapseTimer.restart();
        }
    }
    // Opened by a click (handle icon / tap) without the pointer on it.
    Timer {
        id: unattendedCollapseTimer
        interval: 3000
        onTriggered: if (!island.hovered) island.expanded = false
    }
    onExpandedChanged: {
        if (expanded) {
            expandedContent.selectDefaultPage();
            if (!hovered) unattendedCollapseTimer.restart();
        }
    }

    // ---- morph animation ------------------------------------------------------
    onTargetWidthChanged: Qt.callLater(morph)
    onTargetHeightChanged: Qt.callLater(morph)
    onTargetRadiusChanged: Qt.callLater(morph)

    function morph(): void {
        const grow = targetWidth * targetHeight >= surface.width * surface.height;
        morphAnim.stop();
        const dur = grow ? theme.morphDuration : theme.collapseDuration;
        wAnim.duration = hAnim.duration = rAnim.duration = dur;
        wAnim.easing.type = hAnim.easing.type = grow ? Easing.OutBack : Easing.OutCubic;
        wAnim.to = targetWidth;
        hAnim.to = targetHeight;
        rAnim.to = targetRadius;
        morphAnim.start();
    }

    ParallelAnimation {
        id: morphAnim
        NumberAnimation { id: wAnim; target: surface; property: "width"; easing.overshoot: island.theme.overshoot }
        NumberAnimation { id: hAnim; target: surface; property: "height"; easing.overshoot: island.theme.overshoot }
        NumberAnimation { id: rAnim; target: surface; property: "radius"; easing.type: Easing.OutCubic }
    }

    // ---- surface ----------------------------------------------------------------
    IslandShape {
        id: surface
        theme: island.theme
        anchors.horizontalCenter: parent.horizontalCenter
        y: island.theme.windowTopPad
        width: island.theme.pillWidth
        height: island.theme.pillHeight
        radius: island.theme.pillHeight / 2

        HoverHandler {
            id: hover
        }

        TapHandler {
            enabled: island.mode === "idle" || island.mode === "live" || island.mode === "split"
            onTapped: {
                expandTimer.stop();
                island.expanded = true;
            }
        }

        // Every content layer is laid out at its *final* size and centered, so
        // text never reflows while the surface morphs; the surface clips it.
        component Layer: Item {
            required property string layerMode
            readonly property bool shown: island.mode === layerMode
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.94
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation {
                    duration: island.theme.fadeDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: island.theme.morphDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        // idle
        Layer {
            layerMode: "idle"
            width: island.theme.pillWidth
            height: island.theme.pillHeight

            Clock {
                anchors.centerIn: parent
                visible: island.showClock
                running: parent.visible && island.showClock
                color: island.theme.text
                font.pointSize: island.theme.fontNormal
                font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.centerIn: parent
                visible: !island.showClock
                width: 6
                height: 6
                radius: 3
                color: island.backend.hasMedia ? island.theme.live : island.theme.subText
            }
            // paused media hint on the right
            Kirigami.Icon {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                visible: island.backend.hasMedia && island.backend.isPaused
                source: "media-playback-paused-symbolic"
                color: island.theme.subText
                isMask: true
            }
        }

        // live activity (primary): its own compact component or the generic one
        Layer {
            id: liveLayer
            layerMode: "live"
            readonly property bool shownAlso: island.mode === "split"
            opacity: shown || shownAlso ? 1 : 0
            scale: shown || shownAlso ? 1 : 0.94
            width: island.mode === "split" ? island.theme.splitMainWidth : island.liveWidth
            height: island.theme.pillHeight

            ActivityView {
                anchors.fill: parent
                theme: island.theme
                activity: island.primary
                component: island.primary ? (island.primary.compact ?? genericCompact) : null
            }
        }

        // transient system event
        Layer {
            layerMode: "event"
            width: island.currentEvent?.width || island.theme.eventWidth
            height: island.theme.eventHeight

            EventBanner {
                anchors.fill: parent
                theme: island.theme
                event: island.mode === "event" ? island.currentEvent : null
                onActivated: island.manager.activateEvent()
            }
        }

        // notification banner
        Layer {
            layerMode: "notification"
            width: island.theme.notificationWidth
            height: island.theme.notificationHeight

            NotificationBanner {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 18
                theme: island.theme
                notification: island.currentNotification
                onActivated: island.manager.activateEvent()
                onDismissed: island.manager.dismissEvent()
            }
        }

        // expanded
        Layer {
            layerMode: "expanded"
            width: island.theme.expandedWidth
            height: island.theme.expandedHeight

            ExpandedContent {
                id: expandedContent
                objectName: "expandedContent"
                anchors.fill: parent
                anchors.margins: island.theme.padding
                anchors.topMargin: island.theme.padding * 0.7
                theme: island.theme
                backend: island.backend
                manager: island.manager
                active: island.expanded
                showMediaModule: island.showMediaModule
                showSystemModule: island.showSystemModule
                showVolumeModule: island.showVolumeModule
                showNotificationModule: island.showNotificationModule
                showClock: island.showClock
                extraPages: island.extraPages
            }
        }
    }

    Component { id: genericCompact; ActivityCompact {} }
    Component { id: genericMinimal; ActivityMinimal {} }

    // ---- split: secondary activity in a detached bubble ---------------------------
    // The bubble is tucked under the right end of the pill and "drips" out with
    // a spring; a neck between them thins out while they separate.
    readonly property bool split: mode === "split"
    readonly property real bubbleRestX: surface.x + surface.width + theme.splitGap
    readonly property real bubbleTuckedX: surface.x + surface.width - bubble.width

    Rectangle {
        id: neck
        readonly property real distance: Math.max(0, bubble.x - (surface.x + surface.width))
        readonly property real thickness: island.theme.pillHeight * 0.55 * Math.max(0, 1 - distance / (island.theme.splitGap * 0.85))
        visible: bubble.visible && thickness > 1
        x: surface.x + surface.width - island.theme.pillHeight / 2
        width: bubble.x + bubble.width / 2 - x
        y: surface.y + (island.theme.pillHeight - thickness) / 2
        height: thickness
        radius: height / 2
        color: island.theme.bodyMid
        z: -1
    }

    IslandShape {
        id: bubble
        theme: island.theme
        z: -1
        width: island.theme.bubbleSize
        height: island.theme.bubbleSize
        radius: width / 2
        y: surface.y
        x: island.split ? island.bubbleRestX : island.bubbleTuckedX
        scale: island.split ? 1 : 0.55
        opacity: island.split ? 1 : 0
        visible: opacity > 0.01
        Behavior on x { SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.2 } }
        Behavior on scale { SpringAnimation { spring: 3.2; damping: 0.3; epsilon: 0.005 } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        HoverHandler { id: bubbleHover }
        TapHandler {
            onTapped: {
                expandTimer.stop();
                island.expanded = true;
            }
        }

        // Keeps showing the last secondary while the bubble merges back.
        ActivityView {
            id: bubbleView
            anchors.fill: parent
            theme: island.theme
            property var lastActivity: null
            activity: lastActivity
            component: lastActivity ? (lastActivity.minimal ?? genericMinimal) : null
            Connections {
                target: island
                function onSecondaryChanged() { if (island.secondary) bubbleView.lastActivity = island.secondary; }
            }
        }
    }

    // ---- privacy dots (mic = orange, camera = green, screen = red) --------------
    Row {
        id: privacyDots
        spacing: 4
        x: (bubble.visible ? bubble.x + bubble.width : surface.x + surface.width) + 8
        y: surface.y + island.theme.pillHeight / 2 - height / 2
        visible: island.mode !== "expanded"
        Repeater {
            model: island.manager.indicators
            delegate: Rectangle {
                required property var modelData
                width: island.theme.privacyDotSize
                height: width
                radius: width / 2
                color: modelData.color
                scale: 0
                Component.onCompleted: scale = 1
                Behavior on scale { SpringAnimation { spring: 4; damping: 0.3; epsilon: 0.01 } }
            }
        }
    }
}
