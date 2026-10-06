/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The ambient glow of the island (off by default; the button on the Media
    page switches it): a light around the edge in the colour of the album
    cover (AlbumColor), breathing with the loudness of the music and popping
    on bass hits (LevelsBridge → native AudioLevels), and a faint tint of the
    surface in that colour. Island.qml draws it (IslandShape's glow*).

    Only while it is on and something plays is the music listened to; paused,
    the glow stays as a dim, still light; without media it goes out. Switched
    off, everything fades out in 350 ms and the listening process stops.
*/
import QtQuick

Item {
    id: glow

    property bool enabled: false
    property var backend: null              // PlasmaBackend
    // The output listened to: "" = the default one (a sink name for tests).
    property string audioTarget: ""

    readonly property bool hasMedia: backend !== null && backend.hasMedia
    readonly property bool playing: backend !== null && backend.isPlaying
    readonly property bool listening: enabled && playing

    // 0..1: how much of the glow is there at all (fades in and out).
    property real shown: enabled && hasMedia ? 1 : 0
    Behavior on shown { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }
    readonly property bool visibleAtAll: shown > 0.001

    // The cover's colour, crossfaded when the song changes.
    AlbumColor {
        id: album
        source: glow.enabled && glow.backend ? glow.backend.artUrl : ""
    }
    property color color: album.color
    Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutQuad } }

    // The music: loudness and bass, 0..1, about 30 times a second.
    Loader {
        id: levels
        active: glow.enabled
        source: "LevelsBridge.qml"
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: native module too old for the glow to follow the music; run install.sh again")
    }
    Binding { target: levels.item; property: "active"; value: glow.listening; when: levels.item !== null }
    Binding { target: levels.item; property: "target"; value: glow.audioTarget; when: levels.item !== null }
    // The music is really followed (the native module is there): its beats are handed on.
    readonly property bool following: listening && levels.item !== null
    signal beat(real strength)
    readonly property real level: levels.item && glow.listening ? levels.item.level : 0
    readonly property real bass: levels.item && glow.listening ? levels.item.bass : 0

    // Breathing: playing follows the loudness; paused stays still and dim.
    property real breath: listening ? 0.25 + 0.5 * level + 0.25 * bass : 0.2
    Behavior on breath { NumberAnimation { duration: 100 } }

    // A bass hit: up in 90 ms, back in 220 ms (ease-out), like a heartbeat.
    property real pop: 0
    SequentialAnimation {
        id: popAnim
        property real peak: 1
        NumberAnimation { target: glow; property: "pop"; to: popAnim.peak; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: glow; property: "pop"; to: 0; duration: 220; easing.type: Easing.OutCubic }
    }
    Connections {
        target: levels.item
        ignoreUnknownSignals: true
        function onBeat(strength) {
            if (!glow.listening) return;
            popAnim.peak = 0.5 + 0.5 * strength;
            popAnim.restart();
            glow.beat(strength);
        }
    }

    // What IslandShape draws.
    readonly property real strength: Math.min(1, breath + 0.6 * pop)
    readonly property real bodyScale: 1 + 0.04 * pop
}
