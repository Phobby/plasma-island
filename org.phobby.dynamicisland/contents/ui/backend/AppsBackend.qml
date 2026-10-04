/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The installed applications, from the source Plasma's own launchers use:
    the system's application database (KService / KSycoca, built from the XDG
    .desktop files in the applications directories and the menu's rules about
    what is shown). It is read through plasma-workspace's "apps" data engine;
    its "launch" operation starts an application the way the launcher does
    (KIO::ApplicationLauncherJob: startup notification, the right activation).

    An application is identified by its menu id: the .desktop file's name, e.g.
    "org.kde.dolphin.desktop".

    Which of them run right now comes from the task manager's window list
    (the model exists only while something watches it).
*/
import QtQuick
import org.kde.plasma.plasma5support as P5
import org.kde.taskmanager as TaskManager

Item {
    id: apps

    // The list is only gathered while it is wanted (the "add an application" view).
    property bool listing: false
    // [{ id, name, generic, icon }] sorted by name: what a launcher's menu shows.
    readonly property var all: {
        const out = [];
        if (!listing) return out;
        for (const id of engine.connectedSources) {
            const d = engine.data[id];
            // Groups of the menu and hidden entries (NoDisplay, settings modules) are not applications to start.
            if (!d || d.isApp !== true || d.display !== true || /^kcm_/.test(id)) continue;
            const categories = d.categories || [];
            if (categories.indexOf("Settings") >= 0 && categories.indexOf("X-KDE-Settings-Dialog") >= 0) continue;
            out.push({ id: id, name: String(d.name || id), generic: String(d.genericName || ""), icon: String(d.iconName || "application-x-executable") });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }

    P5.DataSource {
        id: engine
        engine: "apps"
        connectedSources: apps.listing ? sources.filter(s => /\.desktop$/.test(s)) : []
    }
    // Starts are asked for through a source of their own, so that the list above is not needed for them.
    P5.DataSource {
        id: launcher
        engine: "apps"
    }
    function launch(id: string): bool {
        if (launcher.sources.indexOf(id) < 0) return false;
        launcher.connectSource(id);
        const service = launcher.serviceForSource(id);
        if (!service) return false;
        service.startOperationCall(service.operationDescription("launch"));
        launcher.disconnectSource(id);
        return true;
    }
    // Still installed? (an application that was removed keeps its shortcut, dimmed)
    function known(id: string): bool { return launcher.sources.indexOf(id) >= 0; }

    // ---- running ------------------------------------------------------------------
    property bool watching: false
    // Menu ids, lower case, without ".desktop", of the applications that have a window.
    property var running: []
    function isRunning(id: string): bool { return running.indexOf(id.toLowerCase().replace(/\.desktop$/, "")) >= 0; }
    Loader {
        id: tasks
        active: apps.watching
        sourceComponent: TaskManager.TasksModel {
            groupMode: TaskManager.TasksModel.GroupDisabled
            onCountChanged: Qt.callLater(apps.collect)
            Component.onCompleted: Qt.callLater(apps.collect)
        }
    }
    function collect(): void {
        const model = tasks.item, ids = [];
        for (let i = 0; model && i < model.count; ++i) {
            const id = String(model.data(model.makeModelIndex(i), TaskManager.AbstractTasksModel.AppId) || "").toLowerCase().replace(/\.desktop$/, "");
            if (id.length > 0 && ids.indexOf(id) < 0) ids.push(id);
        }
        if (ids.join(",") !== running.join(",")) running = ids;
    }
    onWatchingChanged: if (!watching) running = []
}
