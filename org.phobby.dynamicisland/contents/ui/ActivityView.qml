/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Instantiates an activity presentation Component with its required
    `activity` and `theme` set at creation (a Loader would set them too late).
*/
import QtQuick

Item {
    id: view

    property Component component
    property var activity: null
    property Theme theme
    property Item item: null

    onComponentChanged: Qt.callLater(rebuild)
    onActivityChanged: if (item) item.activity = activity
    Component.onCompleted: rebuild()
    Component.onDestruction: if (item) item.destroy()

    function rebuild(): void {
        if (item) {
            item.destroy();
            item = null;
        }
        if (!component || !theme) return;
        item = component.createObject(view, {
            activity: view.activity,
            theme: view.theme,
            width: Qt.binding(() => view.width),
            height: Qt.binding(() => view.height)
        });
    }
}
