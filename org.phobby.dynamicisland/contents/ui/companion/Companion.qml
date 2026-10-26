/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The companion on the island: a cat beside the pill. This places it, hands
    it the pointer, and puts together what decides (CompanionController), what
    draws (CatCharacter) and its bubble (CompanionBubble). It is a child of the
    Island (main.qml) and only reads from it: where the pill is, what stands
    beside it. Nothing here opens, closes or changes the island.

    Where it sits
      Beside the pill, outside it, on the pill's level and a little lower:
      there is no room above (the island hangs at the top of the screen), so
      its bubble goes beside its head, on the far side. It follows the pill's
      edge as the island changes shape, and so stands beside the open island
      at its top corner without ever covering it.
      Left by itself: the split island's bubble and the privacy dots are on
      the right. On the right (a setting, or no room on the left) it keeps
      clear of both. A change of sides is a walk across, not a jump.
      A dot: hidden, or asleep beside the dot (a setting).
      Beside the notch: on the panel, a little away from the notch's side
      (beyond its curves at the screen's edge, if it has them), its size as
      set; as high as the panel or less it stands on the panel's lower edge
      (the notch's), larger it hangs from the screen's edge.

    Where it takes the pointer
      On its body only (`maskShapes`, see main.qml and native/windowmask.h):
      not the air around it, not its tail, not its bubble; nothing while it
      is hidden. The pointer on the cat is not the pointer on the island:
      it neither opens nor holds it.
*/
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import ".."
import "Companion.js" as Mind
import "CatPoses.js" as Poses

Item {
    id: companion

    required property Item island
    required property Theme theme

    // ---- settings --------------------------------------------------------------------
    property bool enabled: true
    property int sideSetting: 0             // 0 by itself, 1 left, 2 right
    property int sizePercent: 130           // of the pill's height
    property string fur: "grey"
    property color furColor: "#c9a27c"
    property bool music: true
    property bool thoughts: true
    property bool events: true
    property bool petting: true
    property bool clicks: true
    property bool noAnger: false
    property int sulkSeconds: 10
    property int sleepSeconds: 20
    property int dotBehaviour: 0            // 0 hidden, 1 asleep beside the dot
    property bool reduceMotion: false
    // The island drawn up to the edge over a window that fills the screen (main.qml): the cat goes up
    // with it, its feet no lower than the island's lower edge, and keeps still (nothing of it is drawn
    // anew) until the island comes down again, the same way and as fast (tuckMove ms).
    property bool tucked: false
    property int tuckMove: 260
    readonly property real tuck: tucked ? Math.max(0, restY + tall - island.restBottom) : 0
    // From the island's middle to the screen's edges (in the island's units).
    property real spaceLeft: 100000
    property real spaceRight: 100000

    // The AI tab's backend (AiBackend), or null: whether an answer is on its way.
    property var ai: null
    readonly property alias mind: controller
    readonly property alias feed: feed
    readonly property alias character: figure
    signal hideRequested()
    signal settingsRequested()

    // ---- size ------------------------------------------------------------------------
    readonly property real tall: Math.round(theme.pillHeight * Math.max(100, Math.min(180, sizePercent)) / 100)
    readonly property real wide: Math.round(tall * Poses.W / Poses.H)
    readonly property real bubbleSize: Math.max(15, Math.round(tall * 0.4))
    readonly property real bubbleRoom: Math.ceil(bubbleSize * 1.25 * 0.8)
    // Room the window keeps on each side of the island, for as long as there is a cat.
    readonly property real reserve: enabled ? wide + bubbleRoom + 8 : 0

    // Motion is reduced: the setting, or the desktop's own "no animations".
    readonly property bool calm: reduceMotion || Kirigami.Units.longDuration <= 1
    // Beside a dot it is hidden, or asleep.
    readonly property bool shown: enabled && !(island.dot && dotBehaviour === 0)
    property real presence: shown ? 1 : 0
    Behavior on presence { enabled: !companion.calm; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // ---- which side, and where on it -------------------------------------------------------
    readonly property string wanted: Mind.sideFor(sideSetting, spaceLeft - theme.expandedWidth / 2, spaceRight - theme.expandedWidth / 2, wide + bubbleRoom + 6)
    property string side: "left"
    // How far it still has to go when it changes sides, and how far that was.
    property real cross: 0
    property real crossFrom: 0
    readonly property bool mirrored: (side === "right") !== (crossFrom !== 0 && Math.abs(cross) > Math.abs(crossFrom) / 2)
    onWantedChanged: {
        if (wanted === side) return;
        const here = restX(side) + cross, walk = !calm && shown;
        side = wanted;
        crossFrom = walk ? here - restX(side) : 0;
        cross = crossFrom;
        if (walk) crossAnim.restart(); else { crossAnim.stop(); crossFrom = 0; }
    }
    Component.onCompleted: side = wanted
    SequentialAnimation {
        id: crossAnim
        NumberAnimation { target: companion; property: "cross"; to: 0; duration: 620; easing.type: Easing.InOutCubic }
        ScriptAction { script: companion.crossFrom = 0 }
    }
    // What stands right of the pill: followed, but not in a jump when a dot appears.
    property real pushed: island.besideRight
    Behavior on pushed { enabled: !companion.calm; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    // The pill's edges (the dot's own, a little around it).
    readonly property rect pill: island.mode === "dot" ? island.hitRect : island.surfaceRect
    // The notch's curves where it meets the screen's edge reach beyond its sides (NotchOutline):
    // the cat leans against the notch beyond them.
    // (and keeps a little room from it, as from the panel's widgets)
    readonly property real ear: theme.notch ? Math.min(theme.notchEar, island.surfaceRect.height / 4) + notchGap : 0
    readonly property real notchGap: 10
    function restX(where: string): real {
        return where === "left" ? pill.x - ear - wide + 1 : pill.x + pill.width + ear + pushed - 1;
    }
    // (beside the notch: standing on the panel's lower edge, which is the notch's, or from the screen's edge down)
    readonly property real restY: theme.notch ? Math.max(0, theme.pillHeight - tall)
        : Math.max(1, Math.min(island.height - tall - 1, theme.windowTopPad + theme.pillHeight / 2 + (tall - theme.pillHeight) * 0.25 - tall / 2))

    // ---- where it takes the pointer (in the island's coordinates) -----------------------------
    readonly property var maskShapes: shown && presence > 0.99
        ? figure.touch.map(r => Qt.rect(spot.x + r.x, spot.y + r.y, r.width, r.height)) : []

    CompanionController {
        id: controller
        active: companion.shown
        asleepOnly: companion.island.dot
        music: companion.music
        thoughts: companion.thoughts
        events: companion.events
        petting: companion.petting
        clicks: companion.clicks
        noAnger: companion.noAnger
        still: companion.calm
        sleepAfter: Math.max(1, companion.sleepSeconds) * 1000
        sulkFor: Math.max(1, companion.sulkSeconds) * 1000
        onGesture: name => figure.gesture(name)
    }

    // What goes on, read from the island and its activities (nothing is written back).
    CompanionFeed {
        id: feed
        mind: controller
        manager: companion.island.manager
        island: companion.island
        ai: companion.ai
    }

    Item {
        id: spot
        objectName: "companionSpot"
        x: companion.restX(companion.side) + companion.cross
        // (a walk across is a small arc)
        y: companion.restY - (companion.crossFrom !== 0 ? 5 * Math.sin(Math.PI * Math.abs(companion.cross / companion.crossFrom)) : 0) - lift
        property real lift: companion.tuck
        Behavior on lift { NumberAnimation { duration: companion.tuckMove; easing.type: Easing.OutCubic } }
        width: companion.wide
        height: companion.tall
        visible: companion.presence > 0.01
        opacity: companion.presence
        scale: 0.6 + 0.4 * companion.presence
        transformOrigin: Item.Bottom

        CatCharacter {
            id: figure
            objectName: "companionCat"
            anchors.fill: parent
            body: controller.body
            accessory: controller.accessory
            tilt: controller.tilt
            look: over.hovered ? Math.max(-1, Math.min(1, (companion.pointerX - spot.width / 2) / (spot.width / 2))) * (mirrored ? -1 : 1) : 0
            mirrored: companion.mirrored
            still: companion.calm
            running: companion.shown && companion.presence > 0.01 && !companion.tucked
            beats: companion.island.musicBeats
            fur: companion.fur
            furColor: companion.furColor
            accent: companion.theme.accent
        }

        // The body: what the pointer can touch.
        Item {
            id: touch
            objectName: "companionTouch"
            anchors.fill: parent
            containmentMask: QtObject {
                function contains(point: point): bool {
                    const shapes = figure.touch;
                    for (let i = 0; i < shapes.length; ++i) {
                        const r = shapes[i], dx = (point.x - r.x - r.width / 2) / (r.width / 2), dy = (point.y - r.y - r.height / 2) / (r.height / 2);
                        if (dx * dx + dy * dy <= 1) return true;
                    }
                    return false;
                }
            }
            HoverHandler {
                id: over
                onHoveredChanged: controller.hovered(hovered)
                onPointChanged: {
                    if (!hovered) return;
                    companion.pointerX = point.position.x;
                    controller.pointerAt(point.position.x, spot.width);
                }
            }
            TapHandler { onTapped: controller.clicked() }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: companion.openMenu()
            }
        }
    }
    property real pointerX: 0
    readonly property bool hovered: over.hovered

    Connections {
        target: companion.island
        function onMusicBeat(strength) { figure.beat(strength); }
    }

    CompanionBubble {
        id: bubble
        objectName: "companionBubble"
        kind: companion.presence > 0.99 ? controller.bubble : ""
        still: companion.calm
        running: companion.shown && !companion.tucked
        side: companion.mirrored ? 1 : -1
        size: companion.bubbleSize
        fill: companion.theme.surface
        rim: companion.theme.mix(companion.theme.surface, companion.theme.text, 0.3)
        ink: companion.theme.text
        hot: companion.theme.danger
        x: companion.mirrored ? spot.x + figure.bubbleAt.x + 1 : spot.x + figure.bubbleAt.x - width - 1
        y: Math.max(0, spot.y + figure.bubbleAt.y - height * 0.75)
    }

    // ---- its own menu (right click on the cat, nowhere else) -------------------------------------
    readonly property bool menuOpen: menuLoader.item !== null && menuLoader.item.status === PlasmaExtras.Menu.Open
    // (a function of its own, so that a test can look at the click without a menu opening)
    property var openMenu: () => {
        menuLoader.active = true;
        menuLoader.item.openRelative();
    }
    Loader {
        id: menuLoader
        active: false
        sourceComponent: PlasmaExtras.Menu {
            visualParent: spot
            placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
            PlasmaExtras.MenuItem {
                text: Lang.i18n("Hide the cat")
                icon: "view-hidden-symbolic"
                onClicked: companion.hideRequested()
            }
            PlasmaExtras.MenuItem {
                text: Lang.i18n("Cat settings")
                icon: "configure-symbolic"
                onClicked: companion.settingsRequested()
            }
        }
    }

    // where it takes the pointer, outlined (with the island's own outline: main.qml's debugRegion)
    Repeater {
        model: companion.island.debugRegion ? companion.maskShapes : []
        delegate: Shape {
            id: outline
            required property var modelData
            z: 100
            ShapePath {
                fillColor: "transparent"
                strokeColor: "red"
                strokeWidth: 1
                PathAngleArc {
                    centerX: outline.modelData.x + outline.modelData.width / 2; centerY: outline.modelData.y + outline.modelData.height / 2
                    radiusX: outline.modelData.width / 2; radiusY: outline.modelData.height / 2
                    startAngle: 0; sweepAngle: 360
                }
            }
        }
    }
}
