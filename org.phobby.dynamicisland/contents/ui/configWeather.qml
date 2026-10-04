/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Weather: the place (searched by name, as on the island's Weather page),
    the units and the alert for rain, snow and storms. Whether the Weather tab
    is shown is set in Layout.

    The search asks Open-Meteo's geocoding service when "Search" is pressed,
    not before and not while typing here.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "WeatherData.js" as WeatherData

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property string cfg_weatherLocation
    property alias cfg_weatherUnits: unitsCombo.currentIndex
    property alias cfg_showWeatherAlerts: alertsCheck.checked

    readonly property var place: WeatherData.parsePlace(cfg_weatherLocation)

    // Only its search is used here: switched off, it fetches no weather.
    Loader { id: backend; source: "backend/WeatherBackend.qml" }
    readonly property var weather: backend.status === Loader.Ready ? backend.item : null
    Binding { target: page.weather; property: "enabled"; value: false; when: page.weather !== null }

    property var found: []
    property bool searching: false
    // "" | "none" | "offline" | "service"
    property string problem: ""
    function search(): void {
        if (!weather || searchField.text.trim().length < 2) return;
        searching = true; problem = ""; found = [];
        weather.search(searchField.text, (results, error) => {
            page.searching = false;
            page.found = results;
            page.problem = error.length > 0 ? error : results.length === 0 ? "none" : "";
        });
    }
    function pick(result: var): void {
        cfg_weatherLocation = JSON.stringify({ name: result.name, admin: result.admin, country: result.country, latitude: result.latitude, longitude: result.longitude });
        found = [];
        searchField.text = "";
    }

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Place:")
            QQC2.Label {
                text: page.place !== null ? WeatherData.placeLabel(page.place) : Lang.i18n("None chosen yet")
                font.weight: page.place !== null ? Font.DemiBold : Font.Normal
            }
            QQC2.ToolButton {
                visible: page.place !== null
                icon.name: "edit-clear"
                display: QQC2.AbstractButton.IconOnly
                text: Lang.i18n("Forget the place")
                onClicked: page.cfg_weatherLocation = ""
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: text
            }
        }
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Search:")
            enabled: page.weather !== null
            QQC2.TextField {
                id: searchField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                placeholderText: Lang.i18n("City")
                onAccepted: page.search()
            }
            QQC2.Button {
                icon.name: "search"
                text: Lang.i18n("Search")
                enabled: !page.searching && searchField.text.trim().length >= 2
                onClicked: page.search()
            }
            QQC2.BusyIndicator {
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                Layout.preferredWidth: Layout.preferredHeight
                visible: page.searching
                running: visible
            }
        }
        ColumnLayout {
            visible: page.found.length > 0
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: page.found
                delegate: QQC2.Button {
                    required property var modelData
                    Layout.fillWidth: true
                    icon.name: "mark-location"
                    text: WeatherData.placeLabel(modelData)
                    onClicked: page.pick(modelData)
                }
            }
        }
        QQC2.Label {
            visible: page.problem.length > 0
            text: page.problem === "none" ? Lang.i18n("No place was found by that name.")
                : page.problem === "offline" ? Lang.i18n("No connection: places cannot be searched right now.")
                : Lang.i18n("The search did not answer; try again in a moment.")
            opacity: 0.7
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("The place is never detected: the Weather page starts empty and it is chosen by name, here or on the page. Weather and search come from Open-Meteo.com, without an account or a key. What is sent: the text that is searched for, and the coordinates of the chosen place (for its weather, every 30 minutes while the page is switched on). Nothing else.")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Units")
        }
        QQC2.ComboBox {
            id: unitsCombo
            Kirigami.FormData.label: Lang.i18n("Show in:")
            model: [Lang.i18n("°C, km/h, mm"), Lang.i18n("°F, mph, inches")]
            // The texts change with the language: the choice stays.
            property int chosen: 0
            onActivated: chosen = currentIndex
            onModelChanged: Qt.callLater(() => { if (currentIndex !== chosen) currentIndex = chosen; })
            Component.onCompleted: chosen = currentIndex
            onCurrentIndexChanged: if (currentIndex >= 0) chosen = currentIndex
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("The names of days, conditions and wind directions follow the widget's language (Language).")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Alert")
        }
        QQC2.CheckBox {
            id: alertsCheck
            Kirigami.FormData.label: Lang.i18n("On the island:")
            text: Lang.i18n("Announce rain, snow and storms")
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("Shown once, for a few seconds, when the forecast for today, tonight or tomorrow says so.")
        }
    }
}
