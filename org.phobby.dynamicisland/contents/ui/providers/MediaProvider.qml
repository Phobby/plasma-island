/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Media (all MPRIS players) as a Live Activity. The expanded view is the
    existing Media page, so it is not listed on the Activities page.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property PlasmaBackend backend
    property bool enabled: true

    Activity {
        id: activity
        // Handed to the compact/minimal components.
        property PlasmaBackend backend: provider.backend
        activityId: "media"
        category: "media"
        listed: false
        active: provider.enabled && provider.backend.isPlaying
        icon: "view-media-track"
        title: provider.backend.track
        subtitle: provider.backend.artist
        compact: Component { MediaCompact {} }
        minimal: Component { MediaMinimal {} }
        Component.onCompleted: provider.manager.register(this)
    }
}
