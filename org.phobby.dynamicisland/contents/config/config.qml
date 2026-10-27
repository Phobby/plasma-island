/*
    SPDX-License-Identifier: GPL-2.0-or-later
    The pages of the settings window, in their order: what every island has
    first (General, Appearance, Tabs, Activities), then a page for each tab
    that has settings of its own, there only while that tab is on (the search
    of every page finds their settings also while it is off: SettingsIndex),
    then the cat, suggestions and Diagnostics (with the island's about and
    its tour).
*/
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../ui"
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: Lang.i18n("General")
        icon: "preferences-desktop-plasma"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Appearance")
        icon: "preferences-desktop-theme-global"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Tabs")
        icon: "view-sort"
        source: "configLayout.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Activities")
        icon: "view-list-details"
        source: "configActivities.qml"
    }
    // ---- the tabs' own pages: while the tab is on ----------------------------------------
    ConfigCategory {
        name: Lang.i18n("Weather")
        icon: "weather-clear"
        source: "configWeather.qml"
        visible: Plasmoid.configuration.showWeather
    }
    ConfigCategory {
        name: Lang.i18n("Controls")
        icon: "configure"
        source: "configControls.qml"
        visible: Plasmoid.configuration.showQuickSettings
    }
    ConfigCategory {
        name: Lang.i18n("Tools")
        icon: "chronometer"
        source: "configTools.qml"
        visible: Plasmoid.configuration.showTools
    }
    ConfigCategory {
        name: Lang.i18n("Habits")
        icon: "view-calendar-tasks"
        source: "configHabits.qml"
        visible: Plasmoid.configuration.showHabits
    }
    ConfigCategory {
        name: Lang.i18n("Calendar")
        icon: "view-calendar"
        source: "configCalendar.qml"
        visible: Plasmoid.configuration.showCalendar
    }
    ConfigCategory {
        name: Lang.i18n("Notes")
        icon: "view-pim-notes"
        source: "configNotes.qml"
        visible: Plasmoid.configuration.showNotes
    }
    ConfigCategory {
        name: Lang.i18n("AI")
        // The tab's own picture (Lucide's sparkles). The settings window cannot colour a file of
        // the widget, so there is one for a dark and one for a light window.
        icon: Qt.resolvedUrl(Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
                             ? "../icons/ai/sparkles-on-dark.svg" : "../icons/ai/sparkles-on-light.svg")
        source: "configAi.qml"
        visible: Plasmoid.configuration.showAi
    }
    ConfigCategory {
        name: Lang.i18n("Cloud")
        icon: "folder-cloud"
        source: "configCloud.qml"
        visible: Plasmoid.configuration.showCloud
    }
    // ---- the rest -----------------------------------------------------------------------
    ConfigCategory {
        name: Lang.i18n("Cat")
        icon: "face-smile"
        source: "configCat.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Suggestions")
        icon: "dialog-question"
        source: "configSuggestions.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Diagnostics")
        icon: "tools-report-bug"
        source: "configDiagnostics.qml"
    }
}
