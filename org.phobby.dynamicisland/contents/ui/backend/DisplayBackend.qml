/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Screen brightness and Night Light (Plasma's brightness plugin).
*/
import QtQuick
import org.kde.plasma.private.brightnesscontrolplugin as Brightness

Item {
    id: display

    // Emitted when any display's brightness changes (0..1).
    signal brightnessAdjusted(string displayName, real value)

    readonly property bool brightnessAvailable: screenControl.isBrightnessAvailable
    // Model roles (same as the Brightness applet): displayName, label, brightness, maxBrightness
    readonly property var displays: screenControl.displays
    function setBrightness(displayName: string, value: int): void { screenControl.setBrightness(displayName, value); }
    // Singleton shared with the Brightness applet.
    readonly property bool nightLightInhibited: Brightness.NightLightInhibitor.inhibited
    function toggleNightLight(): void { Brightness.NightLightInhibitor.toggleInhibition(); }

    Brightness.ScreenBrightnessControl {
        id: screenControl
    }

    Instantiator {
        model: screenControl.displays
        delegate: QtObject {
            required property var model
            readonly property real value: model.maxBrightness > 0 ? model.brightness / model.maxBrightness : 0
            onValueChanged: display.brightnessAdjusted(model.displayName, value)
        }
    }
}
