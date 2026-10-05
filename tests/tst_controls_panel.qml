/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Controls page with stand-ins for Bluetooth and the network: holding
    the Bluetooth, Wi-Fi or VPN button opens its panel (another button still
    starts editing), the rows connect and let go, a new Wi-Fi network asks
    for its password, "Scan" and "Add new" reach the right place, and the
    search for Bluetooth devices ends with the panel.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 470
    height: 400

    Theme { id: islandTheme; follow: false }
    QtObject {
        id: radio
        property bool available: true
        property bool enabled: true
        property bool discovering: false
        property var busy: ({})
        property string failure: ""
        property var devices: [
            { address: "AA:01", name: "Buds", connected: true, paired: true, battery: { percentage: 80 } },
            { address: "AA:02", name: "Mouse", connected: false, paired: true, battery: null },
            { address: "AA:03", name: "Speaker", connected: false, paired: false, battery: null },
            { address: "AA:04", name: "AA-BB-CC-DD-EE-FF", connected: false, paired: false, battery: null }
        ]
        readonly property var connectedDevices: devices.filter(d => d.connected)
        property var toggled: []
        function setEnabled(on) { enabled = on; }
        function setDiscovering(on) { discovering = on; }
        function toggleDevice(device) { toggled = toggled.concat([device.address]); }
        function batteryOf(device) { return device.battery ? device.battery.percentage : -1; }
        function iconFor(device) { return "network-bluetooth-symbolic"; }
    }
    QtObject {
        id: net
        property bool wirelessAvailable: true
        property bool wirelessEnabled: true
        property bool airplaneMode: false
        property bool hotspotActive: false
        property bool scanning: false
        property string failure: ""
        property int scans: 0
        property var asked: []
        property var wifis: [
            { name: "Home", strength: 90, secure: true, needsPassword: false, saved: true, connection: "/c/1", device: "/d", specific: "/ap/1", active: true, activating: false },
            { name: "Cafe", strength: 60, secure: true, needsPassword: true, saved: false, connection: "", device: "/d", specific: "/ap/2", active: false, activating: false },
            { name: "Open", strength: 30, secure: false, needsPassword: false, saved: false, connection: "", device: "/d", specific: "/ap/3", active: false, activating: false }
        ]
        property var vpns: [{ name: "Work", connection: "/c/9", device: "", active: false, activating: false }]
        readonly property var activeVpn: vpns.find(v => v.active) ?? null
        function scan() { scans += 1; }
        function signalIcon(strength) { return "network-wireless-80"; }
        function setWireless(on) { wirelessEnabled = on; }
        function toggleVpn() {}
        function toggleWifi(wifi, password) { asked = asked.concat([wifi.name + ":" + password]); }
        function setVpn(vpn, on) { asked = asked.concat([vpn.name + ":" + on]); }
    }
    QtObject {
        id: nativeCore
        property var started: []
        property bool updatesAvailable: false
        function startDetached(program, args) { started = started.concat([[program].concat(args).join(" ")]); }
    }
    PlasmaBackend { id: sound }
    Rectangle {
        x: 20; y: 8
        width: islandTheme.expandedWidth
        height: islandTheme.tallHeight
        color: islandTheme.surface
        QuickSettingsPage {
            id: page
            anchors.fill: parent
            anchors.margins: islandTheme.padding
            theme: islandTheme
            bluetooth: radio
            network: net
            core: nativeCore
            backend: sound
            tiles: "dnd,bluetooth,wifi,vpn"
        }
    }

    TestCase {
        name: "ControlsPanel"
        when: windowShown

        function find(test) {
            let found = null;
            const walk = item => { if (found === null && test(item)) found = item; for (const c of item.children) walk(c); };
            walk(page);
            return found;
        }
        function named(name) { return find(item => item.objectName === name); }
        function text(t) { return find(item => item.visible === true && typeof item.text === "string" && item.text === t && item.width > 0); }
        function click(item) { tryVerify(() => item !== null && item.visible && item.width > 0, 3000); wait(120); mouseClick(item, item.width / 2, item.height / 2); }
        // The round button above a label.
        function hold(label) {
            tryVerify(() => text(label) !== null, 3000, label);
            const tile = text(label).parent.children[0];
            mousePress(tile, 20, 20);
            wait(700);
            mouseRelease(tile, 20, 20);
        }
        function rowNames() { const l = named("panelList"); const out = []; for (let i = 0; i < l.count; ++i) out.push(l.model.get(i).name + "|" + l.model.get(i).detail); return out; }

        function initTestCase() { Lang.setting = "en"; }
        function cleanup() { page.detail = ""; page.editing = false; radio.toggled = []; net.asked = []; nativeCore.started = []; }

        function test_another_button_still_edits() {
            hold("Focus");
            compare([page.editing, page.detail, page.holdOpen], [true, "", true]);
        }

        function test_bluetooth_devices_scan_and_add() {
            hold("Bluetooth");
            compare([page.editing, page.detail, page.holdOpen, page.tall], [false, "bluetooth", true, true]);
            // connected first with its battery, then paired, then the new one; the nameless one is left out
            compare(rowNames(), ["Buds|80%", "Mouse|", "Speaker|New"]);
            click(text("Speaker"));
            compare(radio.toggled, ["AA:03"]);
            click(named("panelScan"));
            compare(radio.discovering, true);
            tryVerify(() => text("Scanning…") !== null);
            click(named("panelAdd"));
            compare(nativeCore.started, ["bluedevil-wizard"]);
            // leaving ends the search this page started
            click(named("panelBack"));
            compare([page.detail, radio.discovering, page.holdOpen], ["", false, false]);
            tryVerify(() => text("Bluetooth") !== null);
        }

        function test_bluetooth_off_offers_to_turn_it_on() {
            radio.enabled = false;
            hold("Bluetooth");
            verify(text("Bluetooth is off") !== null);
            click(named("panelTurnOn"));
            compare(radio.enabled, true);
            tryVerify(() => text("Buds") !== null);
        }

        function test_wifi_networks_and_a_password() {
            const before = net.scans;
            hold("Wi-Fi");
            compare([page.detail, net.scans], ["wifi", before + 1]);
            compare(rowNames(), ["Home|Connected", "Cafe|", "Open|"]);
            click(text("Open"));
            compare(net.asked, ["Open:"]);
            // a new network with a key: the password is typed first
            click(text("Cafe"));
            tryVerify(() => text("Password for Cafe") !== null);
            compare(page.interacting, true);
            const field = named("panelPassword");
            tryVerify(() => field.input.activeFocus);
            keyClick(Qt.Key_S); keyClick(Qt.Key_3); keyClick(Qt.Key_Return);
            compare(net.asked, ["Open:", "Cafe:s3"]);
            compare(page.interacting, false);
            click(named("panelScan"));
            compare(net.scans, before + 2);
            click(named("panelAdd"));
            compare(nativeCore.started, ["kcmshell6 kcm_networkmanagement"]);
        }

        function test_vpn_connections() {
            hold("VPN");
            compare(page.detail, "vpn");
            compare(named("panelScan").visible, false);
            click(text("Work"));
            compare(net.asked, ["Work:true"]);
            click(named("panelAdd"));
            compare(nativeCore.started, ["kcmshell6 kcm_networkmanagement"]);
        }
    }
}
