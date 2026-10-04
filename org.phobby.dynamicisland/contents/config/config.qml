import QtQuick
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
        name: Lang.i18n("Layout")
        icon: "view-sort"
        source: "configLayout.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Controls")
        icon: "configure"
        source: "configControls.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Activities")
        icon: "view-list-details"
        source: "configActivities.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Alerts")
        icon: "dialog-warning"
        source: "configAlerts.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Calendar")
        icon: "view-calendar"
        source: "configCalendar.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Weather")
        icon: "weather-clear"
        source: "configWeather.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Notes")
        icon: "view-pim-notes"
        source: "configNotes.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Tools")
        icon: "chronometer"
        source: "configTools.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Habits")
        icon: "view-calendar-tasks"
        source: "configHabits.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Suggestions")
        icon: "dialog-question"
        source: "configSuggestions.qml"
    }
    ConfigCategory {
        name: Lang.i18n("Language")
        icon: "preferences-desktop-locale"
        source: "configLanguage.qml"
    }
}
