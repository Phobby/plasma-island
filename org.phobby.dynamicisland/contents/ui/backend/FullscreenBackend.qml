/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Whether the window in use fills the screen (a film, a game, a talk): the
    suggestions keep quiet then, and the notch steps aside. Told by the task
    manager's model on a change; nothing is polled, and no window's title or
    application is looked at.

    And, where `area` is given (the notch's place, global coordinates),
    whether a window reaches into it, as a panel's "Dodge windows" asks: any
    window of this screen, desktop and activity that is not minimised (a
    maximised one, a window moved up to the edge). Only where windows are
    and whether they are minimised is looked at.
*/
import QtQuick
import org.kde.taskmanager as TaskManager

Item {
    id: watch
    property bool active: false
    // Only a window on this screen counts (global coordinates); an empty one: any screen.
    property rect screen: Qt.rect(0, 0, 0, 0)
    // Where the notch is (global coordinates); empty: not looked at.
    property rect area: Qt.rect(0, 0, 0, 0)
    property bool covered: false
    function look(): void {
        active = tasks.data(tasks.activeTask, TaskManager.AbstractTasksModel.IsFullScreen) === true;
        covered = area.width > 0 && reaches();
    }
    function reaches(): bool {
        for (let i = 0; i < tasks.count; ++i) {
            const index = tasks.index(i, 0);
            if (tasks.data(index, TaskManager.AbstractTasksModel.IsMinimized) === true) continue;
            const g = tasks.data(index, TaskManager.AbstractTasksModel.Geometry);
            if (!g || !(g.width > 0)) continue;
            if (g.x < area.x + area.width && g.x + g.width > area.x && g.y < area.y + area.height && g.y + g.height > area.y) return true;
        }
        return false;
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
