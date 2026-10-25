/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The notch's outline, filled: the upper edge straight along the screen's,
    the lower corners rounded by `radius`, and where the sides meet the edge
    two inward curves `ear` px wide and `earDepth` px deep, outside the item's
    own width (as where a real notch meets the frame). One colour, or the theme's gradient (the
    same three stops IslandShape takes).
*/
import QtQuick
import QtQuick.Shapes

Shape {
    id: outline

    property real edgeWidth: 0
    property color edgeColor: "transparent"
    property real radius: 0
    property real ear: 0
    property real earDepth: ear
    property color fillColor: "black"
    property var gradientColors: []          // three colours, or none
    property string gradientKind: "linear"
    property real gradientAngle: 0

    readonly property real r: Math.max(0, Math.min(radius, height, width / 2))
    // (a small notch, the dot, gets small curves)
    readonly property real e: Math.max(0, Math.min(ear, height / 4))
    readonly property real ed: e > 0 ? Math.max(e, Math.min(earDepth, height * 0.4)) : 0
    readonly property real angle: gradientAngle * Math.PI / 180
    readonly property real span: Math.abs(width * Math.sin(angle)) + Math.abs(height * Math.cos(angle))
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        fillColor: outline.gradientColors.length === 3 ? "transparent" : outline.fillColor
        fillGradient: outline.gradientColors.length !== 3 ? null : outline.gradientKind === "radial" ? radial : linear
        PathSvg {
            path: {
                const w = outline.width, h = outline.height, r = outline.r, e = outline.e, ed = outline.ed;
                // (an arc of no size is left out: some renderers draw nothing for it)
                const arc = (radius, sweep, x, y) => radius > 0.01 ? " A " + radius + " " + radius + " 0 0 " + sweep + " " + x + " " + y : " L " + x + " " + y;
                // (the curves at the edge: a quarter of an ellipse, `e` across and `ed` down)
                const ear = (sweep, x, y) => e > 0.01 ? " A " + e + " " + ed + " 0 0 " + sweep + " " + x + " " + y : " L " + x + " " + y;
                return "M " + (-e) + " 0 L " + (w + e) + " 0"
                    + ear(0, w, ed)
                    + " L " + w + " " + (h - r)
                    + arc(r, 1, w - r, h)
                    + " L " + r + " " + h
                    + arc(r, 1, 0, h - r)
                    + " L 0 " + ed
                    + ear(0, -e, 0)
                    + " Z";
            }
        }
    }
    // Open, inset stroke: the screen edge stays joined, with no line across the top.
    ShapePath {
        strokeWidth: outline.edgeWidth > 0 ? outline.edgeWidth : -1
        strokeColor: outline.edgeWidth > 0 ? outline.edgeColor : "transparent"
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.RoundJoin
        fillColor: "transparent"
        PathSvg {
            path: {
                const d = Math.min(outline.edgeWidth / 2, outline.width / 4, outline.height / 4);
                const w = outline.width, h = outline.height, r = Math.max(0, outline.r - d), e = outline.e, ed = outline.ed;
                const arc = (radius, sweep, x, y) => radius > 0.01 ? " A " + radius + " " + radius + " 0 0 " + sweep + " " + x + " " + y : " L " + x + " " + y;
                const ear = (sweep, x, y) => e > 0.01 ? " A " + (e + d) + " " + (ed + d) + " 0 0 " + sweep + " " + x + " " + y : " L " + x + " " + y;
                return "M " + (-e) + " " + (-d)
                    + ear(1, d, ed)
                    + " L " + d + " " + (h - d - r)
                    + arc(r, 0, d + r, h - d)
                    + " L " + (w - d - r) + " " + (h - d)
                    + arc(r, 0, w - d, h - d - r)
                    + " L " + (w - d) + " " + ed
                    + ear(1, w + e, -d);
            }
        }
    }
    // CSS's angles, as in IslandShape: 0° runs upwards, 90° to the right.
    LinearGradient {
        id: linear
        x1: outline.width / 2 - Math.sin(outline.angle) * outline.span / 2
        y1: outline.height / 2 + Math.cos(outline.angle) * outline.span / 2
        x2: outline.width / 2 + Math.sin(outline.angle) * outline.span / 2
        y2: outline.height / 2 - Math.cos(outline.angle) * outline.span / 2
        GradientStop { position: 0; color: outline.gradientColors[0] ?? "transparent" }
        GradientStop { position: 0.5; color: outline.gradientColors[1] ?? "transparent" }
        GradientStop { position: 1; color: outline.gradientColors[2] ?? "transparent" }
    }
    RadialGradient {
        id: radial
        centerX: outline.width / 2
        centerY: outline.height / 2
        focalX: centerX
        focalY: centerY
        centerRadius: Math.sqrt(outline.width * outline.width + outline.height * outline.height) / 2
        GradientStop { position: 0; color: outline.gradientColors[0] ?? "transparent" }
        GradientStop { position: 0.5; color: outline.gradientColors[1] ?? "transparent" }
        GradientStop { position: 1; color: outline.gradientColors[2] ?? "transparent" }
    }
}
