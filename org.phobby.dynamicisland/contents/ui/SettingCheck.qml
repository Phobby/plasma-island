/*
    SPDX-License-Identifier: GPL-2.0-or-later
    A check box for one setting of a settings page (its cfg_<key>; `settings`: the page): shows it
    and writes it back. Named "setting-<key>", so the search finds it.
*/
import QtQuick
import QtQuick.Controls as QQC2

QQC2.CheckBox {
    id: control
    required property var settings
    required property string key
    objectName: "setting-" + key
    Binding { target: control; property: "checked"; value: control.settings["cfg_" + control.key] === true }
    onToggled: control.settings["cfg_" + control.key] = checked
    Accessible.name: text
}
