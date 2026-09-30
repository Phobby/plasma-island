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
    property bool active: false
    property bool showMediaModule: true
    property bool showSystemModule: true
    property bool showVolumeModule: true
    property bool showNotificationModule: true
    property bool showClock: true

    // True while the user drags a slider, so the island does not collapse.
    readonly property bool interacting: false

    readonly property var pages: {
        const p = [];
        if (showMediaModule) p.push({ key: "media", icon: "view-media-track", title: i18n("Media") });
        if (showSystemModule || showVolumeModule) p.push({ key: "control", icon: "speedometer", title: i18n("System") });
        if (showNotificationModule) p.push({ key: "notifications", icon: "notifications", title: i18n("Notifications") });
        return p;
    }
    property int currentIndex: 0
    // Jump (don't slide) when the island opens on its default page.
    property bool slide: false
    readonly property string currentKey: pages.length > 0 ? pages[Math.min(currentIndex, pages.length - 1)].key : ""

    // Feed visibility back to the backend so hidden modules cost nothing.
    Binding { target: expanded.backend; property: "systemActive"; value: expanded.active && expanded.currentKey === "control" && expanded.showSystemModule }
    Binding { target: expanded.backend; property: "positionActive"; value: expanded.active && expanded.currentKey === "media" }

    function selectDefaultPage(): void {
        slide = false;
        const media = pages.findIndex(p => p.key === "media");
        if (backend.hasMedia && media >= 0) {
            currentIndex = media;
        } else if (currentKey === "media" && pages.length > 1) {
            currentIndex = media === 0 ? 1 : 0;
        }
        currentIndex = Math.min(currentIndex, Math.max(0, pages.length - 1));
        Qt.callLater(() => { slide = true; });
    }
    function go(delta: int): void {
        currentIndex = Math.max(0, Math.min(pages.length - 1, currentIndex + delta));
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
                    readonly property bool current: index === expanded.currentIndex
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
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: expanded.currentIndex = tab.index
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Kirigami.Icon {
                visible: expanded.backend.hasBattery
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                source: expanded.backend.batteryCharging ? "battery-charging-symbolic"
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
                width: viewport.width * expanded.pages.length
                height: parent.height
                x: -expanded.currentIndex * viewport.width
                Behavior on x {
                    enabled: expanded.slide
                    NumberAnimation { id: stripAnim; duration: 320; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: expanded.pages
                    delegate: Loader {
                        required property int index
                        required property var modelData
                        x: index * viewport.width
                        width: viewport.width
                        height: viewport.height
                        // Neighbouring pages stay loaded for a smooth slide, but are
                        // only rendered while sliding.
                        active: expanded.active && Math.abs(index - expanded.currentIndex) <= 1
                        visible: index === expanded.currentIndex || stripAnim.running
                        sourceComponent: modelData.key === "media" ? mediaPage
                                       : modelData.key === "control" ? controlPage
                                       : notificationsPage
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
        ColumnLayout {
            spacing: 10
            SystemModule {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                visible: expanded.showSystemModule
                theme: expanded.theme
                backend: expanded.backend
            }
            VolumeModule {
                Layout.fillWidth: true
                visible: expanded.showVolumeModule
                theme: expanded.theme
                backend: expanded.backend
            }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: notificationsPage
        NotificationModule {
            theme: expanded.theme
            backend: expanded.backend
            active: expanded.active
        }
    }
}
