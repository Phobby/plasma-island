/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Every pose of the cat and every frame of its motions, side by side, to
    look at: the bodies at rest, each coat, what it wears and where it looks,
    each gesture in five frames, each motion that repeats in four, the
    changes from one pose to another in between. Nothing moves here: every
    cat is one frame set by hand (CatCharacter's `fixed`).

    Shown by the settings page ("Show all poses") and, in a window of its
    own, when the island is started with DYNAMICISLAND_CAT_GALLERY set.
*/
import QtQuick
import "CatPoses.js" as Poses

Flow {
    id: gallery

    // The height of one cat (px).
    property real cell: 94
    property string fur: "grey"
    property color furColor: "#a9afba"
    property color accent: "#0a84ff"
    property color labelColor: "white"
    // The bubbles' colours.
    property color bubbleFill: "#2b2c31"
    property color bubbleRim: "#55575f"
    property color bubbleInk: "white"
    // Which of it: "all", or one section ("bodies", "coats", "layers", "bubbles", "gestures", "motions", "changes").
    property string show: "all"

    spacing: 10

    readonly property var bodies: ["sit", "listen", "curious", "perk", "cheer", "tired", "annoyed", "angry", "sulk", "pet", "doze", "wake", "sleep", "purr"]
    readonly property var coats: ["grey", "orange", "black", "white", "tuxedo"]
    readonly property var frames: {
        const out = [], want = name => show === "all" || show === name;
        if (want("bodies")) for (const b of bodies) out.push({ label: b, fixed: { body: b } });
        if (want("coats")) for (const c of coats) for (const b of ["sit", "angry", "sulk", "sleep"]) out.push({ label: c + " · " + b, fur: c, fixed: { body: b } });
        if (want("layers")) {
            out.push({ label: "headphones", fixed: { body: "listen", phones: 1 } });
            out.push({ label: "headphones, half on", fixed: { body: "listen", phones: 0.5 } });
            out.push({ label: "nod", fixed: { body: "listen", phones: 1, nod: 0.4 } });
            out.push({ label: "thinking", fixed: { body: "sit", tilt: 1 } });
            out.push({ label: "music + thinking", fixed: { body: "listen", phones: 1, tilt: 1 } });
            out.push({ label: "angry, headphones", fixed: { body: "angry", phones: 1 } });
            out.push({ label: "sulk, headphones", fixed: { body: "sulk", phones: 1 } });
            out.push({ label: "look ←", fixed: { body: "curious", look: -1 } });
            out.push({ label: "look →", fixed: { body: "curious", look: 1 } });
            out.push({ label: "pet ←", fixed: { body: "pet", look: -1 } });
            out.push({ label: "blink", fixed: { body: "sit", blink: 0.5 } });
            out.push({ label: "mirrored", mirrored: true, fixed: { body: "sit" } });
            out.push({ label: "mirrored · sleep", mirrored: true, fixed: { body: "sleep" } });
        }
        if (want("bubbles")) {
            const with_ = { dots: "sit", question: "sit", exclaim: "perk", note: "listen", hiss: "angry", heart: "pet", zzz: "sleep" };
            for (const kind in with_) {
                const moves = kind === "dots" || kind === "heart" || kind === "zzz";
                for (const p of moves ? [0, 0.25, 0.5, 0.75] : [0])
                    out.push({ label: kind + (moves ? " " + p : ""), bubble: kind, phase: p,
                               fixed: { body: with_[kind], tilt: kind === "dots" || kind === "question" ? 1 : 0, phones: kind === "note" ? 1 : 0 } });
            }
            out.push({ label: "heart, still", bubble: "heart", phase: 0, calm: true, fixed: { body: "pet" } });
            out.push({ label: "zzz, still", bubble: "zzz", phase: 0, calm: true, fixed: { body: "sleep" } });
            out.push({ label: "mirrored", bubble: "question", phase: 0, mirrored: true, fixed: { body: "sit", tilt: 1 } });
        }
        if (want("gestures")) {
            const on = { yawn: "doze", stretch: "wake", shoo: "sulk", turn: "sulk", flinch: "annoyed", hop: "curious", perk: "perk" };
            for (const name in Poses.GESTURES)
                for (const g of [0.15, 0.35, 0.5, 0.7, 0.9]) out.push({ label: name + " " + Math.round(g * 100) + "%", fixed: { body: on[name] || "sit", act: name, g: g } });
        }
        if (want("motions")) {
            const of = { breath: "sleep", bob: "listen", swish: "sulk", lash: "annoyed", bristle: "angry", purr: "pet", snore: "purr", wag: "cheer" };
            for (const name in Poses.LOOPS)
                for (const p of [0, 0.25, 0.5, 0.75]) out.push({ label: name + " " + p, fixed: { body: of[name], loop: name, p: p, phones: name === "bob" ? 1 : 0 } });
        }
        if (want("changes")) {
            for (const pair of [["sit", "sleep"], ["sleep", "wake"], ["wake", "sit"], ["sit", "angry"], ["angry", "sulk"], ["sit", "pet"]])
                for (const t of [0.25, 0.5, 0.75]) out.push({ label: pair[0] + " → " + pair[1] + " " + t, fixed: { from: pair[0], body: pair[1], t: t } });
        }
        return out;
    }

    Repeater {
        model: gallery.frames
        delegate: Column {
            id: frame
            required property var modelData
            spacing: 2
            Item {
                // (room beside the head for the bubble, on the side it goes)
                readonly property real room: frame.modelData.bubble ? gallery.cell * 0.42 : 0
                width: figure.width + room
                height: gallery.cell
                CatCharacter {
                    id: figure
                    x: frame.modelData.mirrored === true ? 0 : parent.room
                    height: gallery.cell
                    width: implicitWidth * height / implicitHeight
                    fixed: frame.modelData.fixed
                    running: false
                    mirrored: frame.modelData.mirrored === true
                    fur: frame.modelData.fur || gallery.fur
                    furColor: gallery.furColor
                    accent: gallery.accent
                }
                CompanionBubble {
                    visible: frame.modelData.bubble !== undefined
                    kind: frame.modelData.bubble || ""
                    fixedPhase: frame.modelData.phase || 0
                    still: frame.modelData.calm === true
                    running: false
                    side: figure.mirrored ? 1 : -1
                    size: gallery.cell * 0.4
                    fill: gallery.bubbleFill
                    rim: gallery.bubbleRim
                    ink: gallery.bubbleInk
                    x: figure.mirrored ? figure.x + figure.bubbleAt.x + 1 : figure.x + figure.bubbleAt.x - width - 1
                    y: Math.max(0, figure.bubbleAt.y - height * 0.75)
                }
            }
            Text {
                textFormat: Text.PlainText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: frame.modelData.label
                color: gallery.labelColor
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }
}
