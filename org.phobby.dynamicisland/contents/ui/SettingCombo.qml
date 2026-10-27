/*
    SPDX-License-Identifier: GPL-2.0-or-later
    A choice for one setting of a settings page (its cfg_<key>; `settings`: the page): `model` the
    names in order, `values` what each one stores (the index when not given).
    Named "setting-<key>", so the search finds it.
*/
import QtQuick
import QtQuick.Controls as QQC2

QQC2.ComboBox {
    id: control
    required property var settings
    required property string key
    property var values: null
    objectName: "setting-" + key
    readonly property var stored: settings["cfg_" + key]
    Binding { target: control; property: "currentIndex"; value: control.values ? Math.max(0, control.values.indexOf(control.stored)) : Number(control.stored) }
    onActivated: index => control.settings["cfg_" + control.key] = control.values ? control.values[index] : index
    Accessible.name: currentText
}
