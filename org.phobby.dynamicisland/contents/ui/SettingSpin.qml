/*
    SPDX-License-Identifier: GPL-2.0-or-later
    A number for one setting of a settings page (its cfg_<key>; `settings`: the page), with its unit
    (`unit`: "%1 px", "%1 ms"…; `scale`: shown as value / scale, e.g. seconds
    of milliseconds). Named "setting-<key>", so the search finds it.
*/
import QtQuick
import QtQuick.Controls as QQC2

QQC2.SpinBox {
    id: control
    required property var settings
    required property string key
    property string unit: "%1"
    property real scale: 1
    property int decimals: 0
    objectName: "setting-" + key
    editable: true
    Binding { target: control; property: "value"; value: Number(control.settings["cfg_" + control.key]) }
    onValueModified: control.settings["cfg_" + control.key] = value
    textFromValue: (v, locale) => Lang.substitute(unit, [Number(v / scale).toLocaleString(locale, "f", decimals)])
    valueFromText: (text, locale) => Math.round(Number.fromLocaleString(locale, text.replace(/[^0-9,.\-]/g, "")) * scale)
    Accessible.name: textFromValue(value, locale)
}
