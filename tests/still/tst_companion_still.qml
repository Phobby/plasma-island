/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The companion with the desktop's animations switched off (System Settings →
    Animation speed: instant): it stands still by itself, without its own
    "Reduce motion" setting. Plasma's units say so (longDuration 1 instead of
    200), read from the desktop's configuration: tools/run-tests runs this
    file with one that has them off; by hand it is skipped.
*/
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../org.phobby.dynamicisland/contents/ui"
import "../../org.phobby.dynamicisland/contents/ui/companion"

Item {
    id: root
    width: 760
    height: 200

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    PlasmaBackend { id: plasma }
    Activity { id: media; activityId: "media"; category: "media"; title: "Song"; Component.onCompleted: activities.register(this) }
    Island {
        id: island
        anchors.fill: parent
        theme: islandTheme
        backend: plasma
        manager: activities
        showMediaModule: false
        showSystemModule: false
        showNotificationModule: false
        Companion { id: companion; island: island; theme: islandTheme }
    }

    TestCase {
        name: "CompanionStill"
        when: windowShown

        function test_the_desktops_own_setting() {
            if (Kirigami.Units.longDuration > 1) skip("the desktop's animations are on: tools/run-tests runs this with them off");
            const cat = companion.character, mind = companion.mind;
            compare([companion.reduceMotion, companion.calm, cat.still, mind.still], [false, true, true, true]);
            activities.warm = true;
            media.active = true;
            tryCompare(mind, "accessory", "headphones");
            compare([mind.body, cat.loop, cat.moving, cat.phones, cat.poseAt], ["listen", "", false, 1, 1], "headphones on, no nodding");
            mind.clicked();
            compare([mind.body, cat.poseAt, cat.act], ["curious", 1, ""], "a pose changes at once, nothing hops");
            // (the note of the music beginning goes out; after that nothing is due: no fidgets)
            tryCompare(mind, "nextDue", -1, 5000);
            compare([mind.body, cat.moving], ["listen", false]);
            companion.sideSetting = 2;
            compare([companion.side, companion.cross], ["right", 0]);
        }
    }
}
