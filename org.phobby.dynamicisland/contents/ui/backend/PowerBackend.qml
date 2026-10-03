/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Power profiles (power-profiles-daemon via Plasma's batterymonitor plugin).
    Battery state itself lives in PlasmaBackend.
*/
import QtQuick
import org.kde.plasma.private.batterymonitor as BatteryMonitor
import ".."

Item {
    id: power

    readonly property bool profilesAvailable: control.isPowerProfileDaemonInstalled && control.profiles.length > 0
    readonly property var profiles: control.profiles
    readonly property string profile: control.activeProfile

    function setProfile(p: string): void { control.setProfile(p); }

    function iconFor(p: string): string {
        return p === "power-saver" ? "battery-profile-powersave-symbolic"
             : p === "performance" ? "battery-profile-performance-symbolic"
             : "battery-profile-balanced-symbolic";
    }
    function nameFor(p: string): string {
        return p === "power-saver" ? Lang.i18n("Power Save")
             : p === "performance" ? Lang.i18n("Performance")
             : Lang.i18n("Balanced");
    }

    BatteryMonitor.PowerProfilesControl {
        id: control
    }

    // "Keep awake" in Controls: the same manual sleep/screen-lock block as the
    // battery applet's. It holds while this backend lives (the whole session).
    readonly property bool keptAwake: inhibition.isManuallyInhibited
    function setKeepAwake(on: bool): void {
        if (on) inhibition.inhibit(Lang.i18n("Keep awake (Dynamic Island)")); else inhibition.uninhibit();
    }
    BatteryMonitor.InhibitionControl {
        id: inhibition
    }
}
