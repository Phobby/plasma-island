/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Paired, reachable KDE Connect phones with their battery (via the KDE
    Connect QML module). Calls come from the native D-Bus watcher, file
    transfers show up as regular KDE jobs.
*/
import QtQuick
import org.kde.kdeconnect as KDEConnect

Item {
    id: kdeconnect

    // [{ id, name, icon, charge (-1 unknown), charging }]
    property var phones: []
    readonly property bool available: true

    KDEConnect.DevicesModel {
        id: devices
        displayFilter: KDEConnect.DevicesModel.Paired | KDEConnect.DevicesModel.Reachable
    }

    property var rows: []
    function rebuild(): void {
        phones = rows.filter(r => r).map(r => ({
            id: r.deviceId,
            name: r.name,
            icon: r.icon,
            charge: r.charge,
            charging: r.charging
        }));
    }

    Instantiator {
        model: devices
        delegate: QtObject {
            id: row
            required property var model
            readonly property string deviceId: model.deviceId
            readonly property string name: model.name || ""
            readonly property var device: KDEConnect.DeviceDbusInterfaceFactory.create(model.deviceId)
            readonly property string icon: (device && device.iconName ? device.iconName : "smartphone") + "-symbolic"
            property var checker: KDEConnect.PluginChecker {
                pluginName: "battery"
                device: row.device
                onAvailableChanged: row.battery = available ? KDEConnect.DeviceBatteryDbusInterfaceFactory.create(row.deviceId) : null
            }
            property var battery: null
            readonly property int charge: battery ? battery.charge : -1
            readonly property bool charging: battery ? battery.isCharging : false
            onChargeChanged: Qt.callLater(kdeconnect.rebuild)
            onChargingChanged: Qt.callLater(kdeconnect.rebuild)
            onNameChanged: Qt.callLater(kdeconnect.rebuild)
            Component.onCompleted: { kdeconnect.rows.push(row); Qt.callLater(kdeconnect.rebuild); }
            Component.onDestruction: {
                const i = kdeconnect.rows.indexOf(row);
                if (i >= 0) kdeconnect.rows.splice(i, 1);
                Qt.callLater(kdeconnect.rebuild);
            }
        }
    }
}
