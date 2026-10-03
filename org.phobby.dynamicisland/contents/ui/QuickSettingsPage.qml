/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Control Center: up to six round buttons chosen by the user, like a
    phone's quick settings (ControlCatalog: Do Not Disturb, Night Light,
    power profile, Bluetooth, Wi-Fi, updates, airplane mode, VPN, hotspot,
    screen recording, screenshot, camera, microphone, sound, KDE Connect,
    find phone, dark mode, keep awake, lock, calculator, System Settings), and
    the adjustable sliders (volume, brightness).
    Holding a button edits them here: drag one sideways to move it, "−" takes one away, the others are
    offered below to add (Settings → Controls also orders them); the island
    stays open meanwhile. A button
    whose part is missing (no Bluetooth, no VPN…) is dimmed.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    property var dnd: null
    property var display: null
    property var power: null
    property var bluetooth: null
    property var network: null
    property var core: null
    property var kdeconnect: null
    property var schemes: null           // ColorSchemeBackend
    property var backend: null           // PlasmaBackend (output volume, microphone)
    property bool showUpdates: true
    property bool showVolume: true
    property bool showBrightness: true
    // The chosen buttons (the controlTiles setting) and where a change goes.
    property string tiles: ""
    signal tilesEdited(string tiles)

    ControlCatalog { id: catalog }
    readonly property var chosen: catalog.normalize(tiles)
    property bool editing: false
    // While editing the island stays open even with the pointer away; Done (or
    // another page) ends it and the island closes as usual.
    readonly property bool holdOpen: visible && editing
    onVisibleChanged: if (!visible) editing = false; else if (schemes) schemes.refresh()
    onEditingChanged: if (!editing) { dragFrom = -1; dragTo = -1; dragDx = 0; }
    function remove(key: string): void { tilesEdited(chosen.filter(k => k !== key).join(",")); }
    // Editing: a button dragged sideways takes a new place; the others make room.
    readonly property real slotWidth: 66            // a button (60) and the spacing (6)
    property int dragFrom: -1
    property int dragTo: -1
    property real dragDx: 0
    function moveTile(from: int, to: int): void {
        if (from === to || from < 0 || to < 0) return;
        const list = chosen.slice();
        list.splice(to, 0, list.splice(from, 1)[0]);
        tilesEdited(list.join(","));
    }
    // How far a button that is not dragged steps aside for the dragged one.
    function shiftFor(index: int): real {
        if (dragFrom < 0 || index === dragFrom) return 0;
        if (dragFrom < dragTo && index > dragFrom && index <= dragTo) return -slotWidth;
        if (dragTo < dragFrom && index >= dragTo && index < dragFrom) return slotWidth;
        return 0;
    }
    function add(key: string): void { if (chosen.length < catalog.maximum) tilesEdited(chosen.concat([key]).join(",")); }

    // Programs some buttons start; a missing one dims its button.
    function has(program: string): bool { return !core || !core.local || core.local.findExecutable(program).length > 0; }
    readonly property string cameraApp: ["kamoso", "snapshot", "cheese", "guvcview"].find(p => core && core.local && core.local.findExecutable(p).length > 0) ?? ""
    function run(program: string, args: var): void { if (core) core.startDetached(program, args); }

    // What a button shows and does: { icon, label, checked, tint, badge, available, act }
    function tileState(key: string): var {
        const t = theme, info = catalog.info(key) || { icon: "", title: key };
        const s = { icon: info.icon, label: info.title, checked: false, tint: t.blue, badge: "", available: true, act: () => {} };
        switch (key) {
        case "dnd":
            s.available = dnd !== null; s.checked = dnd ? dnd.active : false; s.tint = t.purple;
            s.act = () => dnd.setActive(!dnd.active); break;
        case "nightlight":
            s.available = display !== null; s.checked = display ? !display.nightLightInhibited : false; s.tint = t.orange;
            s.act = () => display.toggleNightLight(); break;
        case "power":
            s.available = power !== null && power.profilesAvailable;
            if (s.available) {
                s.icon = power.iconFor(power.profile); s.label = power.nameFor(power.profile);
                s.checked = power.profile !== "balanced"; s.tint = power.profile === "performance" ? t.red : t.live;
            }
            s.act = () => { const list = power.profiles; power.setProfile(list[(list.indexOf(power.profile) + 1) % list.length]); }; break;
        case "bluetooth":
            s.available = bluetooth !== null && bluetooth.available;
            s.checked = s.available && bluetooth.enabled;
            s.icon = s.checked ? "network-bluetooth-activated" : "network-bluetooth-inactive";
            s.badge = s.available && bluetooth.connectedDevices.length > 0 ? String(bluetooth.connectedDevices.length) : "";
            s.act = () => bluetooth.setEnabled(!bluetooth.enabled); break;
        case "wifi":
            s.available = network !== null && network.wirelessAvailable;
            s.checked = s.available && network.wirelessEnabled;
            s.icon = s.checked ? "network-wireless" : "network-wireless-off";
            s.act = () => network.setWireless(!network.wirelessEnabled); break;
        case "updates":
            s.available = showUpdates && core !== null && core.updatesAvailable;
            s.badge = s.available && core.updateCount > 0 ? String(core.updateCount) : "";
            s.checked = s.available && core.securityUpdateCount > 0; s.tint = t.red;
            s.act = () => run("plasma-discover", ["--mode", "update"]); break;
        case "airplane":
            s.available = network !== null; s.checked = network ? network.airplaneMode : false; s.tint = t.orange;
            s.act = () => network.setAirplaneMode(!network.airplaneMode); break;
        case "vpn":
            s.available = network !== null && network.vpns.length > 0;
            s.checked = s.available && network.activeVpn !== null;
            if (s.checked) s.label = network.activeVpn.name;
            s.act = () => network.toggleVpn(); break;
        case "hotspot":
            s.available = network !== null && network.wirelessAvailable; s.checked = network ? network.hotspotActive : false;
            s.act = () => network.setHotspot(!network.hotspotActive); break;
        case "record":
            s.available = has("spectacle"); s.checked = core !== null && (core.screenCastApps || []).length > 0; s.tint = t.red;
            s.act = () => run("spectacle", ["--record", "region"]); break;
        case "screenshot":
            s.available = has("spectacle");
            s.act = () => run("spectacle", ["--region"]); break;
        case "camera":
            s.available = cameraApp.length > 0; s.checked = core !== null && (core.cameraApps || []).length > 0; s.tint = t.live;
            s.act = () => run(cameraApp, []); break;
        case "mic":
            s.available = backend !== null && backend.source !== null && backend.source !== undefined;
            s.checked = s.available && !backend.micMuted;
            s.icon = s.checked ? "microphone-sensitivity-high" : "microphone-sensitivity-muted";
            s.act = () => backend.toggleMicMute(); break;
        case "mute":
            s.available = backend !== null && backend.hasSink; s.checked = s.available && !backend.muted;
            s.icon = s.checked ? "audio-volume-high" : "audio-volume-muted";
            s.act = () => backend.toggleMute(); break;
        case "kdeconnect":
            s.available = has("kdeconnect-app");
            s.checked = kdeconnect !== null && kdeconnect.phones.length > 0;
            s.badge = s.checked && kdeconnect.phones.length > 1 ? String(kdeconnect.phones.length) : "";
            s.act = () => run("kdeconnect-app", []); break;
        case "findphone":
            s.available = core !== null && kdeconnect !== null && kdeconnect.phones.length > 0;
            s.act = () => { for (const phone of kdeconnect.phones)
                core.call(false, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + phone.id + "/findmyphone",
                          "org.kde.kdeconnect.device.findmyphone", "ring", [], () => {}); }; break;
        case "darkmode":
            s.available = schemes !== null && core !== null; s.checked = schemes ? schemes.dark : false; s.tint = t.purple;
            s.act = () => schemes.toggle(); break;
        case "awake":
            s.available = power !== null; s.checked = power ? power.keptAwake : false; s.tint = t.orange;
            s.act = () => power.setKeepAwake(!power.keptAwake); break;
        case "lock":
            s.act = () => run("loginctl", ["lock-session"]); break;
        case "calculator":
            s.available = has("kcalc"); s.act = () => run("kcalc", []); break;
        case "settings":
            s.available = has("systemsettings"); s.act = () => run("systemsettings", []); break;
        }
        return s;
    }

    component Toggle: ColumnLayout {
        id: toggle
        property string icon
        property string label
        property string badge
        property bool checked
        property color tint: page.theme.control
        property bool available: true
        property bool editing: false
        property int slot: -1                   // position among the chosen buttons (editing: drag)
        readonly property bool lifted: page.dragFrom >= 0 && page.dragFrom === slot
        signal clicked()
        signal held()
        signal removeClicked()
        spacing: 2
        Layout.preferredWidth: 60
        opacity: available || editing ? 1 : 0.4
        z: lifted ? 10 : 0
        transform: Translate {
            x: toggle.lifted ? page.dragDx : page.shiftFor(toggle.slot)
            Behavior on x { enabled: !toggle.lifted; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            id: circle
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 40
            implicitHeight: 40
            radius: 20
            // on: vivid tint; off: neutral fill. Hover/pressed stay distinguishable in both.
            readonly property color base: toggle.checked ? toggle.tint : page.theme.faint
            color: mouse.pressed ? (toggle.checked ? Qt.darker(toggle.tint, 1.25) : page.theme.pressedFill)
                 : mouse.containsMouse && !toggle.checked ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                 : base
            border.width: mouse.containsMouse ? 1.5 : 0
            border.color: page.theme.readable(toggle.checked ? toggle.tint : page.theme.text, page.theme.surface)
            scale: toggle.lifted ? 1.15 : mouse.pressed && !toggle.editing ? 0.92 : mouse.containsMouse ? 1.08 : 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: toggle.icon
                // WCAG: icon colour picked against the actual button colour.
                color: toggle.checked ? page.theme.onColor(toggle.tint) : page.theme.text
                isMask: true
            }
            // Small count badge (connected devices, pending updates)
            Rectangle {
                visible: toggle.badge.length > 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: -3
                width: Math.max(16, badgeText.implicitWidth + 8)
                height: 16
                radius: 8
                color: page.theme.text
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: toggle.badge
                    color: page.theme.onColor(page.theme.text)
                    font.pointSize: page.theme.fontSmall * 0.8
                    font.weight: Font.Bold
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: toggle.editing ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                pressAndHoldInterval: 500
                preventStealing: true
                property real startX: 0
                onPressed: mouse => startX = mapToItem(page, mouse.x, 0).x
                // Editing: dragging sideways moves the button (also right after the hold that started editing).
                onPositionChanged: mouse => {
                    if (!toggle.editing || !pressed) return;
                    const dx = mapToItem(page, mouse.x, 0).x - startX;
                    if (page.dragFrom < 0) {
                        if (Math.abs(dx) < 6) return;
                        page.dragFrom = toggle.slot;
                    }
                    const last = page.chosen.length - 1;
                    page.dragDx = Math.max(-toggle.slot * page.slotWidth, Math.min((last - toggle.slot) * page.slotWidth, dx));
                    page.dragTo = Math.max(0, Math.min(last, toggle.slot + Math.round(page.dragDx / page.slotWidth)));
                }
                onReleased: {
                    if (page.dragFrom === toggle.slot) {
                        const from = page.dragFrom, to = page.dragTo;
                        page.dragFrom = -1; page.dragTo = -1; page.dragDx = 0;
                        page.moveTile(from, to);
                    }
                }
                onCanceled: { page.dragFrom = -1; page.dragTo = -1; page.dragDx = 0; }
                onClicked: if (!toggle.editing && toggle.available) toggle.clicked()
                onPressAndHold: if (!toggle.editing) toggle.held()
            }
            // Editing: takes the button away
            Rectangle {
                visible: toggle.editing && !toggle.lifted
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: -3
                width: 16; height: 16; radius: 8
                color: page.theme.danger
                Rectangle { anchors.centerIn: parent; width: 8; height: 2; radius: 1; color: page.theme.onColor(page.theme.danger) }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggle.removeClicked()
                }
            }
            // Edit mode: a gentle wiggle, as on phones
            SequentialAnimation on rotation {
                running: toggle.editing && !toggle.lifted
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: -3; duration: 110 }
                NumberAnimation { to: 3; duration: 220 }
                NumberAnimation { to: 0; duration: 110 }
            }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: toggle.label
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.95
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
                model: page.chosen
                delegate: Toggle {
                    required property string modelData
                    required property int index
                    slot: index
                    readonly property var state_: page.tileState(modelData)
                    icon: state_.icon
                    label: state_.label
                    badge: state_.badge
                    checked: state_.checked
                    tint: state_.tint
                    available: state_.available
                    editing: page.editing
                    onClicked: state_.act()
                    onHeld: page.editing = true
                    onRemoveClicked: page.remove(modelData)
                }
            }
            // Nothing chosen: a way back in
            Text {
                visible: page.chosen.length === 0 && !page.editing
                text: Lang.i18n("No buttons. Hold here to add some.")
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall
                MouseArea { anchors.fill: parent; pressAndHoldInterval: 500; onPressAndHold: page.editing = true; onClicked: page.editing = true }
            }
        }

        // Editing: the buttons that can be added (round icons, the name of the
        // one under the pointer above them), and Done
        ColumnLayout {
            id: editBox
            visible: page.editing
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            property var hovered: null          // catalog entry under the pointer
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    readonly property var info: editBox.hovered
                    text: info ? "+ " + info.title + (info.hint ? " · " + info.hint : "")
                        : page.chosen.length < catalog.maximum
                        ? Lang.i18n("Tap to add (at most %1); drag to move, \"−\" removes.", catalog.maximum)
                        : Lang.i18n("%1 buttons: remove one to add another.", catalog.maximum)
                    color: info ? page.theme.text : page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    elide: Text.ElideRight
                }
                PillButton {
                    theme: page.theme
                    implicitHeight: 20
                    primary: true
                    text: Lang.i18n("Done")
                    onClicked: page.editing = false
                }
            }
            Flickable {
                id: picker
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: spare.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Flow {
                    id: spare
                    width: picker.width
                    spacing: 4
                    Repeater {
                        model: catalog.keys.filter(k => page.chosen.indexOf(k) < 0)
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            readonly property var info: catalog.info(modelData)
                            readonly property bool full: page.chosen.length >= catalog.maximum
                            width: 28; height: 28; radius: 14
                            opacity: full ? 0.45 : 1
                            color: chipMouse.containsMouse && !full ? page.theme.hoverFill : page.theme.faint
                            border.width: chipMouse.containsMouse ? 1 : 0
                            border.color: page.theme.subText
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 16; height: 16
                                source: chip.info.icon
                                color: page.theme.text
                                isMask: true
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: chip.full ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onContainsMouseChanged: {
                                    if (containsMouse) editBox.hovered = chip.info;
                                    else if (editBox.hovered === chip.info) editBox.hovered = null;
                                }
                                onClicked: page.add(chip.modelData)
                            }
                        }
                    }
                }
            }
        }

        // Adjustable controls
        Flickable {
            visible: !page.editing
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: sliders.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: sliders
                width: parent.width
                spacing: 4
                VolumeModule {
                    Layout.fillWidth: true
                    visible: page.showVolume && page.backend !== null
                    theme: page.theme
                    backend: page.backend
                }
                BrightnessModule {
                    Layout.fillWidth: true
                    theme: page.theme
                    display: page.showBrightness ? page.display : null
                }
            }
        }
    }
}
