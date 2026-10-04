/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Weather": now (temperature, feels like, condition, humidity, wind) and
    the next days. The data and what it lacks: backend/WeatherBackend.qml.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    property var weather: null              // backend/WeatherBackend.qml
    // The place is chosen in the settings.
    signal setupRequested()

    function degrees(value: real): string { return isNaN(value) ? "–" : Math.round(value) + "°"; }
    function dayName(offset: int, night: bool): string {
        if (offset === 0) return night ? Lang.i18n("Tonight") : Lang.i18n("Today");
        const d = new Date();
        d.setDate(d.getDate() + offset);
        return d.toLocaleDateString(Lang.locale, "ddd");
    }

    // No place yet, or nothing came (no network, the place is gone).
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 40
        visible: !page.weather || !page.weather.ready
        spacing: 8
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            source: "weather-none-available-symbolic"
            color: page.theme.subText
            isMask: true
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall
            text: !page.weather || page.weather.place.length === 0 ? Lang.i18n("Choose a place to see its weather.")
                : page.weather.failed ? Lang.i18n("No weather was found for this place. Choose it again.")
                : Lang.i18n("Waiting for the weather…")
        }
        PillButton {
            Layout.alignment: Qt.AlignHCenter
            visible: !page.weather || page.weather.place.length === 0 || page.weather.failed
            theme: page.theme
            primary: true
            text: Lang.i18n("Choose a place…")
            onClicked: page.setupRequested()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: page.weather !== null && page.weather.ready
        spacing: 6

        // ---- now ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Kirigami.Icon {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                source: page.weather ? page.weather.icon : ""
            }
            Text {
                text: page.weather ? page.degrees(page.weather.temperature) : ""
                color: page.theme.text
                font.pointSize: page.theme.fontNormal * 2.3
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: page.weather ? page.weather.condition : ""
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: page.weather !== null && !isNaN(page.weather.feelsLike)
                    text: page.weather ? Lang.i18n("Feels like %1", page.degrees(page.weather.feelsLike)) : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: {
                        const w = page.weather, parts = [];
                        if (!w) return "";
                        if (w.humidity >= 0) parts.push(Lang.i18n("Humidity %1", Lang.percent(w.humidity)));
                        if (!isNaN(w.windKmh)) parts.push(Lang.i18n("Wind %1 km/h", Math.round(w.windKmh)) + (w.windDirection.length > 0 ? " " + w.windDirection : ""));
                        return parts.join(" · ");
                    }
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    elide: Text.ElideRight
                }
            }
            // Where, and how old the observation is
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.maximumWidth: 120
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: page.weather ? page.weather.placeName.split(",")[0] : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    visible: page.weather !== null && page.weather.observed !== null
                    text: page.weather && page.weather.observed ? Qt.formatTime(page.weather.observed, Lang.locale.timeFormat(Locale.ShortFormat)) : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.85
                    font.features: { "tnum": 1 }
                }
            }
        }

        // ---- the next days ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            Repeater {
                model: page.weather ? page.weather.days.slice(0, 6) : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 10
                    radius: 10
                    color: page.theme.faint
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: page.dayName(modelData.offset, modelData.night)
                            color: page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.85
                            elide: Text.ElideRight
                        }
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            source: modelData.icon
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: (isNaN(modelData.high) ? "" : page.degrees(modelData.high) + " ") + page.degrees(modelData.low)
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall * 0.85
                            font.features: { "tnum": 1 }
                        }
                        // Chance of rain, when it is worth a look
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            visible: modelData.chance >= 20
                            text: Lang.percent(Math.round(modelData.chance))
                            color: page.theme.readable(page.theme.blue, page.theme.surface)
                            font.pointSize: page.theme.fontSmall * 0.8
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }
}
