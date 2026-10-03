/*
    SPDX-License-Identifier: GPL-2.0-or-later
    How loud the music is (native/core/audiolevels.h), in its own file so that
    without the native module (or with an older one) the glow only loses its
    reaction to the music.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Core.AudioLevels {}
