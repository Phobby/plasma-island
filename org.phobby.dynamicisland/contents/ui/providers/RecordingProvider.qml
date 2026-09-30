/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Screen recording / screen sharing (PipeWire screencast streams): blinking
    red dot + elapsed time. There is no generic way to stop another app's
    capture, so the action switches to the recording application instead.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    required property var tasks
    property var core: null
    property bool enabled: true

    readonly property var apps: core ? core.screenCastApps : []
    property int elapsed: 0

    function format(s: int): string {
        const m = Math.floor(s / 60), ss = s % 60;
        return m + ":" + (ss < 10 ? "0" : "") + ss;
    }

    Timer {
        interval: 1000
        repeat: true
        running: recording.active
        onTriggered: provider.elapsed = Math.round((Date.now() - recording.startedAt.getTime()) / 1000)
    }

    Activity {
        id: recording
        activityId: "screen-recording"
        category: "recording"
        active: provider.enabled && provider.apps.length > 0
        onActiveChanged: provider.elapsed = 0
        icon: "dot"
        pulse: true
        color: provider.theme.red
        title: i18n("Screen recording")
        subtitle: provider.apps.join(", ")
        trailingText: provider.format(provider.elapsed)
        actions: [
            { icon: "window-new-symbolic", text: i18n("Switch to application"), trigger: () => provider.tasks.activate(provider.apps[0]) }
        ]
        onClicked: provider.tasks.activate(provider.apps[0])
        Component.onCompleted: provider.manager.register(this)
    }
}
