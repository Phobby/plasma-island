/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Wi-Fi / VPN connection changes and hotspot state (plasma-nm), and the
    switches of the Controls page: Wi-Fi, airplane mode (the same setting as
    Plasma's network applet), the VPN connections, the hotspot.
    NetworkManager does not report how many clients use a hotspot.
    Also the connection the machine is online through (wired before Wi-Fi)
    with the address lines of the applet's Details tab.
    And what the Controls page's Wi-Fi and VPN panels list and do: the networks
    in range, a new search, connecting (with a password for a new network).
*/
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM

Item {
    id: net

    signal wifiConnected(string ssid, int signalStrength)
    signal wifiDisconnected(string ssid)
    signal vpnChanged(string name, bool connected)

    readonly property bool hotspotActive: handler.hotspotActive
    readonly property bool wirelessEnabled: enabledConnections.wirelessEnabled
    readonly property bool wirelessAvailable: enabledConnections.wirelessHwEnabled
    function setWireless(on: bool): void { handler.enableWireless(on); }

    readonly property bool airplaneMode: PlasmaNM.Configuration.airplaneModeEnabled
    function setAirplaneMode(on: bool): void {
        handler.enableAirplaneMode(on);
        PlasmaNM.Configuration.airplaneModeEnabled = on;
    }
    function setHotspot(on: bool): void { if (on) handler.createHotspot(); else handler.stopHotspot(); }

    // VPN connections: [{ name, connection, device, active }]
    property var vpns: []
    readonly property var activeVpn: vpns.find(v => v.active) ?? null
    // Off: the active one goes down. On: the one used last comes up (else the first).
    property string lastVpn: ""
    function toggleVpn(): void {
        if (activeVpn) { handler.deactivateConnection(activeVpn.connection, activeVpn.device); return; }
        const v = vpns.find(x => x.connection === lastVpn) ?? vpns[0];
        if (v) handler.activateConnection(v.connection, v.device, "");
    }
    function setVpn(vpn: var, on: bool): void {
        failure = "";
        if (on) handler.activateConnection(vpn.connection, vpn.device, "");
        else handler.deactivateConnection(vpn.connection, vpn.device);
    }
    function collectVpns(): void {
        const list = [];
        for (let i = 0; i < rows.count; ++i) {
            const r = rows.objectAt(i);
            if (r && r.type === PlasmaNM.Enums.Vpn && r.connection.length > 0 && !list.some(v => v.connection === r.connection))
                list.push({ name: r.name, connection: r.connection, device: r.device, active: r.state === PlasmaNM.Enums.Activated,
                            activating: r.state === PlasmaNM.Enums.Activating });
        }
        vpns = list;
        if (activeVpn) lastVpn = activeVpn.connection;
    }

    // Wi-Fi networks in range, the one in use first, then by strength:
    // [{ name, strength, secure, needsPassword, saved, connection, device, specific, active, activating }]
    property var wifis: []
    readonly property bool scanning: handler.scanning
    function scan(): void { handler.requestScan(); }
    // What went wrong with the last connection that was asked for.
    property string failure: ""
    function collectWifis(): void {
        // A key that is typed in here; the other kinds (enterprise) are set up in Plasma's own window.
        const typed = [PlasmaNM.Enums.StaticWep, PlasmaNM.Enums.WpaPsk, PlasmaNM.Enums.Wpa2Psk, PlasmaNM.Enums.SAE];
        const open = [PlasmaNM.Enums.UnknownSecurity, PlasmaNM.Enums.NoneSecurity, PlasmaNM.Enums.OWE];
        const list = [];
        for (let i = 0; i < rows.count; ++i) {
            const r = rows.objectAt(i);
            if (!r || r.type !== PlasmaNM.Enums.Wireless || r.duplicate || r.name.length === 0) continue;
            // In range (an access point) or in use; a saved network that is far away is left out.
            if (r.specific.length === 0 && r.state === PlasmaNM.Enums.Deactivated) continue;
            const saved = r.connection.length > 0;
            list.push({ name: r.name, strength: r.strength, secure: open.indexOf(r.security) < 0,
                        needsPassword: !saved && typed.indexOf(r.security) >= 0, saved: saved,
                        connection: r.connection, device: r.device, specific: r.specific,
                        active: r.state === PlasmaNM.Enums.Activated, activating: r.state === PlasmaNM.Enums.Activating });
        }
        const rank = w => w.active ? 2 : w.activating ? 1 : 0;
        list.sort((a, b) => rank(b) - rank(a) || b.strength - a.strength || a.name.localeCompare(b.name));
        wifis = list;
    }
    // In use: lets go. Saved: connects. New: is added, with the password where one is needed.
    function toggleWifi(wifi: var, password: string): void {
        failure = "";
        if (wifi.active || wifi.activating) handler.deactivateConnection(wifi.connection, wifi.device);
        else if (wifi.saved) handler.activateConnection(wifi.connection, wifi.device, wifi.specific);
        else if (wifi.needsPassword) handler.addAndActivateConnection(wifi.device, wifi.specific, password);
        else handler.addAndActivateConnection(wifi.device, wifi.specific);
    }

    // The active wired / Wi-Fi connection: { name, device, wired, ipv4, mac } or null.
    property var primary: null
    function collectPrimary(): void {
        let best = null;
        for (let i = 0; i < rows.count; ++i) {
            const r = rows.objectAt(i);
            if (r && r.carrier && (!best || (r.type === PlasmaNM.Enums.Wired && best.type !== PlasmaNM.Enums.Wired))) best = r;
        }
        if (!best) { primary = null; return; }
        // The labels of the details are translated by plasma-nm, so the values are
        // recognised by their form: the address comes before gateway and name
        // server, the device's own MAC after the access point's (BSSID).
        const values = [];
        for (let i = 0; i < best.details.count; ++i) values.push(best.details.objectAt(i)?.value ?? "");
        primary = {
            name: best.name, device: best.iface, wired: best.type === PlasmaNM.Enums.Wired,
            ipv4: values.find(v => /^\d{1,3}(\.\d{1,3}){3}$/.test(v)) ?? "",
            mac: values.filter(v => /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i.test(v)).pop() ?? ""
        };
    }

    function signalIcon(strength: int): string {
        return strength >= 80 ? "network-wireless-100" : strength >= 55 ? "network-wireless-80"
             : strength >= 35 ? "network-wireless-60" : strength >= 15 ? "network-wireless-40" : "network-wireless-20";
    }

    PlasmaNM.Handler {
        id: handler
        onConnectionActivationFailed: (connectionPath, message) => net.failure = message
    }
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.NetworkModel { id: networkModel }

    Instantiator {
        id: rows
        model: networkModel
        onObjectAdded: { Qt.callLater(net.collectVpns); Qt.callLater(net.collectPrimary); Qt.callLater(net.collectWifis); }
        onObjectRemoved: { Qt.callLater(net.collectVpns); Qt.callLater(net.collectPrimary); Qt.callLater(net.collectWifis); }
        delegate: QtObject {
            id: entry
            required property var model
            readonly property int state: model.ConnectionState ?? 0
            readonly property int type: model.Type ?? 0
            readonly property string name: model.Name ?? ""
            readonly property string connection: model.ConnectionPath ?? ""
            readonly property string device: model.DevicePath ?? ""
            readonly property string iface: model.DeviceName ?? ""
            readonly property string specific: model.SpecificPath ?? ""
            readonly property int security: model.SecurityType ?? 0
            readonly property int strength: model.Signal ?? 0
            readonly property bool duplicate: model.Duplicate ?? false
            onConnectionChanged: Qt.callLater(net.collectWifis)
            onSpecificChanged: Qt.callLater(net.collectWifis)
            onStrengthChanged: Qt.callLater(net.collectWifis)
            onDuplicateChanged: Qt.callLater(net.collectWifis)
            readonly property bool carrier: state === PlasmaNM.Enums.Activated && (type === PlasmaNM.Enums.Wired || type === PlasmaNM.Enums.Wireless)
            onNameChanged: { Qt.callLater(net.collectPrimary); Qt.callLater(net.collectWifis); }
            // Rows of the applet's Details tab (section titles have no value).
            readonly property Instantiator details: Instantiator {
                model: entry.carrier ? entry.model.ConnectionDetailsModel : null
                onObjectAdded: Qt.callLater(net.collectPrimary)
                onObjectRemoved: Qt.callLater(net.collectPrimary)
                delegate: QtObject {
                    required property var model
                    readonly property string value: model.detailValue ?? ""
                    onValueChanged: Qt.callLater(net.collectPrimary)
                }
            }
            property int previous: state
            onStateChanged: {
                Qt.callLater(net.collectPrimary);
                Qt.callLater(net.collectWifis);
                if (type === PlasmaNM.Enums.Vpn) Qt.callLater(net.collectVpns);
                const was = previous;
                previous = state;
                if (type === PlasmaNM.Enums.Wireless) {
                    if (state === PlasmaNM.Enums.Activated && was !== PlasmaNM.Enums.Activated) net.wifiConnected(model.Ssid || model.Name, model.Signal ?? 0);
                    else if (state === PlasmaNM.Enums.Deactivated && was === PlasmaNM.Enums.Activated) net.wifiDisconnected(model.Ssid || model.Name);
                } else if (type === PlasmaNM.Enums.Vpn) {
                    if (state === PlasmaNM.Enums.Activated && was !== PlasmaNM.Enums.Activated) net.vpnChanged(model.Name, true);
                    else if (state === PlasmaNM.Enums.Deactivated && was === PlasmaNM.Enums.Activated) net.vpnChanged(model.Name, false);
                }
            }
        }
    }
}
