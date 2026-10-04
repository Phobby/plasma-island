/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Weather: the place (searched by name at BBC Weather, the provider of
    Plasma's weather engine that needs no account) and the alert for rain,
    snow and storms. Whether the Weather tab is shown is set in Layout.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property string cfg_weatherPlace
    property string cfg_weatherPlaceName
    property alias cfg_showWeatherAlerts: alertsCheck.checked

    // The search runs through the same backend as the island (null without Plasma's weather engine).
    Loader { id: backend; source: "backend/WeatherBackend.qml" }
    readonly property var weather: backend.status === Loader.Ready ? backend.item : null
    Binding { target: page.weather; property: "enabled"; value: false; when: page.weather !== null }

    property var found: []
    property bool searching: false
    property bool searched: false
    function search(): void {
        if (!weather || searchField.text.trim().length === 0) return;
        searching = true; searched = false; found = [];
        weather.search(searchField.text, results => { page.searching = false; page.searched = true; page.found = results; });
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.label: Lang.i18n("Place:")
            text: page.cfg_weatherPlaceName.length > 0 ? page.cfg_weatherPlaceName : Lang.i18n("None chosen yet")
            font.weight: page.cfg_weatherPlaceName.length > 0 ? Font.DemiBold : Font.Normal
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
                enabled: !page.searching && searchField.text.trim().length > 0
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
                    icon.name: page.cfg_weatherPlace === modelData.place ? "checkmark" : "mark-location"
                    text: modelData.name
                    onClicked: { page.cfg_weatherPlace = modelData.place; page.cfg_weatherPlaceName = modelData.name; }
                }
            }
        }
        QQC2.Label {
            visible: page.searched && page.found.length === 0
            text: Lang.i18n("No place was found by that name.")
            opacity: 0.7
        }
        QQC2.Label {
            visible: page.weather === null
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            text: Lang.i18n("Plasma's weather engine was not found on this system, so there is no weather to show.")
            opacity: 0.7
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("The weather comes from BBC Weather through Plasma's own weather engine, without an account; the name of the place is sent to it. It is asked again every 30 minutes. Plasma has no working location service to find the place by itself.")
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
            text: Lang.i18n("Shown once, for a few seconds, when the forecast for today, tonight or tomorrow says so. The forecast is by the day, so it cannot say the minute it starts.")
        }
    }
}
