/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Bring an application's window to the front by (fuzzy) app name. The tasks
    model is only created on first use.
*/
import QtQuick
import org.kde.taskmanager as TaskManager

Item {
    id: tasksBackend

    property var model: null

    Component {
        id: modelComponent
        TaskManager.TasksModel {
            groupMode: TaskManager.TasksModel.GroupDisabled
        }
    }

    function activate(appName: string): bool {
        if (!appName) return false;
        if (!model) model = modelComponent.createObject(tasksBackend);
        const needle = appName.toLowerCase();
        for (let i = 0; i < model.count; ++i) {
            const idx = model.makeModelIndex(i);
            const name = String(model.data(idx, TaskManager.AbstractTasksModel.AppName) || "").toLowerCase();
            const id = String(model.data(idx, TaskManager.AbstractTasksModel.AppId) || "").toLowerCase();
            if (name.indexOf(needle) >= 0 || id.indexOf(needle) >= 0 || (name && needle.indexOf(name) >= 0)) {
                model.requestActivate(idx);
                return true;
            }
        }
        return false;
    }
}
