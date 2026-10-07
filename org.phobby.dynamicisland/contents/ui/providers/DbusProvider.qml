/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Live Activities pushed by other programs over D-Bus (island-push, scripts,
    daemons). See README "D-Bus API".
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    property var core: null
    property bool enabled: true

    property var activities: ({})     // id → Activity
    property var timeouts: ({})       // id → Timer

    Component { id: activityComponent; Activity {} }
    Component { id: timerComponent; Timer {} }

    function colorFor(c: var): color {
        const named = { red: theme.red, green: theme.live, blue: theme.blue, orange: theme.orange,
                        purple: theme.purple, white: theme.text, gray: theme.subText, grey: theme.subText };
        if (!c) return theme.blue;
        const key = String(c).toLowerCase();
        return named[key] !== undefined ? named[key] : c;
    }

    function apply(a: Activity, p: var): void {
        if (p.title !== undefined) a.title = String(p.title);
        if (p.subtitle !== undefined) a.subtitle = String(p.subtitle);
        if (p.icon !== undefined) a.icon = String(p.icon);
        if (p.trailing !== undefined) a.trailingText = String(p.trailing);
        if (p.color !== undefined) a.color = colorFor(p.color);
        if (p.progress !== undefined) {
            const v = Number(p.progress);
            a.progress = v < 0 ? -1 : Math.min(100, v) / 100;
            if (p.trailing === undefined && v >= 0) a.trailingText = "";
        }
        if (p.priority !== undefined) a.priority = Number(p.priority);
        if (p.category !== undefined) a.category = String(p.category);
    }

    function push(id: string, p: var): void {
        if (!enabled) return;
        let a = activities[id];
        if (!a) {
            a = activityComponent.createObject(provider, {
                activityId: "dbus:" + id,
                category: "transfer",
                icon: "run-build",
                color: theme.blue
            });
            a.clicked.connect(() => { if (provider.core) provider.core.activityClicked(id); });
            activities[id] = a;
            manager.register(a);
        }
        apply(a, p);
        a.active = true;
        const secs = Number(p.timeout || 0);
        if (timeouts[id]) { timeouts[id].destroy(); delete timeouts[id]; }
        if (secs > 0) {
            const t = timerComponent.createObject(provider, { interval: secs * 1000, running: true });
            t.triggered.connect(() => provider.finish(id, ""));
            timeouts[id] = t;
        }
    }

    function finish(id: string, status: string): void {
        const a = activities[id];
        if (timeouts[id]) { timeouts[id].destroy(); delete timeouts[id]; }
        if (!a) return;
        const title = a.title;
        manager.unregister(a);
        a.active = false;
        delete activities[id];
        a.destroy();
        if (status === "success" || status === "error" || status === "cancel") {
            manager.flash({
                key: "dbus:" + id,
                icon: status === "success" ? "dialog-ok-apply-symbolic" : status === "error" ? "dialog-close-symbolic" : "dialog-cancel-symbolic",
                color: status === "success" ? theme.live : status === "error" ? theme.red : theme.subText,
                title: title,
                subtitle: status === "success" ? Lang.i18n("Done") : status === "error" ? Lang.i18n("Failed") : Lang.i18n("Cancelled"),
                activate: () => { if (provider.core) provider.core.activityClicked(id); }
            });
        }
    }

    Connections {
        target: provider.core
        ignoreUnknownSignals: true
        function onActivityPushed(id, props) { provider.push(id, props); }
        function onActivityFinished(id, status) { provider.finish(id, status); }
        function onEventFlashed(props) {
            if (!provider.enabled) return;
            provider.manager.flash({
                icon: String(props.icon || "help-about-symbolic"),
                color: provider.colorFor(props.color),
                title: String(props.title || ""),
                subtitle: String(props.subtitle || ""),
                trailing: props.progress !== undefined ? { type: "ring", value: Number(props.progress) / 100, color: provider.colorFor(props.color) }
                        : props.trailing !== undefined ? { type: "text", text: String(props.trailing) } : null,
                duration: Number(props.duration || 0) || undefined
            });
        }
    }
}
