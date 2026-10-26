/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Whether a window fills the screen (a film, a game, a talk): the suggestions
    keep quiet then, and the island does what the full-screen mode says. Told
    by the task manager's model on a change; nothing is polled, and no
    window's title or application is looked at. What counts: Fullscreen.js.

    And, where `area` is given (the notch's place, global coordinates),
    whether a window reaches into it, as a panel's "Dodge windows" asks: any
    window of this screen, desktop and activity that is not minimised (a
    maximised one, a window moved up to the edge). Only where windows are
    and whether they are minimised is looked at.
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
    property bool covered: false
    function windows(): var {
        const out = [];
        const activeRow = tasks.activeTask.valid ? tasks.activeTask.row : -1;
        for (let i = 0; i < tasks.count; ++i) {
            const index = tasks.index(i, 0);
            out.push({ fullScreen: tasks.data(index, TaskManager.AbstractTasksModel.IsFullScreen) === true,
                       maximized: tasks.data(index, TaskManager.AbstractTasksModel.IsMaximized) === true,
                       minimized: tasks.data(index, TaskManager.AbstractTasksModel.IsMinimized) === true,
                       active: i === activeRow,
                       geometry: tasks.data(index, TaskManager.AbstractTasksModel.Geometry) });
        }
        return out;
    }
    function look(): void {
        const all = windows();
        // (with no screen given: the screen is the active window's own size)
        active = Fullscreen.fills(all, screen.width > 0 ? screen : null);
        covered = Fullscreen.reaches(all, area);
    }
    onAreaChanged: look()
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: watch.screen.width > 0
        screenGeometry: watch.screen
        filterByVirtualDesktop: true
        filterByActivity: true
        onActiveTaskChanged: watch.look()
        onDataChanged: watch.look()
        onCountChanged: watch.look()
        onScreenGeometryChanged: watch.look()
        Component.onCompleted: watch.look()
    }
}
