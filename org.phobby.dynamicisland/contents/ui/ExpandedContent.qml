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

Item {
    id: expanded

    required property Theme theme
    required property PlasmaBackend backend
    required property ActivityManager manager
    property bool active: false
    property bool showMediaModule: true
    property bool showSystemModule: true
    property bool showVolumeModule: true
    property bool showNotificationModule: true
    property bool showClock: true
    property string systemView: "dynamic"
    signal systemMetricClicked(string key)

    // True while the user types a reply: the island keeps keyboard focus
    // and does not collapse.
    property bool interacting: false
    onActiveChanged: if (!active) interacting = false

    // Live activities that have no page of their own (media has one).
    readonly property var listedActivities: manager.live.concat(manager.indicators).filter(a => a.listed)
    // Extra pages contributed by providers: [{ key, icon, title, component, visible }]
    property var extraPages: []

    readonly property var pages: {
        const p = [];
        if (listedActivities.length > 0) p.push({ key: "activities", icon: "view-list-details", title: i18n("Activities") });
        if (showMediaModule) p.push({ key: "media", icon: "view-media-track", title: i18n("Media") });
        // System = information only; the volume slider lives in Controls.
        if (showSystemModule) p.push({ key: "control", icon: "speedometer", title: i18n("System") });
        if (showNotificationModule) p.push({ key: "notifications", icon: "notifications", title: i18n("Notifications"), badge: backend.notificationCount });
        for (const e of extraPages) if (e.visible !== false) p.push(e);
        return p;
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
            spacing: 4

            Repeater {
                model: expanded.pages
                delegate: Rectangle {
                    id: tab
                    required property int index
                    required property var modelData
                    readonly property bool current: modelData.key === expanded.currentKey
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: current ? tabLabel.implicitWidth + 36 : 30
                    radius: 12
                    color: current ? expanded.theme.faint : tabMouse.containsMouse ? Qt.rgba(expanded.theme.faint.r, expanded.theme.faint.g, expanded.theme.faint.b, expanded.theme.faint.a / 2) : "transparent"
                    clip: true
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: tab.current ? 10 : (tab.width - 14) / 2
                        spacing: 6
                        Kirigami.Icon {
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            source: tab.modelData.icon + "-symbolic"
                            fallback: tab.modelData.icon
                            color: tab.current ? expanded.theme.text : expanded.theme.subText
                            isMask: true
                        }
                        Text {
                            id: tabLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.title
                            color: expanded.theme.text
                            font.pointSize: expanded.theme.fontSmall
                            font.weight: Font.DemiBold
                            opacity: tab.current ? 1 : 0
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
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: expanded.showPage(tab.modelData.key)
                    }
                }
            }

            Item { Layout.fillWidth: true }

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
        }

        // Pages
        Item {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                    }
                }
            }

            WheelHandler {
                // Mouse wheel or touchpad swipe pages; accumulate to debounce
                // high-resolution touchpad deltas. Sliders handle their own wheel.
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
        }
    }
    Component {
        id: controlPage
        // Fills the whole page: no empty space in either layout.
        SystemModule {
            visible: expanded.showSystemModule
            theme: expanded.theme
            backend: expanded.backend
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
