/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Plays the timer/alarm sound. Loaded through a Loader so a missing
    QtMultimedia only disables the sound.
*/
import QtQuick
import QtMultimedia

Item {
    id: sound

    function play(source: string): void {
        if (!source) return;
        player.stop();
        player.source = source.indexOf("://") >= 0 ? source : "file://" + source;
        player.play();
    }
    function stop(): void { player.stop(); }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput {}
    }
}
