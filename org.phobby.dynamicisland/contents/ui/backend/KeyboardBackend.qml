/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Caps/Num Lock state and the active keyboard layout.
*/
import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.workspace.keyboardlayout as KeyboardLayouts

Item {
    id: keyboard

    readonly property bool capsLock: caps.locked
    readonly property bool numLock: num.locked
    readonly property var currentLayout: layouts.layoutsList.length > layouts.layout ? layouts.layoutsList[layouts.layout] : null
    readonly property string layoutShortName: currentLayout ? currentLayout.shortName : ""
    readonly property string layoutName: currentLayout ? (currentLayout.longName || currentLayout.displayName || currentLayout.shortName) : ""

    KeyboardIndicator.KeyState { id: caps; key: Qt.Key_CapsLock }
    KeyboardIndicator.KeyState { id: num; key: Qt.Key_NumLock }
    KeyboardLayouts.KeyboardLayout { id: layouts }
}
