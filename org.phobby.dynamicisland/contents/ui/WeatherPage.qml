/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Weather": now (temperature, feels like, condition, humidity, wind) and
    the next days; a click on a day slides its hours in from the side (hour,
    picture, temperature, feels like, chance and amount of precipitation,
    humidity, wind), with the day's high and low and sunrise and sunset on top.

    Nothing is shown and nothing is asked until a place is chosen: the page
    starts empty with "Choose a Location", which opens a search by name. The
    place can be changed at any time (its name at the top right).

    The data and what is sent for it: backend/WeatherBackend.qml,
    WeatherData.js. Pictures: contents/icons/weather, drawn in the theme's
    colour. The page reads no clock: "now" and "today" are the backend's.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    property var weather: null              // backend/WeatherBackend.qml
    // The name of the place of the earlier weather source, to start the first search with.
    property string earlierName: ""
    // A place was chosen: its JSON, to be stored (WeatherBackend.location).
    signal locationPicked(string json)

    // "now" | "search"; the hours of a day slide over "now" (`shownDay`)
    property string view: "now"
    property int shownDay: -1               // index into weather.days; -1 = none
    readonly property var day: weather !== null && shownDay >= 0 && shownDay < weather.days.length ? weather.days[shownDay] : null
    readonly property bool hasPlace: weather !== null && weather.hasPlace
    readonly property bool ready: weather !== null && weather.ready
    // The weather now; null until there is some.
    readonly property var current: weather !== null ? weather.current : null

    // The search field has the keyboard: the island stays open and focused.
    property bool typing: false
    readonly property bool interacting: visible && typing
    onVisibleChanged: if (!visible) { typing = false; shownDay = -1; if (view === "search") view = "now"; } else if (weather !== null) weather.refreshIfStale()
    Component.onCompleted: if (visible && weather !== null) weather.refreshIfStale()
    onReadyChanged: if (!ready) shownDay = -1

    // ---- choosing a place -------------------------------------------------------------
    property var found: []
    property bool searching: false
    // "" | "none" | "offline" | "service"
    property string searchProblem: ""
    function openSearch(): void {
        found = []; searchProblem = ""; searching = false;
        view = "search"; typing = true; shownDay = -1;
        searchField.text = hasPlace ? "" : earlierName.split(",")[0].trim();
        Qt.callLater(() => { searchField.input.forceActiveFocus(); searchField.input.selectAll(); });
    }
    function closeSearch(): void { typing = false; view = "now"; lookUp.stop(); }
    function look(): void {
        const text = searchField.text.trim();
        if (weather === null || text.length < 2) { found = []; searching = false; searchProblem = ""; return; }
        searching = true;
        weather.search(text, (results, problem) => {
            page.searching = false;
            page.found = results;
            page.searchProblem = problem.length > 0 ? problem : results.length === 0 ? "none" : "";
        });
    }
    // Asked while typing, but not for every letter.
    Timer { id: lookUp; interval: 400; onTriggered: page.look() }
    function pick(place: var): void {
        locationPicked(JSON.stringify({ name: place.name, admin: place.admin, country: place.country, latitude: place.latitude, longitude: place.longitude }));
        closeSearch();
    }

    function dayName(d: var, full: bool): string {
        if (!full && d.offset === 0) return page.current !== null && !page.current.day ? Lang.i18n("Tonight") : Lang.i18n("Today");
        const date = new Date(Number(d.date.slice(0, 4)), Number(d.date.slice(5, 7)) - 1, Number(d.date.slice(8, 10)), 12);
        return date.toLocaleDateString(Lang.locale, full ? "dddd, d MMMM" : "ddd");
    }

    component Glyph: WeatherIcon {
        color: page.theme.text
    }

    // column widths of a day's hours, left to right; the wind takes the rest
    readonly property var columns: [38, 18, 36, 58, 44, 40, 40]
    component Cell: Text {
        property int column: 0
        Layout.preferredWidth: page.columns[column]
        horizontalAlignment: column === 0 ? Text.AlignLeft : Text.AlignRight
        color: page.theme.text
        font.pointSize: page.theme.fontSmall * 0.9
        font.features: { "tnum": 1 }
        elide: Text.ElideRight
    }

    // ---- no place yet -----------------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 40
        visible: page.view === "now" && !page.hasPlace
        spacing: 8
        Glyph {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            name: "map-pin"
            color: page.theme.subText
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall
            text: Lang.i18n("Choose a place to see its weather.")
        }
        PillButton {
            Layout.alignment: Qt.AlignHCenter
            theme: page.theme
            primary: true
            text: Lang.i18n("Choose a Location")
            onClicked: page.openSearch()
        }
    }

    // ---- a place, but no weather (yet) ---------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 40
        visible: page.view === "now" && page.hasPlace && !page.ready
        spacing: 8
        Glyph {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            name: "cloud"
            color: page.theme.subText
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall
            text: page.weather === null ? ""
                : page.weather.problem === "offline" ? Lang.i18n("No connection: the weather of %1 could not be fetched.", page.weather.placeName)
                : page.weather.problem === "service" ? Lang.i18n("The weather service did not answer for %1.", page.weather.placeName)
                : Lang.i18n("Waiting for the weather…")
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            PillButton {
                visible: page.weather !== null && page.weather.problem.length > 0
                theme: page.theme
                primary: true
                text: Lang.i18n("Try again")
                onClicked: page.weather.refresh()
            }
            PillButton {
                theme: page.theme
                text: Lang.i18n("Change the Location")
                onClicked: page.openSearch()
            }
        }
    }

    // ---- searching a place by its name ---------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "search"
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            IconButton {
                iconName: "go-previous-symbolic"
                iconSize: 12
                implicitWidth: 22; implicitHeight: 22
                color: page.theme.text
                hoverColor: page.theme.faint
                onClicked: page.closeSearch()
            }
            PillField {
                id: searchField
                theme: page.theme
                Layout.fillWidth: true
                implicitHeight: 26
                placeholder: Lang.i18n("City")
                onEdited: { page.searchProblem = ""; lookUp.restart(); }
                onAccepted: { lookUp.stop(); page.look(); }
                onEscaped: page.closeSearch()
                MouseArea {
                    anchors.fill: parent
                    visible: !page.typing
                    cursorShape: Qt.IBeamCursor
                    onClicked: { page.typing = true; Qt.callLater(() => searchField.input.forceActiveFocus()); }
                }
            }
        }
        ListView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: page.found
            delegate: Rectangle {
                id: result
                required property var modelData
                width: results.width
                height: 24
                radius: 8
                color: resultMouse.pressed ? page.theme.pressedFill : resultMouse.containsMouse ? page.theme.hoverFill : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Text {
                        text: result.modelData.name
                        color: page.theme.text
                        font.pointSize: page.theme.fontSmall
                        font.weight: Font.DemiBold
                    }
                    // region, country
                    Text {
                        Layout.fillWidth: true
                        text: [result.modelData.admin !== result.modelData.name ? result.modelData.admin : "", result.modelData.country].filter(t => t.length > 0).join(", ")
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.9
                        elide: Text.ElideRight
                    }
                }
                MouseArea { id: resultMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.pick(result.modelData) }
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 20
                visible: results.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
                text: page.searching ? Lang.i18n("Searching…")
                    : page.searchProblem === "none" ? Lang.i18n("No place was found by that name.")
                    : page.searchProblem === "offline" ? Lang.i18n("No connection: places cannot be searched right now.")
                    : page.searchProblem === "service" ? Lang.i18n("The search did not answer; try again in a moment.")
                    : Lang.i18n("Type the name of a city; the results appear as you type.")
            }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: Lang.i18n("Weather data by Open-Meteo.com")
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall * 0.75
        }
    }

    // ---- now, and the days --------------------------------------------------------------
    ColumnLayout {
        id: nowView
        width: parent.width
        height: parent.height
        // moves aside while a day's hours are shown
        x: page.day !== null ? -Math.round(parent.width * 0.25) : 0
        opacity: page.day !== null ? 0 : 1
        visible: page.view === "now" && page.ready && opacity > 0.01
        spacing: 6
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Glyph {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                name: page.current !== null ? page.weather.icon : ""
            }
            Text {
                text: page.current !== null ? page.weather.degrees(page.current.temperature) : ""
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
                    text: page.current !== null ? page.weather.describe(page.current.kind, page.current.day) : ""
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: page.current !== null && !isNaN(page.current.feelsLike)
                    text: page.current !== null ? Lang.i18n("Feels like %1", page.weather.degrees(page.current.feelsLike)) : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: {
                        const c = page.current, parts = [];
                        if (c === null) return "";
                        if (!isNaN(c.humidity)) parts.push(Lang.i18n("Humidity %1", Lang.percent(Math.round(c.humidity))));
                        if (!isNaN(c.wind)) parts.push(Lang.i18n("Wind %1 %2", page.weather.speed(c.wind), page.weather.speedUnit) + " " + page.weather.windName(c.windDirection));
                        return parts.join(" · ");
                    }
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    elide: Text.ElideRight
                }
            }
            // Where: a click changes the place.
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.maximumWidth: 130
                implicitWidth: placeRow.implicitWidth + 12
                implicitHeight: 22
                radius: 11
                color: placeMouse.pressed ? page.theme.pressedFill : placeMouse.containsMouse ? page.theme.faint : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                RowLayout {
                    id: placeRow
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 3
                    Glyph {
                        Layout.preferredWidth: 11
                        Layout.preferredHeight: 11
                        name: "map-pin"
                        color: page.theme.subText
                    }
                    Text {
                        Layout.fillWidth: true
                        text: page.weather !== null ? page.weather.placeName : ""
                        color: placeMouse.containsMouse ? page.theme.text : page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.9
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
                MouseArea { id: placeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openSearch() }
            }
        }

        // The days: under the pointer one lifts and lights up; a click shows its hours.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            Repeater {
                model: page.ready ? Math.min(7, page.weather.days.length) : 0
                delegate: Rectangle {
                    id: card
                    required property int index
                    readonly property var d: page.weather.days[index] ?? null
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 10
                    radius: 10
                    color: cardMouse.pressed ? page.theme.over(page.theme.pressedFill, page.theme.over(page.theme.faint, page.theme.surface))
                         : cardMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                         : page.theme.faint
                    scale: cardMouse.pressed ? 0.97 : cardMouse.containsMouse ? 1.06 : 1
                    z: cardMouse.containsMouse ? 1 : 0
                    transform: Translate { y: cardMouse.containsMouse && !cardMouse.pressed ? -2 : 0; Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: card.d !== null ? page.dayName(card.d, false) : ""
                            color: cardMouse.containsMouse ? page.theme.text : page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.85
                            elide: Text.ElideRight
                        }
                        Glyph {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            name: card.d !== null ? page.weather.iconFor(card.d.kind, true) : ""
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: card.d !== null ? page.weather.degrees(card.d.high) + " " + page.weather.degrees(card.d.low) : ""
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall * 0.85
                            font.features: { "tnum": 1 }
                        }
                        // Chance of rain, when it is worth a look
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            visible: card.d !== null && card.d.chance >= 20
                            text: card.d !== null && !isNaN(card.d.chance) ? Lang.percent(Math.round(card.d.chance)) : ""
                            color: page.theme.readable(page.theme.blue, page.theme.surface)
                            font.pointSize: page.theme.fontSmall * 0.8
                            font.features: { "tnum": 1 }
                        }
                    }
                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.shownDay = card.index
                    }
                }
            }
        }
    }

    // ---- one day, hour by hour: slides in from the right ------------------------------------
    Item {
        id: dayView
        width: parent.width
        height: parent.height
        x: page.day !== null ? 0 : parent.width
        opacity: page.day !== null ? 1 : 0
        visible: page.view === "now" && opacity > 0.01
        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        // What is shown stays while the view slides out.
        property var d: null
        Connections {
            target: page
            function onDayChanged() {
                if (page.day === null) return;
                dayView.d = page.day;
                // today: from this hour on; another day: from the morning
                const at = page.day.hours.findIndex(h => h.now), count = page.day.hours.length;
                Qt.callLater(() => hours.positionViewAtIndex(at >= 0 ? at : Math.min(6, Math.max(0, count - 1)), ListView.Beginning));
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 2

            // the day in short: its name, picture, high and low, sunrise and sunset
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 6
                IconButton {
                    iconName: "go-previous-symbolic"
                    iconSize: 12
                    implicitWidth: 22; implicitHeight: 22
                    color: page.theme.text
                    hoverColor: page.theme.faint
                    onClicked: page.shownDay = -1
                }
                Text {
                    text: dayView.d !== null ? page.dayName(dayView.d, true) : ""
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                }
                Glyph {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    name: dayView.d !== null ? page.weather.iconFor(dayView.d.kind, true) : ""
                }
                Text {
                    Layout.fillWidth: true
                    text: dayView.d !== null ? Lang.i18n("High %1 · Low %2", page.weather.degrees(dayView.d.high), page.weather.degrees(dayView.d.low)) : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    font.features: { "tnum": 1 }
                    elide: Text.ElideRight
                }
                Glyph {
                    visible: dayView.d !== null && dayView.d.sunrise.length > 0
                    Layout.preferredWidth: 13
                    Layout.preferredHeight: 13
                    name: "sunrise"
                    color: page.theme.subText
                }
                Text {
                    visible: dayView.d !== null && dayView.d.sunrise.length > 0
                    text: dayView.d !== null ? dayView.d.sunrise : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    font.features: { "tnum": 1 }
                }
                Glyph {
                    visible: dayView.d !== null && dayView.d.sunset.length > 0
                    Layout.preferredWidth: 13
                    Layout.preferredHeight: 13
                    name: "sunset"
                    color: page.theme.subText
                }
                Text {
                    visible: dayView.d !== null && dayView.d.sunset.length > 0
                    text: dayView.d !== null ? dayView.d.sunset : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    font.features: { "tnum": 1 }
                }
            }
            // what the columns are
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 8
                spacing: 6
                Cell { column: 0; text: Lang.i18nc("@title:column the hour of the day", "Hour"); color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.75 }
                Cell { column: 1; text: "" }
                Cell { column: 2; text: page.weather !== null ? page.weather.degreeUnit : ""; color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.75 }
                Cell { column: 3; text: Lang.i18nc("@title:column the temperature it feels like", "Feels like"); color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.75 }
                Cell { column: 4; text: Lang.i18nc("@title:column chance of precipitation", "Rain"); color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.75 }
                Cell { column: 5; text: page.weather !== null ? page.weather.amountUnit : ""; color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.75 }
                Cell { column: 6; text: Lang.i18nc("@title:column relative humidity", "Humid."); color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.75 }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: page.weather !== null ? Lang.i18nc("@title:column wind speed and its unit", "Wind, %1", page.weather.speedUnit) : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.75
                    elide: Text.ElideRight
                }
            }
            ListView {
                id: hours
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds
                model: dayView.d !== null ? dayView.d.hours.length : 0
                delegate: Rectangle {
                    id: row
                    required property int index
                    readonly property var h: dayView.d !== null ? (dayView.d.hours[index] ?? null) : null
                    readonly property bool now: h !== null && h.now
                    width: hours.width
                    height: 19
                    radius: 7
                    // the hour it is
                    color: now ? page.theme.faint : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 8
                        spacing: 6
                        Cell { column: 0; text: row.h !== null ? row.h.time : ""; font.weight: row.now ? Font.Bold : Font.Normal; color: row.now ? page.theme.text : page.theme.subText }
                        Glyph {
                            Layout.preferredWidth: page.columns[1]
                            Layout.preferredHeight: 14
                            name: row.h !== null ? page.weather.iconFor(row.h.kind, row.h.day) : ""
                        }
                        Cell { column: 2; text: row.h !== null ? page.weather.degrees(row.h.temperature) : ""; font.weight: Font.DemiBold }
                        Cell { column: 3; text: row.h !== null ? page.weather.degrees(row.h.feelsLike) : ""; color: page.theme.subText }
                        Cell {
                            column: 4
                            text: row.h === null || isNaN(row.h.chance) ? "–" : Lang.percent(Math.round(row.h.chance))
                            color: row.h !== null && row.h.chance >= 20 ? page.theme.readable(page.theme.blue, page.theme.surface) : page.theme.subText
                        }
                        Cell {
                            column: 5
                            text: row.h !== null && row.h.precipitation > 0 ? page.weather.amount(row.h.precipitation) : "–"
                            color: row.h !== null && row.h.precipitation > 0 ? page.theme.readable(page.theme.blue, page.theme.surface) : page.theme.subText
                        }
                        Cell { column: 6; text: row.h === null || isNaN(row.h.humidity) ? "–" : Lang.percent(Math.round(row.h.humidity)) }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: row.h !== null ? page.weather.speed(row.h.wind) + " " + page.weather.windName(row.h.windDirection) : ""
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall * 0.9
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
