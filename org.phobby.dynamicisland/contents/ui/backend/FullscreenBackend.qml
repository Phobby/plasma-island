/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Whether a window fills the screen (a film, a game, a talk, a browser's F11,
    a terminal): the suggestions keep quiet then, and the island does what the
    full-screen mode says. What counts: Fullscreen.js. The window manager's own
    full-screen flag of every window, as Plasma's task manager hands it over,
    for the windows of this screen, of the desktop shown and of the activity
    shown: a full-screen window on another desktop, or behind another window,
    does not count. Told by the task manager's model on a change; nothing is
    polled, and no window's title or application is looked at.

    And, where `area` is given (the notch's place, global coordinates),
    whether a window reaches into it, as a panel's "Dodge windows" asks: any
    window of this screen, desktop and activity that is not minimised (a
    window moved up to the edge; a maximised one where `maximized` is wanted).
    Only where windows are and whether they are minimised is looked at.

    (A window that asks to be left off the taskbar is left out by the task
    manager, and so here: a full-screen one of those is not seen.)
*/
import QtQuick
import org.kde.taskmanager as TaskManager
import "../Fullscreen.js" as Fullscreen

Item {
    id: watch
    property bool active: false
    // Only a window on this screen counts (global coordinates); an empty one: any screen.
    property rect screen: Qt.rect(0, 0, 0, 0)
    // Where the notch is (global coordinates); empty: not looked at.
    property rect area: Qt.rect(0, 0, 0, 0)
    // Whether a maximised window counts as one that fills the screen (Appearance › Layout).
    property bool maximized: false
    property bool covered: false
    function windows(): var {
        const out = [];
        const R = TaskManager.AbstractTasksModel;
        const activeRow = tasks.activeTask.valid ? tasks.activeTask.row : -1;
        for (let i = 0; i < tasks.count; ++i) {
            const index = tasks.index(i, 0);
            const last = tasks.data(index, R.LastActivated);
            out.push({ fullScreen: tasks.data(index, R.IsFullScreen) === true,
                       maximized: tasks.data(index, R.IsMaximized) === true,
                       minimized: tasks.data(index, R.IsMinimized) === true,
                       active: i === activeRow,
                       lastActivated: last instanceof Date && !isNaN(last.getTime()) ? last.getTime() : 0,
                       geometry: tasks.data(index, R.Geometry) });
        }
        return out;
    }
    // QT_LOGGING_RULES="island.fullscreen.debug=true": every window looked at, and what came of it.
    readonly property LoggingCategory log: LoggingCategory { name: "island.fullscreen"; defaultLogLevel: LoggingCategory.Warning }
    function look(): void {
        const all = windows();
        // (with no screen given: the screen is the active window's own size)
        active = Fullscreen.fills(all, screen.width > 0 ? screen : null, maximized);
        covered = Fullscreen.reaches(all, area, maximized);
        console.debug(watch.log, "windows:", JSON.stringify(all), "screen:", JSON.stringify(screen),
                      "desktop:", desktops.currentDesktop, "fills:", active, "reaches:", covered);
    }
    // (many changes come at once, a title changing over and over among them: looked at once, after them)
    function later(): void { Qt.callLater(watch.look); }
    onAreaChanged: later()
    onMaximizedChanged: later()
    onScreenChanged: later()
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: watch.screen.width > 0
        screenGeometry: watch.screen
        // (without a desktop or an activity given, the task manager does not filter by them at all)
        filterByVirtualDesktop: true
        virtualDesktop: desktops.currentDesktop
        filterByActivity: true
        activity: activities.currentActivity
        onActiveTaskChanged: watch.later()
        onDataChanged: watch.later()
        onCountChanged: watch.later()
        onRowsInserted: watch.later()
        onRowsRemoved: watch.later()
        onModelReset: watch.later()
        onLayoutChanged: watch.later()
        onScreenGeometryChanged: watch.later()
        onVirtualDesktopChanged: watch.later()
        onActivityChanged: watch.later()
        Component.onCompleted: watch.look()
    }
}
