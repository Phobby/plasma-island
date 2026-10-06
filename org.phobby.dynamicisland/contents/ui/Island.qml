/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Island: state machine + morphing surface.

      idle          small pill (clock or status dot)
      live          compact view of the primary Live Activity (media: art · title · equalizer)
      split         primary in the pill + secondary in a detached bubble
      notification  banner with icon, title, first line          (queued)
      event         transient system event (charging, Bluetooth…) (queued)
      expanded      paged modules                                (hover)
      dot           a small dot in the pill's place               (dot mode: a click)

    What is live / queued is decided by the ActivityManager. While a banner or
    event is shown, hovering pauses it instead of expanding, so it can be clicked.
    Privacy dots (mic / camera / screen) always sit right of the island.
*/
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras

Item {
    id: island

    required property Theme theme
    // Icons that colour themselves (application and symbolic icons without a
    // colour of their own) take Kirigami's colours: here the island's, not the shell's.
    Kirigami.Theme.inherit: false
    Kirigami.Theme.textColor: theme.text
    Kirigami.Theme.backgroundColor: theme.surface
    Kirigami.Theme.highlightColor: theme.control
    required property PlasmaBackend backend
    property var network: null
    required property ActivityManager manager

    // configuration
    property bool showClock: true
    property int hoverDelay: 120
    property int collapseDelay: 400
    property bool showMediaModule: true
    property bool showSystemModule: true
    property bool showVolumeModule: true
    property bool showNotificationModule: true
    property string systemView: "dynamic"
    signal systemMetricClicked(string key)
    signal settingsRequested()
    // Ambient glow (the colour of the cover, following the music); see AmbientGlow.qml.
    property bool ambientGlow: false
    signal ambientGlowToggled()
    AmbientGlow {
        id: glow
        // not while the island is a dot: nothing of it would be seen
        enabled: island.ambientGlow && !island.dot
        backend: island.backend
    }
    // For who stands beside the island (the companion): the music's beats, while the glow follows
    // them anyway (nobody else starts the listening), and how far what is right of the pill
    // (the split island's bubble, the privacy dots) reaches beyond its edge.
    // The open page asks something and waits for the answer.
    readonly property bool asking: expanded && expandedContent.asking
    readonly property bool musicBeats: glow.following
    signal musicBeat(real strength)
    Connections {
        target: glow
        function onBeat(strength) { island.musicBeat(strength); }
    }
    readonly property real besideRight: (split ? theme.splitGap + theme.bubbleSize : 0)
        + (privacyDots.visible && manager.indicators.length > 0 ? 8 + manager.indicators.length * (theme.privacyDotSize + privacyDots.spacing) + 2 : 0)
    // Provider pages for the expanded view: [{ key, icon, title, component, visible }]
    property var extraPages: []
    property string pageOrder: ""
    // A page that takes dropped files (the Cloud tab): files dragged onto the small island open it there,
    // so that they can be dropped on the page. "" = the small island takes no drops.
    property string dropPage: ""
    // SuggestionProvider: what waits quietly is shown in the open island, and marked on the pill.
    property var suggestions: null
    readonly property bool suggestionHint: suggestions !== null && suggestions.hint
    function filesOver(): void { if (dropPage.length > 0 && !expanded) openPage(dropPage); }

    // ---- dot mode ---------------------------------------------------------------
    // A click on the small island shrinks it to a dot in the same place; a click on the dot
    // brings back the closed pill. Off: a click opens the island, as it always did.
    property bool dotMode: false
    property real dotSize: 15
    // Whether hovering the dot opens the island (it then returns to the dot).
    property bool dotHoverExpand: false
    // Events while it is a dot: 0 = only the dot shows them, 1 = it opens for them and returns, 2 = nothing.
    property int dotEvents: 0
    // An incoming call, an alarm, low battery: opens for them whatever dotEvents says.
    property bool dotCriticalExpand: true
    // It is a dot now (main.qml keeps this across restarts).
    property bool dot: false
    onDotModeChanged: if (!dotMode) dot = false
    // The pointer is still on the island after the click that changed its form: hovering opens
    // nothing until it has left once (the dot's click returns to the *closed* pill).
    property bool hoverSpent: false
    // The pill's content appears after the shape has grown out of the dot.
    property int revealDelay: 0
    readonly property bool calling: primary !== null && primary.category === "call"
    readonly property bool menuOpen: menuLoader.item !== null && menuLoader.item.status === PlasmaExtras.Menu.Open
    function shrink(): void {
        if (!dotMode) return;
        expandTimer.stop();
        hoverSpent = true;
        revealDelay = 0;
        expanded = false;
        dot = true;
        spentTimer.restart();
    }
    function unshrink(): void {
        expandTimer.stop();
        hoverSpent = true;
        revealDelay = 170;
        dot = false;
        spentTimer.restart();
    }
    // What the dot says: a privacy indicator's colour, a recording, something critical waiting,
    // something waiting; nothing = the island's own body.
    readonly property color dotColor: manager.indicators.length > 0 ? manager.indicators[0].color
                                    : primary !== null && primary.category === "recording" ? theme.danger
                                    : dotEvents !== 2 && manager.waitingCritical ? "#ffd60a"
                                    : dotEvents !== 2 && (manager.waiting > 0 || suggestionHint) ? theme.accent
                                    : dotEvents !== 2 && primary !== null ? theme.accent
                                    : "transparent"
    // A running live activity pulses.
    readonly property bool dotPulse: mode === "dot" && dotEvents !== 2 && (primary !== null || suggestionHint)
    Binding { target: island.manager; property: "quiet"; value: island.dot && island.dotEvents !== 1 }
    Binding { target: island.manager; property: "quietCritical"; value: island.dotCriticalExpand }

    // ---- state ----------------------------------------------------------------
    property bool expanded: false
    // Kept for the notification layer (the ActivityManager owns the queue).
    readonly property var currentEvent: manager.currentEvent
    readonly property var currentNotification: currentEvent?.kind === "notification" ? currentEvent.notification : null
    readonly property var primary: manager.primary
    readonly property var secondary: manager.secondary

    readonly property bool hovered: hover.hovered || bubbleHover.hovered || dotHover.hovered
    // A text field (quick reply) needs keyboard focus: see main.qml.
    readonly property bool wantsKeyboard: expanded && expandedContent.interacting
    readonly property string mode: expanded ? "expanded"
                                 : currentEvent ? (currentEvent.kind === "notification" ? "notification" : "event")
                                 : dot && !(dotCriticalExpand && calling) ? "dot"
                                 : secondary ? "split"
                                 : primary ? "live"
                                 : "idle"

    readonly property real liveWidth: primary && primary.compactWidth > 0 ? primary.compactWidth : theme.liveWidth
    // A page may ask for a wider island (the Habits year).
    readonly property bool wide: expanded && expandedContent.wide
    readonly property real expandedWidth: wide ? theme.wideWidth : theme.expandedWidth
    // Or for a taller one (the AI tab's conversation).
    readonly property bool tall: expanded && expandedContent.tall
    readonly property real expandedHeight: tall ? theme.tallHeight : theme.expandedHeight
    readonly property real targetWidth: mode === "expanded" ? expandedWidth
                                      : mode === "notification" ? theme.notificationWidth
                                      : mode === "event" ? (currentEvent.width || theme.eventWidth)
                                      : mode === "dot" ? dotSize
                                      : mode === "split" ? theme.splitMainWidth
                                      : mode === "live" ? liveWidth
                                      : theme.pillWidth
    readonly property real targetHeight: mode === "expanded" ? expandedHeight
                                       : mode === "notification" ? theme.notificationHeight
                                       : mode === "event" ? (currentEvent.height || theme.eventHeight)
                                       : mode === "dot" ? dotSize
                                       : theme.pillHeight
    readonly property real targetRadius: mode === "expanded" ? theme.expandedRadius
                                       : mode === "notification" ? theme.notificationRadius
                                       : mode === "event" ? theme.rounded(Math.min((currentEvent.height || theme.eventHeight) / 2, 26))
                                       : mode === "dot" ? dotSize / 2
                                       : theme.rounded(theme.pillHeight / 2)

    // The window has to stay large while the surface is still bigger than
    // the small window (i.e. until the collapse animation has finished).
    readonly property bool needsLargeWindow: mode === "expanded" || mode === "notification" || mode === "event"
                                             || surface.height > theme.pillHeight + 1
                                             || surface.width / 2 > theme.smallHalfWidth - theme.privacyAreaWidth
    // The window widens when a page first asks for it and stays so until the
    // island is small again, so it is never resized in the middle of a morph.
    property bool needsWideWindow: false
    onWideChanged: if (wide) needsWideWindow = true
    // The same downwards.
    property bool needsTallWindow: false
    onTallChanged: if (tall) needsTallWindow = true
    onNeedsLargeWindowChanged: if (!needsLargeWindow) { needsWideWindow = false; needsTallWindow = false; }
    // Geometry of the glass surfaces in window coordinates (for the blur region).
    readonly property rect surfaceRect: Qt.rect(surface.x, surface.y, surface.width, surface.height)
    readonly property real surfaceRadius: surface.radius
    // Where the island takes the pointer: its shape (see main.qml, native/windowmask.h).
    // The dot is smaller than a comfortable target: it takes the pointer a little around itself too.
    readonly property real dotTarget: 24
    readonly property rect hitRect: mode === "dot" ? Qt.rect(surface.x - Math.max(0, dotTarget - surface.width) / 2,
                                                             surface.y - Math.max(0, dotTarget - surface.height) / 2,
                                                             Math.max(dotTarget, surface.width), Math.max(dotTarget, surface.height))
                                                   : surfaceRect
    readonly property real hitRadius: mode === "dot" ? Math.min(hitRect.width, hitRect.height) / 2 : surfaceRadius
    // Draws that region's outline (DYNAMICISLAND_DEBUG_REGION in the shell's environment).
    property bool debugRegion: false
    readonly property rect bubbleRect: bubble.opacity > 0.05 ? Qt.rect(bubble.x, bubble.y, bubble.width, bubble.height) : Qt.rect(0, 0, 0, 0)

    Binding { target: island.manager; property: "holdEvents"; value: island.expanded }
    Binding { target: island.manager; property: "hovered"; value: island.hovered }
    onCurrentEventChanged: {
        if (!currentEvent && hovered && !expanded) expandTimer.restart();
        // Timer done / alarm: the island shakes like the iPhone's.
        if (currentEvent && currentEvent.shake) shakeAnim.restart();
    }

    SequentialAnimation {
        id: shakeAnim
        loops: 2
        NumberAnimation { target: surface; property: "anchors.horizontalCenterOffset"; to: 9; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: surface; property: "anchors.horizontalCenterOffset"; to: -9; duration: 90; easing.type: Easing.InOutQuad }
        NumberAnimation { target: surface; property: "anchors.horizontalCenterOffset"; to: 5; duration: 80; easing.type: Easing.InOutQuad }
        NumberAnimation { target: surface; property: "anchors.horizontalCenterOffset"; to: -3; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: surface; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60; easing.type: Easing.OutQuad }
    }

    // ---- the size setting: crisp text ------------------------------------------
    // The island is scaled as a whole (main.qml). Plasma draws text with native
    // rendering, glyphs made for one size, and those smear when scaled; Qt's own
    // rendering scales cleanly. So while the size is not 100% every text item
    // is switched over, and back at 100%. Items come and go (pages, lists), hence
    // the walk repeats while the island shows more than the clock; never at 100%.
    Text { textFormat: Text.PlainText; id: textProbe; visible: false }
    readonly property bool scaled: theme.scale !== 1
    property bool retyped: false
    function retype(item: Item, type: int): void {
        if (item.renderType !== undefined && item.renderType !== type) item.renderType = type;
        const kids = item.children;
        for (let i = 0; i < kids.length; ++i) retype(kids[i], type);
    }
    function retypeAll(): void {
        if (!scaled && !retyped) return;
        retype(island, scaled ? Text.QtRendering : textProbe.renderType);
        retyped = scaled;
    }
    onScaledChanged: retypeAll()
    onModeChanged: if (scaled) Qt.callLater(retypeAll)
    Component.onCompleted: retypeAll()
    Timer {
        interval: 350
        repeat: true
        running: island.scaled && island.mode !== "idle"
        onTriggered: island.retypeAll()
    }

    // ---- hover → expand / collapse --------------------------------------------
    Timer {
        id: expandTimer
        interval: island.hoverDelay
        onTriggered: if (island.hovered && !island.currentEvent && !island.hoverSpent
                             && (island.mode !== "dot" || island.dotHoverExpand)) {
            // The pointer came to click the pill and the island opened under it: for a moment, and
            // while the pointer rests, that click still means the pill (see graceArea).
            if (island.dotMode && island.mode !== "dot") {
                island.gracePos = hover.point.scenePosition;
                island.grace = true;
                graceTimer.restart();
            }
            island.expanded = true;
        }
    }
    property bool grace: false
    property point gracePos: Qt.point(0, 0)
    Timer {
        id: graceTimer
        interval: 700
        onTriggered: island.grace = false
    }
    Timer {
        id: collapseTimer
        interval: island.collapseDelay
        onTriggered: if (!island.hovered && !expandedContent.interacting && !expandedContent.holding && !island.menuOpen) island.expanded = false
    }
    // A menu the page opened has closed: close like after the pointer left.
    Connections {
        target: expandedContent
        function onHoldingChanged() {
            if (!expandedContent.holding && island.expanded && !island.hovered) collapseTimer.restart();
        }
    }
    onHoveredChanged: {
        if (hovered) {
            collapseTimer.stop();
            if (!currentEvent && !expanded) expandTimer.restart();
        } else {
            spentTimer.restart();
            expandTimer.stop();
            if (expanded) collapseTimer.restart();
        }
    }
    // The pointer has really left (not only the form changing under it): hovering opens again.
    Timer {
        id: spentTimer
        interval: 250
        onTriggered: if (!island.hovered) island.hoverSpent = false
    }
    // Opened by a click (handle icon / tap) without the pointer on it.
    Timer {
        id: unattendedCollapseTimer
        interval: 3000
        onTriggered: if (!island.hovered && !expandedContent.holding) island.expanded = false
    }
    onExpandedChanged: {
        if (!expanded) grace = false;
        if (expanded) {
            expandedContent.selectDefaultPage();
            if (!hovered) unattendedCollapseTimer.restart();
        }
    }
    // Expanded on a page of its choice (an event leads there, e.g. the habits' evening review).
    function openPage(key: string): void {
        expandTimer.stop();
        if (expanded) {
            expandedContent.showPage(key);
            return;
        }
        expanded = true;
        expandedContent.jumpTo(key);
    }

    // ---- morph animation ------------------------------------------------------
    onTargetWidthChanged: Qt.callLater(morph)
    onTargetHeightChanged: Qt.callLater(morph)
    onTargetRadiusChanged: Qt.callLater(morph)

    function morph(): void {
        const grow = targetWidth * targetHeight >= surface.width * surface.height;
        morphAnim.stop();
        // To the dot: the content fades first, then the shape shrinks; out of it the shape
        // grows with the usual spring and the content follows (revealDelay).
        const toDot = mode === "dot";
        preMorph.duration = toDot ? 90 : 0;
        const dur = toDot ? 280 : grow ? theme.morphDuration : theme.collapseDuration;
        wAnim.duration = hAnim.duration = rAnim.duration = dur;
        wAnim.easing.type = hAnim.easing.type = grow ? Easing.OutBack : Easing.OutCubic;
        wAnim.to = targetWidth;
        hAnim.to = targetHeight;
        rAnim.to = targetRadius;
        morphAnim.start();
    }

    // The roundness setting changed: the surface at rest takes the new radius.
    Connections {
        target: island.theme
        function onRoundnessChanged() { if (!morphAnim.running) surface.radius = island.targetRadius; }
    }

    SequentialAnimation {
        id: morphAnim
        PauseAnimation { id: preMorph; duration: 0 }
        ParallelAnimation {
            NumberAnimation { id: wAnim; target: surface; property: "width"; easing.overshoot: island.theme.overshoot }
            NumberAnimation { id: hAnim; target: surface; property: "height"; easing.overshoot: island.theme.overshoot }
            NumberAnimation { id: rAnim; target: surface; property: "radius"; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: island.revealDelay = 0 }
    }

    // ---- surface ----------------------------------------------------------------
    IslandShape {
        id: surface
        theme: island.theme
        // the dot under the pointer glows (and grows a little); otherwise the music's glow
        glowShown: island.mode === "dot" ? island.dotGlow : glow.shown
        glowStrength: island.mode === "dot" ? 0.7 : glow.strength
        glowColor: island.mode === "dot" ? (island.dotColor.a > 0 ? island.dotColor : island.theme.accent) : glow.color
        scale: island.mode === "dot" && island.hovered ? 1.22 : 1
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.005 } }
        // a hint of the colour on the small pill, less on the large card
        glowTint: island.mode === "expanded" ? 0.06 : 0.13
        bodyScale: glow.visibleAtAll ? glow.bodyScale : 1
        anchors.horizontalCenter: parent.horizontalCenter
        // smaller than the pill (the dot): in the middle of where the pill is
        y: island.theme.windowTopPad + Math.max(0, (island.theme.pillHeight - height) / 2)
        width: island.theme.pillWidth
        height: island.theme.pillHeight
        radius: island.theme.rounded(island.theme.pillHeight / 2)

        HoverHandler {
            id: hover
            onPointChanged: {
                if (!island.grace) return;
                const p = point.scenePosition;
                if (Math.abs(p.x - island.gracePos.x) > 8 || Math.abs(p.y - island.gracePos.y) > 8) island.grace = false;
            }
        }

        TapHandler {
            enabled: island.mode === "idle" || island.mode === "live" || island.mode === "split"
            onTapped: {
                expandTimer.stop();
                if (island.dotMode) island.shrink();
                else island.expanded = true;
            }
        }
        // (The open island does not shrink for a click on its empty room: a page being filled in
        // would be lost to a click beside a field. Its own button does that: ExpandedContent.)
        // Right click where nothing else takes it: the island's own menu.
        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.WithinBounds
            enabled: island.dotMode && island.mode !== "notification" && island.mode !== "event" && island.mode !== "dot"
            onTapped: island.showMenu()
        }
        DropArea {
            objectName: "islandDrop"
            anchors.fill: parent
            enabled: island.dropPage.length > 0 && !island.expanded
            keys: ["text/uri-list"]
            // not taken here: the island opens, and the page under the pointer takes the drop
            onEntered: drag => { drag.accepted = false; island.filesOver(); }
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
                SequentialAnimation {
                    PauseAnimation { duration: island.revealDelay }
                    NumberAnimation {
                        duration: island.theme.fadeDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: island.theme.morphDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        // dot: what it has to say, as a colour
        Layer {
            layerMode: "dot"
            width: island.dotSize
            height: island.dotSize
            Rectangle {
                id: dotCore
                objectName: "dotCore"
                anchors.centerIn: parent
                width: Math.max(4, island.dotSize * 0.5)
                height: width
                radius: width / 2
                color: island.dotColor
                visible: island.dotColor.a > 0
                SequentialAnimation on opacity {
                    running: island.dotPulse
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.25; duration: 550; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 550; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: 1400 }
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
            id: eventLayer
            layerMode: "event"
            // an event that asks something has buttons of its own
            readonly property bool asking: island.mode === "event" && Array.isArray(island.currentEvent.buttons)
            width: island.currentEvent?.width || island.theme.eventWidth
            height: island.currentEvent?.height || island.theme.eventHeight

            EventBanner {
                anchors.fill: parent
                visible: !eventLayer.asking
                theme: island.theme
                event: island.mode === "event" && !eventLayer.asking ? island.currentEvent : null
                onActivated: island.manager.activateEvent()
                onDismissed: island.manager.closeEvent()
            }
            SuggestionBanner {
                anchors.fill: parent
                visible: eventLayer.asking
                theme: island.theme
                event: eventLayer.asking ? island.currentEvent : null
                onChosen: index => island.manager.chooseEvent(index)
                onDismissed: island.manager.closeEvent()
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
            width: island.expandedWidth
            height: island.expandedHeight

            ExpandedContent {
                id: expandedContent
                objectName: "expandedContent"
                anchors.fill: parent
                anchors.margins: island.theme.padding
                anchors.topMargin: island.theme.padding * 0.7
                theme: island.theme
                backend: island.backend
                network: island.network
                manager: island.manager
                active: island.expanded
                showMediaModule: island.showMediaModule
                showSystemModule: island.showSystemModule
                showVolumeModule: island.showVolumeModule
                showNotificationModule: island.showNotificationModule
                showClock: island.showClock
                extraPages: island.extraPages
                pageOrder: island.pageOrder
                systemView: island.systemView
                onSystemMetricClicked: key => island.systemMetricClicked(key)
                onSettingsRequested: island.settingsRequested()
                dotMode: island.dotMode
                onShrinkRequested: island.shrink()
                suggestions: island.suggestions
                ambientGlow: island.ambientGlow
                onAmbientGlowToggled: island.ambientGlowToggled()
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
        radius: island.theme.rounded(width / 2)
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

    // ---- the dot's target: a little larger than the dot ---------------------------------
    Item {
        id: dotArea
        objectName: "dotArea"
        visible: island.mode === "dot"
        x: island.hitRect.x; y: island.hitRect.y; width: island.hitRect.width; height: island.hitRect.height
        z: 5
        HoverHandler { id: dotHover }
        TapHandler { onTapped: island.unshrink() }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: island.showMenu()
        }
    }
    // The click that was on its way to the pill when the island opened under the pointer.
    MouseArea {
        id: graceArea
        objectName: "graceArea"
        visible: island.grace && island.mode === "expanded"
        x: surface.x; y: surface.y; width: surface.width; height: surface.height
        z: 4
        onClicked: island.shrink()
    }
    // the glow of the hovered dot fades in and out
    property real dotGlow: mode === "dot" && hovered ? 1 : 0
    Behavior on dotGlow { NumberAnimation { duration: 160 } }

    // ---- the island's menu (right click) ------------------------------------------------
    function showMenu(): void {
        menuLoader.active = true;
        menuLoader.item.openRelative();
    }
    Loader {
        id: menuLoader
        active: false
        sourceComponent: PlasmaExtras.Menu {
            visualParent: island.mode === "dot" ? dotArea : surface
            placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
            PlasmaExtras.MenuItem {
                text: island.dot ? Lang.i18n("Back to pill") : Lang.i18n("Shrink to dot")
                icon: island.dot ? "window-restore-symbolic" : "window-minimize-symbolic"
                onClicked: island.dot ? island.unshrink() : island.shrink()
            }
            PlasmaExtras.MenuItem {
                text: Lang.i18n("Settings")
                icon: "configure-symbolic"
                onClicked: island.settingsRequested()
            }
        }
    }

    // the pointer region, outlined (for looking at it)
    Rectangle {
        visible: island.debugRegion
        x: island.hitRect.x; y: island.hitRect.y; width: island.hitRect.width; height: island.hitRect.height
        radius: Math.min(island.hitRadius, Math.min(width, height) / 2)
        color: "transparent"; border.width: 1; border.color: "red"; z: 100
    }
    Rectangle {
        visible: island.debugRegion && island.bubbleRect.width > 0
        x: island.bubbleRect.x; y: island.bubbleRect.y; width: island.bubbleRect.width; height: island.bubbleRect.height
        radius: Math.min(width, height) / 2
        color: "transparent"; border.width: 1; border.color: "red"; z: 100
    }

    // A suggestion waits: a small mark on the pill's corner (the dot pulses instead).
    Rectangle {
        objectName: "suggestionHint"
        visible: island.suggestionHint && (island.mode === "idle" || island.mode === "live" || island.mode === "split")
        width: 7; height: 7; radius: 3.5
        x: surface.x + surface.width - 9
        y: surface.y + 1
        color: island.theme.accent
        border.width: 1
        border.color: island.theme.surface
        z: 6
        SequentialAnimation on opacity {
            running: parent.visible
            loops: 3
            NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
        }
    }

    // ---- privacy dots (mic = orange, camera = green, screen = red) --------------
    Row {
        id: privacyDots
        spacing: 4
        x: (bubble.visible ? bubble.x + bubble.width : surface.x + surface.width) + 8
        y: island.theme.windowTopPad + island.theme.pillHeight / 2 - height / 2
        visible: island.mode !== "expanded" && island.mode !== "dot"
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
