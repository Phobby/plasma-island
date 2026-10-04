/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Expanded island: a header (page tabs + clock) and horizontally paged
    modules. Pages: Media · Control (system + volume) · Notifications.
    Paging keeps the island a fixed, compact size instead of growing into a
    tall panel; switch pages with the tabs, the wheel, or a touchpad swipe.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "WeatherIcons.js" as WeatherIcons

Item {
    id: expanded

    required property Theme theme
    required property PlasmaBackend backend
    property var network: null
    required property ActivityManager manager
    property bool active: false
    property bool showMediaModule: true
    property bool showSystemModule: true
    property bool showVolumeModule: true
    property bool showNotificationModule: true
    property bool showClock: true
    property string systemView: "dynamic"
    signal systemMetricClicked(string key)
    // The gear in the header: the widget's settings.
    signal settingsRequested()
    // Dot mode (Island.qml): a button that shrinks the island to its dot.
    property bool dotMode: false
    signal shrinkRequested()
    // The ambient glow's switch on the Media page.
    property bool ambientGlow: false
    signal ambientGlowToggled()

    // True while the user types a reply: the island keeps keyboard focus
    // and does not collapse.
    property bool interacting: false
    onActiveChanged: if (!active) { interacting = false; holding = false; wide = false; tall = false; wheelKept = false; }
    // A page keeps the island open without the keyboard (e.g. while a menu it opened is shown).
    property bool holding: false
    // A page keeps the wheel for a list of its own (e.g. the places a search
    // found): it scrolls that list and does not turn the page.
    property bool wheelKept: false
    // A page asks for the wider island (Theme.wideWidth). The header keeps its
    // usual width in the middle, so the tabs do not move from under the pointer.
    property bool wide: false
    // A page asks for the taller island (Theme.tallHeight): a conversation needs the room.
    property bool tall: false
    readonly property real headerWidth: wide ? Math.max(0, width - (theme.wideWidth - theme.expandedWidth)) : width

    // Live activities that have no page of their own (media has one).
    readonly property var listedActivities: manager.live.concat(manager.indicators).filter(a => a.listed)
    // Extra pages contributed by providers: [{ key, icon, title, component, visible, label, dot }]
    property var extraPages: []
    // The user's order of the pages (Settings → Layout): comma-separated keys.
    property string pageOrder: ""
    PageCatalog { id: catalog }
    readonly property var order: catalog.normalize(pageOrder)

    readonly property var pages: {
        const p = [];
        if (listedActivities.length > 0) p.push({ key: "activities", icon: "view-list-details", title: Lang.i18n("Activities") });
        if (showMediaModule) p.push({ key: "media", icon: "view-media-track", title: Lang.i18n("Media") });
        // System = information only; the volume slider lives in Controls.
        if (showSystemModule) p.push({ key: "control", icon: "speedometer", title: Lang.i18n("System") });
        if (showNotificationModule) p.push({ key: "notifications", icon: "notifications", title: Lang.i18n("Notifications"), badge: backend.notificationCount });
        for (const e of extraPages) if (e.visible !== false) p.push(e);
        const rank = k => { const i = order.indexOf(k); return i >= 0 ? i : order.length; };
        return p.sort((a, b) => rank(a.key) - rank(b.key));
    }
    // The current page is tracked by KEY, not by index: pages come and go
    // (e.g. "Activities" appears when a stopwatch starts) and an index would
    // then point at a different page.
    property string currentKey: ""
    readonly property var visibleKeys: pages.map(p => p.key)
    property int lastIndex: 0
    readonly property int currentIndex: {
        const i = visibleKeys.indexOf(currentKey);
        return i >= 0 ? i : Math.max(0, Math.min(lastIndex, visibleKeys.length - 1));
    }
    onCurrentIndexChanged: if (visibleKeys.indexOf(currentKey) >= 0) lastIndex = currentIndex
    // The current page itself disappeared: settle on its neighbour.
    onVisibleKeysChanged: if (currentKey !== "" && visibleKeys.length > 0 && visibleKeys.indexOf(currentKey) < 0) {
        currentKey = visibleKeys[Math.max(0, Math.min(lastIndex, visibleKeys.length - 1))];
    }
    // Only user navigation slides; pages appearing/disappearing never animate.
    property bool slide: false

    function showPage(key: string): void {
        if (key === currentKey || visibleKeys.indexOf(key) < 0) return;
        slide = true;
        currentKey = key;
    }

    // Straight to a page, without the slide (the island was opened for it).
    function jumpTo(key: string): void {
        if (visibleKeys.indexOf(key) < 0) return;
        slide = false;
        currentKey = key;
    }

    // All page keys that may exist. The page Repeater uses this list and it only
    // changes when the SET of keys changes, so pages are not torn down (and
    // lose their state) whenever visibility or provider data changes.
    property var allKeys: []
    readonly property string allKeysSignature: ["activities", "media", "control", "notifications"].concat(extraPages.map(e => e.key)).join(",")
    onAllKeysSignatureChanged: allKeys = allKeysSignature.split(",")
    Component.onCompleted: allKeys = allKeysSignature.split(",")

    function componentFor(key: string): var {
        const extra = extraPages.find(e => e.key === key);
        if (extra) return extra.component;
        return key === "media" ? mediaPage : key === "control" ? controlPage
             : key === "activities" ? activitiesPage : notificationsPage;
    }

    // Feed visibility back to the backend so hidden modules cost nothing.
    Binding { target: expanded.backend; property: "systemActive"; value: expanded.active && expanded.currentKey === "control" && expanded.showSystemModule }
    Binding { target: expanded.backend; property: "positionActive"; value: expanded.active && expanded.currentKey === "media" }

    function selectDefaultPage(): void {
        slide = false;
        const has = k => visibleKeys.indexOf(k) >= 0;
        // Open on what the pill was showing: a non-media primary activity → its list.
        if (has("activities") && manager.primary && manager.primary.listed) {
            currentKey = "activities";
        } else if (backend.hasMedia && has("media")) {
            currentKey = "media";
        } else if (!has(currentKey) || currentKey === "media") {
            currentKey = visibleKeys.find(k => k !== "media" && k !== "activities") ?? visibleKeys[0] ?? "";
        }
    }
    function go(delta: int): void {
        const i = Math.max(0, Math.min(visibleKeys.length - 1, currentIndex + delta));
        showPage(visibleKeys[i]);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: expanded.headerWidth
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            // Tabs shrink to fit: a row wider than the island would widen
            // every page with it (pages spill over the right edge).
            Item {
                id: tabsArea
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 24
                clip: true

                readonly property int count: expanded.pages.length
                readonly property real gap: 4
                readonly property real currentFull: currentTitle.width + 36
                // A tab's short label (the weather's temperature) beside its icon, while it is not the current one.
                readonly property real labelWidth: 22
                readonly property int labelled: expanded.pages.filter(p => (p.label ?? "").length > 0 && p.key !== expanded.currentKey).length
                readonly property real fullFit: (count - 1) * (30 + gap) + currentFull + labelled * labelWidth
                // The current tab keeps its title while the others can stay at least 22 px.
                readonly property bool showTitle: count <= 1 || width >= (count - 1) * (22 + gap) + currentFull
                readonly property real otherWidth: width >= fullFit ? 30
                    : showTitle ? Math.floor((width - currentFull - (count - 1) * gap) / (count - 1))
                    : Math.max(16, Math.floor((width - (count - 1) * gap) / Math.max(1, count)))
                readonly property real currentWidth: showTitle ? currentFull : otherWidth

                TextMetrics {
                    id: currentTitle
                    text: expanded.pages[expanded.currentIndex]?.title ?? ""
                    font.pointSize: expanded.theme.fontSmall
                    font.weight: Font.DemiBold
                }

                Row {
                    spacing: tabsArea.gap
                    Repeater {
                        model: expanded.pages
                        delegate: Rectangle {
                            id: tab
                            required property int index
                            required property var modelData
                            readonly property bool current: modelData.key === expanded.currentKey
                            readonly property bool titled: current && tabsArea.showTitle
                            // Only where every tab has its full width: a label never squeezes the others.
                            readonly property bool labelled: !current && (modelData.label ?? "").length > 0 && tabsArea.width >= tabsArea.fullFit
                            height: 24
                            width: current ? tabsArea.currentWidth : tabsArea.otherWidth + (labelled ? tabsArea.labelWidth : 0)
                            radius: 12
                            color: current ? expanded.theme.faint : tabMouse.containsMouse ? Qt.rgba(expanded.theme.faint.r, expanded.theme.faint.g, expanded.theme.faint.b, expanded.theme.faint.a / 2) : "transparent"
                            clip: true
                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: tab.titled ? 10 : tab.labelled ? 7 : (tab.width - 14) / 2
                                spacing: tab.labelled ? 3 : 6
                                // An icon of the system's theme, or one of the widget's own pictures ("weather:<name>", "lucide:<name>").
                                Item {
                                    id: tabIcon
                                    readonly property string ownName: WeatherIcons.own(tab.modelData.icon)
                                    readonly property bool own: ownName.length > 0
                                    width: 14
                                    height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    Kirigami.Icon {
                                        anchors.fill: parent
                                        visible: !tabIcon.own
                                        source: tabIcon.own ? "" : tab.modelData.icon + "-symbolic"
                                        fallback: tab.modelData.icon
                                        color: tab.current ? expanded.theme.text : expanded.theme.subText
                                        isMask: true
                                    }
                                    WeatherIcon {
                                        anchors.fill: parent
                                        visible: tabIcon.own
                                        name: tabIcon.ownName
                                        color: tab.current ? expanded.theme.text : expanded.theme.subText
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: tab.labelled
                                    text: tab.modelData.label ?? ""
                                    color: expanded.theme.subText
                                    font.pointSize: expanded.theme.fontSmall * 0.9
                                    font.weight: Font.DemiBold
                                    font.features: { "tnum": 1 }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !tab.labelled
                                    text: tab.modelData.title
                                    color: expanded.theme.text
                                    font.pointSize: expanded.theme.fontSmall
                                    font.weight: Font.DemiBold
                                    opacity: tab.titled ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                            }
                            // Count badge (e.g. notifications)
                            Rectangle {
                                visible: (tab.modelData.badge ?? 0) > 0 && !tab.current
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: Math.max(12, badgeLabel.implicitWidth + 6)
                                height: 12
                                radius: 6
                                color: expanded.theme.red
                                Text {
                                    id: badgeLabel
                                    anchors.centerIn: parent
                                    text: (tab.modelData.badge ?? 0) > 99 ? "99+" : String(tab.modelData.badge ?? 0)
                                    color: expanded.theme.onColor(expanded.theme.red)
                                    font.pointSize: expanded.theme.fontSmall * 0.7
                                    font.weight: Font.Bold
                                }
                            }
                            // Something is waiting on that page (e.g. a day of the habits not reviewed)
                            Rectangle {
                                visible: tab.modelData.dot === true
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: 3
                                anchors.topMargin: 3
                                width: 6
                                height: 6
                                radius: 3
                                color: expanded.theme.orange
                            }
                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: expanded.showPage(tab.modelData.key)
                            }
                        }
                    }
                }
            }

            Kirigami.Icon {
                visible: expanded.backend.hasBattery
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                source: expanded.backend.batteryCharging ? "battery-100-charging-symbolic"
                        : "battery-" + String(Math.min(100, Math.round(expanded.backend.batteryPercent / 10) * 10)).padStart(3, "0") + "-symbolic"
                color: expanded.theme.subText
                isMask: true
            }
            Clock {
                visible: expanded.showClock
                running: expanded.active && expanded.showClock
                color: expanded.theme.subText
                font.pointSize: expanded.theme.fontSmall
                font.weight: Font.DemiBold
            }
            IconButton {
                objectName: "shrinkButton"
                visible: expanded.dotMode
                iconName: "window-minimize-symbolic"
                iconSize: 12
                implicitWidth: 22; implicitHeight: 22
                toolTip: Lang.i18n("Shrink to dot")
                color: expanded.theme.subText
                hoverColor: expanded.theme.faint
                onClicked: expanded.shrinkRequested()
            }
            IconButton {
                iconName: "configure-symbolic"
                iconSize: 12
                implicitWidth: 22; implicitHeight: 22
                toolTip: Lang.i18n("Settings")
                color: expanded.theme.subText
                hoverColor: expanded.theme.faint
                onClicked: expanded.settingsRequested()
            }
        }

        // Pages
        Item {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.maximumWidth: expanded.width
            clip: true

            Item {
                id: strip
                width: viewport.width * Math.max(1, expanded.visibleKeys.length)
                height: parent.height
                x: -expanded.currentIndex * viewport.width
                Behavior on x {
                    enabled: expanded.slide
                    NumberAnimation {
                        id: stripAnim
                        duration: 320
                        easing.type: Easing.OutCubic
                        onRunningChanged: if (!running) expanded.slide = false
                    }
                }

                Repeater {
                    model: expanded.allKeys
                    delegate: Loader {
                        id: pageLoader
                        required property string modelData
                        readonly property int pos: expanded.visibleKeys.indexOf(modelData)
                        readonly property bool near: pos >= 0 && Math.abs(pos - expanded.currentIndex) <= 1
                        // Once loaded, a page keeps its state until the island collapses.
                        property bool keep: false
                        onNearChanged: if (near && expanded.active) keep = true
                        Connections {
                            target: expanded
                            function onActiveChanged() { if (!expanded.active) pageLoader.keep = false; }
                        }
                        x: Math.max(0, pos) * viewport.width
                        width: viewport.width
                        height: viewport.height
                        active: expanded.active && pos >= 0 && (near || keep)
                        // Rendered only when current (or while sliding).
                        visible: pos >= 0 && (pos === expanded.currentIndex || stripAnim.running)
                        sourceComponent: expanded.componentFor(modelData)
                        // A page typing text (e.g. a calendar link) keeps the island focused and open.
                        readonly property bool pageInteracting: item !== null && item.interacting === true
                        onPageInteractingChanged: expanded.interacting = pageInteracting
                        readonly property bool pageHolding: item !== null && item.holdOpen === true
                        onPageHoldingChanged: expanded.holding = pageHolding
                        readonly property bool pageKeepsWheel: item !== null && item.keepsWheel === true
                        onPageKeepsWheelChanged: expanded.wheelKept = pageKeepsWheel
                        readonly property bool pageWide: item !== null && item.wide === true
                        onPageWideChanged: expanded.wide = pageWide
                        readonly property bool pageTall: item !== null && item.tall === true
                        onPageTallChanged: expanded.tall = pageTall
                    }
                }
            }

            WheelHandler {
                // Mouse wheel or touchpad swipe pages; accumulate to debounce
                // high-resolution touchpad deltas. Sliders handle their own wheel.
                // Not while a page holds the island (e.g. editing the Controls
                // buttons) or keeps the wheel (e.g. the places a search found):
                // there the wheel scrolls that page's list. A list lets the
                // wheel through at its end, so without this it would turn the page.
                enabled: !expanded.holding && !expanded.wheelKept
                property real acc: 0
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const d = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y;
                    acc += d;
                    if (Math.abs(acc) >= 120) {
                        expanded.go(acc < 0 ? 1 : -1);
                        acc = 0;
                    }
                }
            }
        }

        // Page dots
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: expanded.pages.length > 1
            spacing: 5
            Repeater {
                model: expanded.pages.length
                delegate: Rectangle {
                    required property int index
                    width: index === expanded.currentIndex ? 14 : 5
                    height: 5
                    radius: 2.5
                    color: index === expanded.currentIndex ? expanded.theme.subText : expanded.theme.track
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    Component {
        id: mediaPage
        MediaModule {
            theme: expanded.theme
            backend: expanded.backend
            glowEnabled: expanded.ambientGlow
            onGlowToggled: expanded.ambientGlowToggled()
        }
    }
    Component {
        id: controlPage
        // Fills the whole page: no empty space in either layout.
        SystemModule {
            visible: expanded.showSystemModule
            theme: expanded.theme
            backend: expanded.backend
            network: expanded.network
            mode: expanded.systemView
            onMetricClicked: key => expanded.systemMetricClicked(key)
        }
    }
    Component {
        id: activitiesPage
        Flickable {
            clip: true
            contentHeight: activityColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: activityColumn
                width: parent.width
                spacing: 6
                Repeater {
                    model: expanded.listedActivities
                    delegate: ActivityView {
                        required property var modelData
                        width: activityColumn.width
                        height: item ? item.implicitHeight : 0
                        theme: expanded.theme
                        activity: modelData
                        component: modelData.expanded ?? genericCard
                    }
                }
            }
        }
    }
    Component { id: genericCard; ActivityCard {} }
    Component {
        id: notificationsPage
        NotificationModule {
            objectName: "notificationModule"
            theme: expanded.theme
            backend: expanded.backend
            active: expanded.active
            onReplyingChanged: expanded.interacting = replying
        }
    }
}
