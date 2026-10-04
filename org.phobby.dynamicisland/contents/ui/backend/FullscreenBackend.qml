/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Whether the window in use fills the screen (a film, a game, a talk): the
    suggestions keep quiet then. Told by the task manager's model on a change;
    nothing is polled, and no window's title or application is looked at.
*/
import QtQuick
import org.kde.taskmanager as TaskManager

Item {
    id: watch
    property bool active: false
    function look(): void { active = tasks.data(tasks.activeTask, TaskManager.AbstractTasksModel.IsFullScreen) === true; }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        onActiveTaskChanged: watch.look()
        onDataChanged: watch.look()
        Component.onCompleted: watch.look()
    }
}
