// SPDX-License-Identifier: GPL-2.0-or-later
#include <QQmlEngineExtensionPlugin>

extern void qml_register_types_org_phobby_dynamicisland_effects();
Q_GHS_KEEP_REFERENCE(qml_register_types_org_phobby_dynamicisland_effects)

class DynamicIslandEffectsPlugin : public QQmlEngineExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)

public:
    DynamicIslandEffectsPlugin(QObject *parent = nullptr)
        : QQmlEngineExtensionPlugin(parent)
    {
        volatile auto registration = &qml_register_types_org_phobby_dynamicisland_effects;
        Q_UNUSED(registration)
    }
};

#include "plugin.moc"
