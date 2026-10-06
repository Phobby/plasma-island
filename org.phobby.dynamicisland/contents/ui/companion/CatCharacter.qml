/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The cat, drawn. Drawing only: what it does is decided elsewhere
    (CompanionController), this shows it. Another character would be another
    file like this one, with the same properties:

      body, accessory, tilt, look     what to show (see Companion.js)
      gesture(name), beat(strength)   what happens once
      still, running, mirrored
      touch, bubbleAt                 where it can be touched, where a bubble goes

    Vector shapes made in code (CatPoses.js has the numbers): no picture
    files, sharp at any size. Each group of parts is drawn twice, first in the
    outline's colour and a little fatter, then in the fur's colour on top, so
    that parts which overlap share one outline.

    Nothing moves by itself. One timer steps what is in motion (a change of
    pose, a gesture, a motion that repeats) at no more than `fps` frames a
    second, far fewer for the slow ones (a sleeping cat breathes in steps of
    two or three a second), and stops when nothing is. `running` false: it
    does not run at all.
*/
import QtQuick
import QtQuick.Shapes
import "CatPoses.js" as Poses

Item {
    id: cat

    // ---- what to show ---------------------------------------------------------------
    property string body: "sit"
    property string accessory: ""           // "" | headphones
    property bool tilt: false
    // -1..1: where the pointer is, from its tail's side to the other
    property real look: 0
    // drawn the other way round (on the island's right)
    property bool mirrored: false
    // motion is reduced: poses change at once, nothing else moves
    property bool still: false
    property bool running: true
    // the music's beat is handed in (beat()): no nodding by itself
    property bool beats: false
    // The gallery's: one frame, by hand { body, from, t, act, g, blink, nod, loop, p, tilt, look, phones }.
    property var fixed: null

    // ---- its looks -------------------------------------------------------------------
    property string fur: "grey"             // grey | orange | black | white | tuxedo | custom
    property color furColor: "#a9afba"      // the custom colour
    property color accent: "#0a84ff"        // the headphones' cups

    implicitHeight: 47
    implicitWidth: implicitHeight * Poses.W / Poses.H
    readonly property real unit: height / Poses.H
    // Frames a second while something moves quickly.
    property int fps: 30

    // ---- where it can be touched, and where its bubble goes (in this item) ------------------
    readonly property string seen: fixed !== null ? fixed.body : body
    function across(x: real, w: real): real { return (mirrored ? Poses.W - x - w : x) * unit; }
    readonly property var touch: Poses.touch(seen).map(r => Qt.rect(across(r.x, r.w), r.y * unit, r.w * unit, r.h * unit))
    readonly property point bubbleAt: { const p = Poses.beside(seen); return Qt.point(across(p.x, 0), p.y * unit); }

    // ---- colours --------------------------------------------------------------------
    readonly property var coats: ({
        grey: { fur: "#a9afba", soft: "#e6e9ee", muzzle: true, belly: true, socks: false, stripes: "#8b919d" },
        orange: { fur: "#f2a65c", soft: "#fde9cf", muzzle: true, belly: true, socks: false, stripes: "#d4883e" },
        black: { fur: "#35363c", soft: "#35363c", muzzle: false, belly: false, socks: false, stripes: "" },
        white: { fur: "#f6f4ef", soft: "#ffffff", muzzle: false, belly: false, socks: false, stripes: "" },
        tuxedo: { fur: "#35363c", soft: "#f5f3ee", muzzle: true, belly: true, socks: true, stripes: "" }
    })
    readonly property var coat: coats[fur] !== undefined ? coats[fur]
        : { fur: String(furColor), soft: String(blend(furColor, "white", 0.62)), muzzle: true, belly: true, socks: false, stripes: "" }
    function blend(a: color, b: color, t: real): color { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1); }
    function brightness(c: color): real { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    readonly property color furFill: coat.fur
    readonly property color softFill: coat.soft
    readonly property bool darkFur: brightness(furFill) < 0.34
    // the outline: a darker shade of a light coat, a lighter one of a dark coat
    readonly property color line: darkFur ? blend(furFill, "#d4d8e2", 0.58) : blend(furFill, "#1b1c21", 0.5)
    // the face's strokes, and the eyes: dark on a light coat; on a dark one bright eyes with pupils
    readonly property color ink: darkFur ? "#f4f2ec" : "#2a2b31"
    readonly property color softInk: brightness(softFill) < 0.34 ? "#f4f2ec" : "#2a2b31"
    readonly property color faceInk: coat.muzzle ? softInk : ink
    readonly property color iris: !darkFur ? "#26272c" : fur === "tuxedo" ? "#a9dc73" : "#f6c94c"
    readonly property color pink: "#f3a0af"

    // ---- motion ---------------------------------------------------------------------
    // The character's own time (ms): it only moves while the ticker runs.
    property real clock: 0
    property real last: 0
    function easeOut(x: real): real { const y = 1 - Math.max(0, Math.min(1, x)); return 1 - y * y * y; }
    function easeBack(x: real): real { const y = Math.max(0, Math.min(1, x)) - 1; return 1 + 2.4 * y * y * y + 1.4 * y * y; }

    // a change of pose
    property var from: Poses.POSES.sit
    property var to: Poses.POSES.sit
    property string was: "sit"
    property real poseStart: -100000
    property real poseFor: 1
    property bool snappy: false
    readonly property real poseAt: still ? 1 : Math.min(1, (clock - poseStart) / poseFor)
    onBodyChanged: change()
    Component.onCompleted: { from = to = Poses.POSES[body] || Poses.POSES.sit; was = body; }
    function change(): void {
        const next = Poses.POSES[body] || Poses.POSES.sit;
        const here = Poses.between(from, to, snappy ? easeBack(poseAt) : easeOut(poseAt));
        const fresh = !(still || !running);
        poseFor = fresh ? Poses.into(body, was) : 1;
        poseStart = fresh ? clock : -100000;
        snappy = body === "angry" || body === "curious" || body === "perk";
        from = here;
        to = next;
        was = body;
    }
    // a gesture
    property string act: ""
    property real actStart: 0
    property real actFor: 1
    readonly property real actAt: act === "" ? 0 : Math.min(1, (clock - actStart) / actFor)
    property real blinkStart: -100000
    readonly property real blinkAt: clock - blinkStart < Poses.BLINK ? (clock - blinkStart) / Poses.BLINK : -1
    property real nodStart: -100000
    property real nodStrength: 1
    readonly property real nodAt: clock - nodStart < Poses.NOD ? (clock - nodStart) / Poses.NOD : -1
    function gesture(name: string): void {
        if (still || !running || fixed !== null) return;
        if (name === "blink") { blinkStart = clock; return; }
        const known = Poses.GESTURES[name];
        if (known === undefined) return;
        act = name;
        actFor = known[0];
        actStart = clock;
    }
    // A beat of the music (0..1): a nod.
    function beat(strength: real): void {
        if (still || !running || fixed !== null || body !== "listen") return;
        nodStrength = strength;
        nodStart = clock;
    }
    // the head to the side, the headphones on: eased
    property real tiltFrom: 0
    property real tiltStart: -100000
    readonly property real tiltAt: { const x = still ? 1 : easeOut((clock - tiltStart) / 280); return tiltFrom + ((tilt ? 1 : 0) - tiltFrom) * x; }
    onTiltChanged: { tiltFrom = tilt ? 0 : 1; tiltStart = still || !running ? -100000 : clock; }
    property real phonesStart: -100000
    readonly property bool wearing: accessory === "headphones"
    readonly property real phonesAt: { const x = still ? 1 : easeBack((clock - phonesStart) / 300); return wearing ? x : 1 - Math.min(1, x); }
    onWearingChanged: phonesStart = still || !running ? -100000 : clock
    // a motion that repeats
    readonly property string loop: still ? "" : Poses.loopOf(body, beats)
    property real loopStart: 0
    onLoopChanged: loopStart = clock
    readonly property real loopAt: loop === "" ? 0 : ((clock - loopStart) % Poses.LOOPS[loop][0]) / Poses.LOOPS[loop][0]

    // Something is on its way that needs frames, and how many a second.
    readonly property bool quick: poseAt < 1 || act !== "" || blinkAt >= 0 || nodAt >= 0 || clock - tiltStart < 280 || clock - phonesStart < 300
    readonly property bool moving: !still && (quick || loop !== "")
    Timer {
        id: ticker
        repeat: true
        running: cat.running && cat.fixed === null && cat.moving
        interval: Math.round(1000 / (cat.quick || cat.loop === "" ? cat.fps : Poses.LOOPS[cat.loop][1]))
        onRunningChanged: cat.last = Date.now()
        onTriggered: {
            const now = Date.now();
            // (never a leap, whatever kept the timer waiting)
            cat.clock += Math.max(1, Math.min(2 * interval + 60, now - cat.last));
            cat.last = now;
            if (cat.act !== "" && cat.actAt >= 1) cat.act = "";
        }
    }

    // ---- the cat as it is now -----------------------------------------------------------
    readonly property var m: fixed !== null
        ? Poses.compose(Poses.POSES[fixed.from || fixed.body], Poses.POSES[fixed.body], fixed.t === undefined ? 1 : fixed.t,
                        { tilt: fixed.tilt || 0, look: fixed.look || 0, act: fixed.act || "", g: fixed.g || 0,
                          blink: fixed.blink === undefined ? -1 : fixed.blink, nod: fixed.nod === undefined ? -1 : fixed.nod, strength: 1,
                          loop: fixed.loop || "", p: fixed.p || 0 })
        : Poses.compose(from, to, snappy ? easeBack(poseAt) : easeOut(poseAt),
                        { tilt: tiltAt, look: look, act: act, g: actAt, blink: blinkAt, nod: nodAt, strength: nodStrength, loop: loop, p: loopAt })
    readonly property real phones: fixed !== null ? (fixed.phones || 0) : phonesAt
    readonly property real lineWidth: 1.05

    component Blob: ShapePath {
        property real cx
        property real cy
        property real rx
        property real ry
        strokeWidth: 0
        strokeColor: "transparent"
        PathAngleArc { centerX: cx; centerY: cy; radiusX: Math.max(0.01, rx); radiusY: Math.max(0.01, ry); startAngle: 0; sweepAngle: 360 }
    }
    component Outline: Blob {
        fillColor: cat.line
        strokeColor: cat.line
        strokeWidth: 2 * cat.lineWidth
    }

    Item {
        id: rig
        width: Poses.W
        height: Poses.H
        // (drawn in the design's units, the right way round, and brought to size and side here)
        transform: [
            Translate { x: cat.m.jx; y: cat.m.dy },
            Scale { xScale: cat.mirrored ? -cat.unit : cat.unit; yScale: cat.unit },
            Translate { x: cat.mirrored ? cat.width : 0 }
        ]

        // ---- tail: one thick curve, outlined by a thicker one under it ----
        Shape {
            id: tail
            z: cat.m.tfront > 0.5 ? 4 : 0
            preferredRendererType: Shape.CurveRenderer
            component Curve: ShapePath {
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: cat.m.t0x; startY: cat.m.t0y
                PathCubic { x: cat.m.t3x; y: cat.m.t3y; control1X: cat.m.t1x; control1Y: cat.m.t1y; control2X: cat.m.t2x; control2Y: cat.m.t2y }
            }
            Curve { strokeColor: cat.line; strokeWidth: cat.m.tw + 2 * cat.lineWidth }
            Curve { strokeColor: cat.furFill; strokeWidth: cat.m.tw }
        }

        // ---- body ----
        Item {
            id: bodyGroup
            z: 1
            width: Poses.W
            height: Poses.H
            transform: [
                Scale { origin.x: cat.m.hx; origin.y: Poses.H - 1.5; xScale: cat.m.sx; yScale: cat.m.sy },
                Rotation { origin.x: cat.m.hx; origin.y: Poses.H - 1.5; angle: cat.m.rot }
            ]
            // fur on end
            Shape {
                preferredRendererType: Shape.CurveRenderer
                visible: cat.m.puff > 0.02
                ShapePath {
                    fillColor: cat.furFill
                    strokeColor: cat.line
                    strokeWidth: cat.lineWidth
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: cat.m.spikes }
                }
            }
            Shape {
                preferredRendererType: Shape.CurveRenderer
                Outline { cx: cat.m.tx; cy: cat.m.ty; rx: cat.m.trx; ry: cat.m.try_ }
                Outline { cx: cat.m.hx; cy: cat.m.hy; rx: cat.m.hrx; ry: cat.m.hry }
                Blob { fillColor: cat.furFill; cx: cat.m.tx; cy: cat.m.ty; rx: cat.m.trx; ry: cat.m.try_ }
                Blob { fillColor: cat.furFill; cx: cat.m.hx; cy: cat.m.hy; rx: cat.m.hrx; ry: cat.m.hry }
            }
            // from behind: the line of its back
            Shape {
                preferredRendererType: Shape.CurveRenderer
                opacity: (1 - cat.m.face) * 0.55
                visible: opacity > 0.01
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: cat.line
                    strokeWidth: 0.9
                    capStyle: ShapePath.RoundCap
                    startX: cat.m.tx - 0.6; startY: cat.m.ty - cat.m.try_ * 0.42
                    PathQuad { x: cat.m.tx - 1.4; y: cat.m.ty + cat.m.try_ * 0.62; controlX: cat.m.tx + 1.2; controlY: cat.m.ty + 2 }
                }
            }
            // a lighter chest
            Shape {
                preferredRendererType: Shape.CurveRenderer
                visible: cat.coat.belly
                opacity: cat.m.belly
                Blob { fillColor: cat.softFill; cx: cat.m.tx; cy: cat.m.ty + 2.4; rx: cat.m.trx * 0.56; ry: cat.m.try_ * 0.66 }
            }
        }

        // ---- head ----
        Item {
            id: headGroup
            z: 3
            x: cat.m.kx
            y: cat.m.ky
            transform: Rotation { origin.x: 0; origin.y: cat.m.kry * 0.72; angle: cat.m.krot }

            component Ear: ShapePath {
                property var e
                joinStyle: ShapePath.RoundJoin
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: cat.furFill
                startX: e.b1x; startY: e.b1y
                PathLine { x: e.ax; y: e.ay }
                PathQuad { x: e.cx; y: e.cy; controlX: e.tx; controlY: e.ty }
                PathLine { x: e.b2x; y: e.b2y }
                PathLine { x: e.b1x; y: e.b1y }
            }
            Shape {
                id: skull
                preferredRendererType: Shape.CurveRenderer
                Ear { e: cat.m.left; fillColor: cat.line; strokeColor: cat.line; strokeWidth: 2 * cat.lineWidth }
                Ear { e: cat.m.right; fillColor: cat.line; strokeColor: cat.line; strokeWidth: 2 * cat.lineWidth }
                Outline { cx: 0; cy: 0; rx: cat.m.krx; ry: cat.m.kry }
                Blob { fillColor: cat.furFill; cx: 0; cy: 0; rx: cat.m.krx; ry: cat.m.kry }
            }
            // the headphones' band: over the head, behind the ears
            Shape {
                preferredRendererType: Shape.CurveRenderer
                visible: cat.phones > 0.01
                opacity: Math.min(1, cat.phones * 1.4)
                y: -7 * (1 - Math.min(1, cat.phones))
                component Band: ShapePath {
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: -cat.m.krx - 0.6; startY: 1
                    PathCubic { x: cat.m.krx + 0.6; y: 1; control1X: -cat.m.krx - 1.2; control1Y: -cat.m.kry * 1.5; control2X: cat.m.krx + 1.2; control2Y: -cat.m.kry * 1.5 }
                }
                Band { strokeColor: "#1f2024"; strokeWidth: 3.3 }
                Band { strokeColor: "#50525c"; strokeWidth: 1.3 }
            }
            Shape {
                preferredRendererType: Shape.CurveRenderer
                Ear { e: cat.m.left }
                Ear { e: cat.m.right }
            }
            // a tabby's marks, on the forehead (and all there is to see of it from behind)
            Shape {
                preferredRendererType: Shape.CurveRenderer
                visible: cat.coat.stripes.length > 0
                component Mark: ShapePath {
                    property real at
                    property real tall
                    fillColor: "transparent"
                    strokeColor: cat.coat.stripes.length > 0 ? cat.coat.stripes : "transparent"
                    strokeWidth: 1.5
                    capStyle: ShapePath.RoundCap
                    startX: at * 1.25; startY: -cat.m.kry + 1.6
                    PathLine { x: at; y: -cat.m.kry + 1.6 + tall }
                }
                Mark { at: -3.6; tall: 3.2 }
                Mark { at: 0; tall: 4.3 }
                Mark { at: 3.6; tall: 3.2 }
            }

            // ---- face ----
            Item {
                id: face
                opacity: cat.m.face
                visible: opacity > 0.01
                readonly property real open: Math.min(1.3, cat.m.eye)
                readonly property bool shut: cat.m.eye < 0.14
                readonly property real gx: cat.m.gx * 1.1
                readonly property real gy: cat.m.gy * 0.9
                readonly property real gape: cat.m.mouth

                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    // inner ears
                    component Inner: ShapePath {
                        property var e
                        fillColor: cat.pink
                        strokeWidth: 0
                        strokeColor: "transparent"
                        startX: e.i1x; startY: e.i1y
                        PathLine { x: e.itx; y: e.ity }
                        PathLine { x: e.i2x; y: e.i2y }
                        PathLine { x: e.i1x; y: e.i1y }
                    }
                    Inner { e: cat.m.left }
                    Inner { e: cat.m.right }
                }
                // the lighter muzzle
                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    visible: cat.coat.muzzle
                    Blob { fillColor: cat.softFill; cx: 0; cy: 6.9; rx: 6.6; ry: 4.9 }
                }
                // cheeks, when it is pleased
                Rectangle { x: -13.2; y: 4.6; width: 5; height: 3; radius: 1.5; color: cat.pink; opacity: 0.75 * cat.m.blush }
                Rectangle { x: 8.2; y: 4.6; width: 5; height: 3; radius: 1.5; color: cat.pink; opacity: 0.75 * cat.m.blush }

                Shape {
                    id: eyes
                    preferredRendererType: Shape.CurveRenderer
                    component Eye: Blob {
                        property real side
                        fillColor: face.shut ? "transparent" : cat.iris
                        strokeColor: face.shut ? "transparent" : cat.darkFur ? "#1d1e22" : "transparent"
                        strokeWidth: cat.darkFur ? 0.5 : 0
                        cx: side * 7 + (cat.darkFur ? 0 : face.gx * 0.7); cy: 1.5 + (cat.darkFur ? 0 : face.gy * 0.5)
                        rx: 2.7; ry: 3.25 * face.open
                    }
                    // bright eyes have pupils
                    component Pupil: Blob {
                        property real side
                        fillColor: face.shut || !cat.darkFur ? "transparent" : "#1d1e22"
                        cx: side * 7 + face.gx; cy: 1.5 + face.gy
                        rx: 1.25 * cat.m.pupil; ry: Math.min(2.55, 2.55 * cat.m.pupil + 0.3) * Math.min(1, face.open)
                    }
                    component Glint: Blob {
                        property real side
                        fillColor: face.shut ? "transparent" : "white"
                        cx: side * 7 - 0.95 + face.gx * (cat.darkFur ? 1 : 0.7); cy: 1.5 - 1.25 * Math.min(1, face.open) + face.gy * (cat.darkFur ? 1 : 0.5)
                        rx: 0.85; ry: 0.85 * Math.min(1, face.open + 0.2)
                    }
                    // shut: an arc, bent down in sleep and up in delight
                    component Lid: ShapePath {
                        property real side
                        fillColor: "transparent"
                        strokeColor: face.shut ? cat.ink : "transparent"
                        strokeWidth: 0.95
                        capStyle: ShapePath.RoundCap
                        startX: side * 7 - 2.7; startY: 1.9 + 0.5 * cat.m.arc
                        PathQuad { x: side * 7 + 2.7; y: 1.9 + 0.5 * cat.m.arc; controlX: side * 7; controlY: 1.9 - 3.4 * cat.m.arc }
                    }
                    // a frown: a slanted stroke over each eye
                    component Brow: ShapePath {
                        property real side
                        fillColor: "transparent"
                        strokeColor: Qt.rgba(cat.ink.r, cat.ink.g, cat.ink.b, Math.min(1, cat.m.brow * 1.2))
                        strokeWidth: 1.25
                        capStyle: ShapePath.RoundCap
                        startX: side * 10.4; startY: -3.9 + 1.2 * (1 - cat.m.brow)
                        PathLine { x: side * 3.9; y: -1.1 - 0.9 * (1 - cat.m.brow) }
                    }
                    Eye { side: -1 } Eye { side: 1 }
                    Pupil { side: -1 } Pupil { side: 1 }
                    Glint { side: -1 } Glint { side: 1 }
                    Lid { side: -1 } Lid { side: 1 }
                    Brow { side: -1 } Brow { side: 1 }
                }
                Shape {
                    id: muzzle
                    preferredRendererType: Shape.CurveRenderer
                    // whiskers
                    component Whisker: ShapePath {
                        property real side
                        property real rise
                        fillColor: "transparent"
                        strokeColor: Qt.rgba(cat.ink.r, cat.ink.g, cat.ink.b, 0.5)
                        strokeWidth: 0.6
                        capStyle: ShapePath.RoundCap
                        startX: side * 9.4; startY: 6.6 + rise * 0.3
                        PathLine { x: side * (cat.m.krx + 2.4); y: 6.4 + rise }
                    }
                    Whisker { side: -1; rise: -1.7 } Whisker { side: -1; rise: 1.3 }
                    Whisker { side: 1; rise: -1.7 } Whisker { side: 1; rise: 1.3 }
                    // the open mouth (a yawn, a hiss), a tongue in it
                    Blob {
                        fillColor: face.gape > 0.06 ? "#6e2a36" : "transparent"
                        strokeColor: face.gape > 0.06 ? cat.faceInk : "transparent"
                        strokeWidth: 0.6
                        cx: 0; cy: 7.6 + 2.2 * face.gape; rx: 1.2 + 1.9 * Math.sqrt(face.gape); ry: 0.4 + 3 * face.gape
                    }
                    Blob {
                        fillColor: face.gape > 0.3 ? cat.pink : "transparent"
                        cx: 0; cy: 8 + 3.9 * face.gape; rx: 1.5 * Math.sqrt(face.gape); ry: 1.2 * face.gape
                    }
                    // fangs
                    ShapePath {
                        fillColor: cat.m.fangs > 0.3 && face.gape > 0.3 ? "white" : "transparent"
                        strokeWidth: 0; strokeColor: "transparent"
                        startX: -2.1; startY: 7.3
                        PathLine { x: -1.45; y: 7.3 + 2.3 * cat.m.fangs }
                        PathLine { x: -0.8; y: 7.3 }
                        PathLine { x: 0.8; y: 7.3 }
                        PathLine { x: 1.45; y: 7.3 + 2.3 * cat.m.fangs }
                        PathLine { x: 2.1; y: 7.3 }
                        PathLine { x: -2.1; y: 7.3 }
                    }
                    // the shut mouth: a small "w" under the nose
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: face.gape > 0.06 ? "transparent" : cat.faceInk
                        strokeWidth: 0.8
                        capStyle: ShapePath.RoundCap
                        startX: -2.9; startY: 7.5
                        PathQuad { x: 0; y: 7.1; controlX: -1.5; controlY: 9.4 }
                        PathQuad { x: 2.9; y: 7.5; controlX: 1.5; controlY: 9.4 }
                    }
                    // nose
                    ShapePath {
                        fillColor: cat.pink
                        strokeColor: cat.pink
                        strokeWidth: 0.7
                        joinStyle: ShapePath.RoundJoin
                        startX: -1.35; startY: 4.9
                        PathLine { x: 1.35; y: 4.9 }
                        PathLine { x: 0; y: 6.3 }
                        PathLine { x: -1.35; y: 4.9 }
                    }
                }
            }

            // ---- headphones: a cup on each side (the band is behind the ears) ----
            Item {
                visible: cat.phones > 0.01
                opacity: Math.min(1, cat.phones * 1.4)
                y: -7 * (1 - Math.min(1, cat.phones))
                component Cup: Rectangle {
                    property real side
                    x: side * (cat.m.krx + 0.6) - width / 2
                    y: -3.2
                    width: 6.4
                    height: 11.4
                    radius: 3
                    color: cat.accent
                    border.width: 0.9
                    border.color: "#1f2024"
                    Rectangle { x: parent.side < 0 ? 1.1 : parent.width - 2.3; y: 2; width: 1.2; height: parent.height - 4; radius: 0.6; color: Qt.rgba(1, 1, 1, 0.35) }
                }
                Cup { side: -1 }
                Cup { side: 1 }
            }
        }

        // ---- front paws ----
        Shape {
            z: 5
            preferredRendererType: Shape.CurveRenderer
            opacity: cat.m.paw
            visible: opacity > 0.01
            component Paw: Blob {
                fillColor: cat.coat.socks ? cat.softFill : cat.furFill
                strokeColor: cat.line
                strokeWidth: cat.lineWidth * 0.85
                rx: 4.3; ry: 2.9
            }
            Paw { cx: cat.m.plx; cy: cat.m.ply }
            Paw { cx: cat.m.prx; cy: cat.m.pry }
        }
    }
}
