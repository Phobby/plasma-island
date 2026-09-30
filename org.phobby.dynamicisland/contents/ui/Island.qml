/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Island: state machine + morphing surface.

      idle          small pill (clock or status dot)
      live          wider pill: album art · title · equalizer   (media playing)
      notification  banner with icon, title, first line          (queued)
      expanded      paged modules                                (hover)

    Priority: expanded > notification > live > idle. While a banner is shown,
    hovering pauses it instead of expanding, so it can be clicked.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: island

    required property Theme theme
    required property PlasmaBackend backend

    // configuration
    property bool showClock: true
    property bool showNotifications: true
    property int notificationDuration: 4000
    property int hoverDelay: 120
    property int collapseDelay: 400
    property bool showMediaModule: true
    property bool showSystemModule: true
    property bool showVolumeModule: true
    property bool showNotificationModule: true

    // ---- state ----------------------------------------------------------------
    property bool expanded: false
    property var currentNotification: null
    property var queue: []

    readonly property bool hovered: hover.hovered
    readonly property string mode: expanded ? "expanded"
                                 : currentNotification ? "notification"
                                 : backend.isPlaying && showMediaModule ? "live"
                                 : "idle"

    readonly property real targetWidth: mode === "expanded" ? theme.expandedWidth
                                      : mode === "notification" ? theme.notificationWidth
                                      : mode === "live" ? theme.liveWidth
                                      : theme.pillWidth
    readonly property real targetHeight: mode === "expanded" ? theme.expandedHeight
                                       : mode === "notification" ? theme.notificationHeight
                                       : theme.pillHeight
    readonly property real targetRadius: mode === "expanded" ? theme.expandedRadius
                                       : mode === "notification" ? theme.notificationRadius
                                       : theme.pillHeight / 2

    // The window has to stay large while the surface is still bigger than
    // the small window (i.e. until the collapse animation has finished).
    readonly property bool needsLargeWindow: mode === "expanded" || mode === "notification"
                                             || surface.height > theme.pillHeight + 1
                                             || surface.width > theme.liveWidth + theme.windowSidePad
    // Geometry of the glass surface in window coordinates (for the blur region).
    readonly property rect surfaceRect: Qt.rect(surface.x, surface.y, surface.width, surface.height)
    readonly property real surfaceRadius: surface.radius

    // ---- notifications queue --------------------------------------------------
    function enqueue(n: var): void {
        if (!showNotifications) return;
        queue.push(n);
        if (!currentNotification && !expanded) showNext();
    }

    function showNext(): void {
        if (queue.length === 0) {
            currentNotification = null;
            if (hovered) expandTimer.restart();
            return;
        }
        currentNotification = queue.shift();
        bannerTimer.restart();
    }

    function dismissBanner(): void {
        bannerTimer.stop();
        currentNotification = null;
        if (queue.length > 0) nextBannerTimer.restart();
        else if (hovered) expandTimer.restart();
    }

    Connections {
        target: island.backend
        function onNotificationArrived(n) { island.enqueue(n); }
    }

    Timer {
        id: bannerTimer
        interval: island.notificationDuration
        onTriggered: island.hovered ? restart() : island.dismissBanner()
    }
    // Small gap so consecutive banners visibly "pulse" back and forth.
    Timer {
        id: nextBannerTimer
        interval: 220
        onTriggered: island.showNext()
    }

    // ---- hover → expand / collapse --------------------------------------------
    Timer {
        id: expandTimer
        interval: island.hoverDelay
        onTriggered: if (island.hovered && !island.currentNotification) island.expanded = true
    }
    Timer {
        id: collapseTimer
        interval: island.collapseDelay
        onTriggered: if (!island.hovered && !expandedContent.interacting) island.expanded = false
    }
    onHoveredChanged: {
        if (hovered) {
            collapseTimer.stop();
            if (!currentNotification && !expanded) expandTimer.restart();
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
        } else if (!currentNotification && queue.length > 0) {
            nextBannerTimer.restart();
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
            enabled: island.mode === "idle" || island.mode === "live"
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

        // live activity
        Layer {
            layerMode: "live"
            width: island.theme.liveWidth
            height: island.theme.pillHeight

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 5
                anchors.rightMargin: 14
                spacing: 8

                AlbumArt {
                    Layout.preferredWidth: island.theme.pillHeight - 10
                    Layout.preferredHeight: island.theme.pillHeight - 10
                    radius: height / 2
                    source: island.backend.artUrl
                    fallbackIcon: island.backend.playerIcon || "media-album-cover"
                    fallbackColor: island.theme.faint
                }
                Text {
                    Layout.fillWidth: true
                    text: island.backend.track
                    color: island.theme.subText
                    font.pointSize: island.theme.fontSmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Equalizer {
                    running: parent.parent.visible && island.backend.isPlaying
                    color: island.theme.live
                    Layout.preferredHeight: 14
                }
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
                onActivated: {
                    island.backend.activateNotification(island.currentNotification.id);
                    island.dismissBanner();
                }
                onDismissed: island.dismissBanner()
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
                active: island.expanded
                showMediaModule: island.showMediaModule
                showSystemModule: island.showSystemModule
                showVolumeModule: island.showVolumeModule
                showNotificationModule: island.showNotificationModule
                showClock: island.showClock
            }
        }
    }
}
