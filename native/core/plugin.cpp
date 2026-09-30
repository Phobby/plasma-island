// SPDX-License-Identifier: GPL-2.0-or-later
#include <QQmlEngineExtensionPlugin>

extern void qml_register_types_org_phobby_dynamicisland_core();
Q_GHS_KEEP_REFERENCE(qml_register_types_org_phobby_dynamicisland_core)

class DynamicIslandCorePlugin : public QQmlEngineExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)

public:
    DynamicIslandCorePlugin(QObject *parent = nullptr)
        : QQmlEngineExtensionPlugin(parent)
    {
        volatile auto registration = &qml_register_types_org_phobby_dynamicisland_core;
        Q_UNUSED(registration)
    }
};

#include "plugin.moc"
