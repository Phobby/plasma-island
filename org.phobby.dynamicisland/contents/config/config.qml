import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "preferences-desktop-plasma"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Activities")
        icon: "view-list-details"
        source: "configActivities.qml"
    }
    ConfigCategory {
        name: i18n("Alerts")
        icon: "dialog-warning"
        source: "configAlerts.qml"
    }
    ConfigCategory {
        name: i18n("Tools")
        icon: "chronometer"
        source: "configTools.qml"
    }
}
