/*
    SPDX-License-Identifier: GPL-2.0-or-later
    One of the embedded weather pictures (WeatherIcons.js), drawn in `color`:
    the theme's text colour, a status colour, anything.
*/
import QtQuick
import "WeatherIcons.js" as WeatherIcons

Image {
    id: icon

    // The picture's name: a file of contents/icons/weather without ".svg".
    property string name
    property color color: "white"

    width: 18
    height: 18
    // drawn at twice the size it is shown at: sharp when the island is scaled
    sourceSize: Qt.size(Math.max(1, Math.ceil(width)) * 2, Math.max(1, Math.ceil(height)) * 2)
    source: name.length > 0 ? WeatherIcons.image(name, String(Qt.rgba(color.r, color.g, color.b, 1))) : ""
    opacity: color.a
    smooth: true
}
