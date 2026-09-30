/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Wi-Fi / VPN connection changes and hotspot state (plasma-nm).
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

    function signalIcon(strength: int): string {
        return strength >= 80 ? "network-wireless-100" : strength >= 55 ? "network-wireless-80"
             : strength >= 35 ? "network-wireless-60" : strength >= 15 ? "network-wireless-40" : "network-wireless-20";
    }

    PlasmaNM.Handler { id: handler }
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.NetworkModel { id: networkModel }

    Instantiator {
        model: networkModel
        delegate: QtObject {
            required property var model
            readonly property int state: model.ConnectionState ?? 0
            readonly property int type: model.Type ?? 0
            property int previous: state
            onStateChanged: {
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
