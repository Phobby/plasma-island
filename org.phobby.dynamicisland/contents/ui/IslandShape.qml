/*
    SPDX-License-Identifier: GPL-2.0-or-later

    IslandShape: the island's surface, in the material the theme describes
    (Oxygen-inspired metallic glass, a flat Breeze-like surface, clear glass):
      drop shadow → body (a gradient for metal; translucent over KWin blur)
      → frosting → inner shadow → top gloss → border, brighter at the top.
    What a material does not have is simply transparent or zero wide.
    A style with a gradient fill (Theme.gradientFill) has that as its body, at
    any angle or radial, under the same frosting, gloss and border.
    Children are placed in a clipped, padded content item.

    As the notch (`notch`): the upper edge straight and one with the screen's,
    only the lower corners rounded, and where it meets the edge (if asked) two
    small inward curves (`ear` px wide and `earDepth` deep, beside its own width). The body is
    the one shape of that outline (NotchOutline), opaque, or see-through in
    the island's own look with its frosting and, for glass and metal, its
    top gloss in the same outline; an optional inset edge, no inner shadow, nothing else
    is drawn.

    Optional ambient glow (AmbientGlow.qml): a coloured light around the edge
    (RectangularShadow, drawn by the GPU), a faint tint of the body and a
    small scale of the *drawn* surface only: the content and the input area
    keep their size. All of it is off (not even created) at glowShown 0.
*/
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: shape

    required property Theme theme
    property real radius: height / 2
    default property alias content: contentItem.data
    // (what is shown in it, without the body: a picture of it is taken there, see Island.frozen)
    readonly property Item contentArea: contentItem
    property real contentPadding: 0

    property bool notch: false
    property real ear: 0
    property real earDepth: ear

    property real glowShown: 0          // 0..1, fades the whole glow in and out
    property real glowStrength: 0       // 0..1, follows the music
    property color glowColor: "white"
    property real glowTint: 0           // how much of the colour tints the body
    property real bodyScale: 1

    // Everything drawn; scaled from the top edge (the island hangs from the top
    // of the screen), so a pop grows sideways and down and never past the top.
    Item {
        id: skin
        anchors.fill: parent
        transformOrigin: Item.Top
        scale: shape.bodyScale

    // The glow: below the body, shifted down so that it spills out under the
    // island and stays inside the window's margins (6 px above, 26 at the sides).
    // The notch's comes from its lower part only: its lower edge glows, not where it meets the screen's.
    Loader {
        width: parent.width
        y: shape.notch ? parent.height * 0.45 : 0
        height: shape.notch ? parent.height * 0.55 : parent.height
        active: shape.glowShown > 0.001
        sourceComponent: RectangularShadow {
            radius: shape.radius
            color: shape.glowColor
            blur: 7 + 6 * shape.glowStrength
            spread: 1 + 2 * shape.glowStrength
            offset.y: 2 + blur + spread - 6
            opacity: shape.glowShown * (0.35 + 0.65 * shape.glowStrength)
        }
    }

    Kirigami.ShadowedRectangle {
        anchors.fill: parent
        radius: shape.radius
        color: "transparent"
        visible: shape.theme.shadowSize > 0
        shadow.size: shape.theme.shadowSize
        shadow.yOffset: 4
        shadow.color: shape.theme.dropShadow
    }

    // Body of a gradient style: a shape of its own, because a Rectangle's gradient
    // only runs straight down or across. The theme's gradient is the base layer;
    // the cover's colour (the tint below) lies over it.
    Loader {
        anchors.fill: parent
        active: shape.theme.gradientFill && !shape.notch
        sourceComponent: Shape {
            id: fill
            readonly property real r: Math.max(0.01, Math.min(shape.radius, width / 2, height / 2))
            // CSS's angles: 0° runs upwards, 90° to the right; the line spans the whole surface.
            readonly property real angle: shape.theme.gradientAngle * Math.PI / 180
            readonly property real span: Math.abs(width * Math.sin(angle)) + Math.abs(height * Math.cos(angle))
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillGradient: shape.theme.gradientKind === "radial" ? radial : linear
                startX: fill.r; startY: 0
                PathLine { x: fill.width - fill.r; y: 0 }
                PathArc { x: fill.width; y: fill.r; radiusX: fill.r; radiusY: fill.r }
                PathLine { x: fill.width; y: fill.height - fill.r }
                PathArc { x: fill.width - fill.r; y: fill.height; radiusX: fill.r; radiusY: fill.r }
                PathLine { x: fill.r; y: fill.height }
                PathArc { x: 0; y: fill.height - fill.r; radiusX: fill.r; radiusY: fill.r }
                PathLine { x: 0; y: fill.r }
                PathArc { x: fill.r; y: 0; radiusX: fill.r; radiusY: fill.r }
            }
            LinearGradient {
                id: linear
                x1: fill.width / 2 - Math.sin(fill.angle) * fill.span / 2
                y1: fill.height / 2 + Math.cos(fill.angle) * fill.span / 2
                x2: fill.width / 2 + Math.sin(fill.angle) * fill.span / 2
                y2: fill.height / 2 - Math.cos(fill.angle) * fill.span / 2
                GradientStop { position: 0; color: shape.theme.gradientBody[0] ?? "transparent" }
                GradientStop { position: 0.5; color: shape.theme.gradientBody[1] ?? "transparent" }
                GradientStop { position: 1; color: shape.theme.gradientBody[2] ?? "transparent" }
            }
            // From the middle outwards, to the corners.
            RadialGradient {
                id: radial
                centerX: fill.width / 2
                centerY: fill.height / 2
                focalX: centerX
                focalY: centerY
                centerRadius: Math.sqrt(fill.width * fill.width + fill.height * fill.height) / 2
                GradientStop { position: 0; color: shape.theme.gradientBody[0] ?? "transparent" }
                GradientStop { position: 0.5; color: shape.theme.gradientBody[1] ?? "transparent" }
                GradientStop { position: 1; color: shape.theme.gradientBody[2] ?? "transparent" }
            }
        }
    }

    // The notch's body
    Loader {
        anchors.fill: parent
        active: shape.notch
        sourceComponent: NotchOutline {
            radius: shape.radius
            ear: shape.ear
            earDepth: shape.earDepth
            fillColor: shape.theme.notchBody.length === 3 ? "transparent" : shape.theme.bodyMid
            gradientColors: shape.theme.notchBody
            gradientKind: shape.theme.notchBodyKind
            gradientAngle: shape.theme.notchBodyAngle
        }
    }

    // Body (for a gradient style only its border: the shape above is the fill)
    Rectangle {
        anchors.fill: parent
        visible: !shape.notch
        radius: shape.radius
        color: "transparent"
        border.width: shape.theme.borderWidth
        border.color: shape.theme.rimBottom
        gradient: shape.theme.gradientFill ? null : bodyGradient
        Gradient {
            id: bodyGradient
            GradientStop { position: 0.0; color: shape.theme.bodyTop }
            GradientStop { position: 0.45; color: shape.theme.bodyMid }
            GradientStop { position: 1.0; color: shape.theme.bodyBottom }
        }
    }

    // Frosting over the blurred background (the blur level)
    Loader {
        anchors.fill: parent
        active: shape.notch && shape.theme.frost.a > 0
        sourceComponent: NotchOutline { radius: shape.radius; ear: shape.ear; earDepth: shape.earDepth; fillColor: shape.theme.frost }
    }
    Rectangle {
        anchors.fill: parent
        visible: !shape.notch && shape.theme.frost.a > 0
        radius: shape.radius
        color: shape.theme.frost
    }

    // The cover's colour over the metal, faintly
    Rectangle {
        anchors.fill: parent
        visible: !shape.notch && shape.glowShown > 0.001 && shape.glowTint > 0
        radius: shape.radius
        color: shape.glowColor
        opacity: shape.glowShown * shape.glowTint
    }
    Loader {
        anchors.fill: parent
        active: shape.notch && shape.glowShown > 0.001 && shape.glowTint > 0
        sourceComponent: NotchOutline {
            radius: shape.radius
            ear: shape.ear
            earDepth: shape.earDepth
            fillColor: shape.glowColor
            opacity: shape.glowShown * shape.glowTint
        }
    }

    // Inner shadow (inset depth)
    Rectangle {
        anchors.fill: parent
        anchors.margins: shape.theme.borderWidth
        visible: shape.theme.innerShadow.a > 0
        radius: Math.max(0, shape.radius - shape.theme.borderWidth)
        color: "transparent"
        border.width: 1
        border.color: shape.theme.innerShadow
    }

    // Top gloss (the notch's: in its outline, from the screen's edge down)
    Loader {
        width: parent.width
        height: Math.min(parent.height * 0.5, 60)
        active: shape.notch && shape.theme.highlight.a > 0
        sourceComponent: NotchOutline {
            ear: shape.ear
            earDepth: shape.earDepth
            fillColor: "transparent"
            readonly property color clear: Qt.rgba(shape.theme.highlight.r, shape.theme.highlight.g, shape.theme.highlight.b, 0)
            gradientColors: [shape.theme.highlight, Qt.rgba(clear.r, clear.g, clear.b, shape.theme.highlight.a * 0.35), clear]
            gradientAngle: 180
        }
    }
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: shape.theme.borderWidth
        }
        visible: !shape.notch && shape.theme.highlight.a > 0
        height: Math.min(parent.height * 0.5, 60)
        radius: Math.max(0, shape.radius - shape.theme.borderWidth)
        gradient: Gradient {
            GradientStop { position: 0.0; color: shape.theme.highlight }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Loader {
        anchors.fill: parent
        active: shape.notch && shape.theme.notchEdgeWidth > 0
        sourceComponent: NotchOutline {
            radius: shape.radius
            ear: shape.ear
            earDepth: shape.earDepth
            fillColor: "transparent"
            edgeWidth: shape.theme.notchEdgeWidth
            edgeColor: shape.theme.notchEdgeColor
        }
    }

    // The border's top colour (metal: a silver rim): bright over the top arc,
    // fading in two steps down the sides.
    Repeater {
        model: shape.theme.borderWidth === 0 || Qt.colorEqual(shape.theme.rimTop, shape.theme.rimBottom) ? [] : [
            { h: 0.5, o: 1.0 },
            { h: 0.8, o: 0.45 }
        ]
        delegate: Item {
            required property var modelData
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: Math.max(1, Math.max(shape.theme.borderWidth, Math.min(shape.radius, shape.height / 2)) * modelData.h * 2)
            clip: true
            opacity: modelData.o
            Rectangle {
                width: shape.width
                height: shape.height
                radius: shape.radius
                color: "transparent"
                border.width: shape.theme.borderWidth
                border.color: shape.theme.rimTop
            }
        }
    }
    }   // skin

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: shape.contentPadding
        clip: true
    }
}
