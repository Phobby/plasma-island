/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Wi-Fi / VPN connection changes and hotspot state (plasma-nm), and the
    switches of the Controls page: Wi-Fi, airplane mode (the same setting as
    Plasma's network applet), the VPN connections, the hotspot.
    NetworkManager does not report how many clients use a hotspot.
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
    function collectVpns(): void {
        const list = [];
        for (let i = 0; i < rows.count; ++i) {
            const r = rows.objectAt(i);
            if (r && r.type === PlasmaNM.Enums.Vpn && r.connection.length > 0 && !list.some(v => v.connection === r.connection))
                list.push({ name: r.name, connection: r.connection, device: r.device, active: r.state === PlasmaNM.Enums.Activated });
        }
        vpns = list;
        if (activeVpn) lastVpn = activeVpn.connection;
    }

    function signalIcon(strength: int): string {
        return strength >= 80 ? "network-wireless-100" : strength >= 55 ? "network-wireless-80"
             : strength >= 35 ? "network-wireless-60" : strength >= 15 ? "network-wireless-40" : "network-wireless-20";
    }

    PlasmaNM.Handler { id: handler }
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.NetworkModel { id: networkModel }

    Instantiator {
        id: rows
        model: networkModel
        onObjectAdded: Qt.callLater(net.collectVpns)
        onObjectRemoved: Qt.callLater(net.collectVpns)
        delegate: QtObject {
            required property var model
            readonly property int state: model.ConnectionState ?? 0
            readonly property int type: model.Type ?? 0
            readonly property string name: model.Name ?? ""
            readonly property string connection: model.ConnectionPath ?? ""
            readonly property string device: model.DevicePath ?? ""
            property int previous: state
            onStateChanged: {
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
