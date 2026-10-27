/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Settings → Appearance: follow the system's colours, or a custom style made
    from a ready-made preset and fine tuning, kept as named profiles. A look
    can be exported as a theme file and themes can be added from files or from
    the store ("Add New…"): they join the ready-made looks as cards of their own.

    Every change shows on the island at once: while the page is open it writes
    its working values to the widget's configuration as a preview (the settings
    window has a QML engine of its own; the configuration is what both share).
    Apply stores them; leaving without applying returns the island to what is
    stored.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: page
    header: SettingsSearch { page: page; pageName: "configAppearance" }

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property int cfg_appearanceMode
    property int cfg_followSource
    property string cfg_customStyle
    property string cfg_styleProfiles
    property string cfg_activeProfile
    // Earlier settings: the first custom style starts from them (see Styles.parse).
    property int cfg_surfaceOpacity
    property bool cfg_blurEnabled
    property int cfg_themeMode
    // Where the island sits while following the system (a custom style brings its own).
    property int cfg_topMargin
    property bool cfg_avoidPanels
    // The layout: 0 = the notch (it sits at the top edge itself: the distance from it does not
    // apply), 1 = the oval layout. And the notch's own settings (NotchSettings.qml).
    property int cfg_islandLayout
    readonly property bool notch: cfg_islandLayout === 0
    property int cfg_notchColor
    property int cfg_notchScreen
    property int cfg_notchMaxWidth
    property bool cfg_notchOpenWidth
    property int cfg_notchDodgeSize
    property bool cfg_notchDodgeWindows
    property int cfg_notchDodgeWidth
    property bool cfg_notchHideCat
    property int cfg_notchHeightMode
    property int cfg_notchHeight
    property bool cfg_notchEars
    property bool cfg_notchBorderEnabled
    property int cfg_notchBorderWidth
    property string cfg_notchBorderColor
    property int cfg_notchBorderOpacity
    property int cfg_notchPanelSeen
    // Over a window that fills the screen, both layouts (FullscreenSettings.qml).
    property int cfg_fullscreenMode
    property int cfg_peekSize
    property int cfg_peekDelay
    property int cfg_peekWidth
    property bool cfg_peekEvents
    property bool cfg_peekMaximized
    property bool cfg_peekIdle
    property int cfg_peekIdleDelay
    // (for the notch's preview: the clock in it, the dot's size; and whether there is a cat to hide)
    property bool cfg_showClock
    property int cfg_dotSize
    property bool cfg_catEnabled
    property int cfg_horizontalOffset
    // Written by the widget: the largest size its screen has room for (0 = the whole range).
    property int cfg_scaleLimitSeen
    // And what else is set by hand in that look: opacity, blur, size, roundness, border, shadow (Styles.parseFollow).
    property string cfg_followStyle
    readonly property var tuning: Styles.parseFollow(cfg_followStyle)
    // What the fine tuning shows and changes: the custom style, or the system look's own settings.
    readonly property var look: custom ? style : Object.assign({}, tuning, {
        top: cfg_topMargin, offsetX: cfg_horizontalOffset, opacity: tuning.opacity < 0 ? Math.round(shown.alpha * 100) : tuning.opacity })
    function put(key: string, value: var): void {
        if (custom) { set(key, value); return; }
        if (key === "top") { cfg_topMargin = value; return; }
        if (key === "offsetX") { cfg_horizontalOffset = value; return; }
        if (tuning[key] === undefined || look[key] === value) return;
        const next = Object.assign({}, tuning);
        next[key] = value;
        cfg_followStyle = JSON.stringify(next);
    }

    readonly property bool custom: cfg_appearanceMode === 1
    readonly property bool gradient: style.fill === "gradient"
    // The style being edited.
    property var style: Styles.defaults("oxygen")
    readonly property var profiles: Styles.parseProfiles(cfg_styleProfiles)
    readonly property var activeProfile: profiles.find(p => p.name === cfg_activeProfile) ?? null
    readonly property bool profileChanged: activeProfile !== null && !Styles.same(activeProfile.style, style)

    function stored(): var {
        return Styles.parse(cfg_customStyle, { opacity: cfg_surfaceOpacity, blur: cfg_blurEnabled, top: cfg_topMargin, light: cfg_themeMode === 2 });
    }
    function use(next: var): void {
        style = Styles.normalize(next);
        cfg_customStyle = JSON.stringify(style);
    }
    function set(key: string, value: var): void {
        if (style[key] === value) return;
        const next = Object.assign({}, style);
        // A gradient nobody has touched yet starts from the solid colours: it follows them.
        const untouched = JSON.stringify(style.gradientStops) === JSON.stringify(Styles.stopsFor(style));
        next[key] = value;
        if (untouched && (key === "background" || key === "control")) next.gradientStops = Styles.stopsFor(next);
        use(next);
    }
    function setStop(index: int, hex: string): void {
        const stops = style.gradientStops.slice();
        stops[index] = hex;
        set("gradientStops", stops);
    }
    // Two colours or three: the third comes in between, as the mix it replaces.
    function setThirdStop(on: bool): void {
        const stops = style.gradientStops;
        if (on === (stops.length === 3)) return;
        set("gradientStops", on ? [stops[0], Styles.mixHex(stops[0], stops[1], 0.5), stops[1]] : [stops[0], stops[2]]);
    }
    // ---- theme files ----------------------------------------------------------------
    // The user's own themes are files (ThemeLibrary); reading and writing them needs the native helper.
    Loader { id: localTools; source: "LocalBridge.qml" }
    ThemeLibrary { id: library; local: localTools.status === Loader.Ready ? localTools.item : null }
    ThemeStore { id: store }
    property alias themeLibrary: library
    property alias themeStore: store
    property alias themeDialog: addDialog
    // The own theme whose settings the edited style is, if any.
    readonly property var activeTheme: library.themes.find(t => Styles.same(library.applied(t, style), style)) ?? null
    // A theme's settings become the edited style; where it says nothing about
    // the island's place and size, those stay.
    function applyTheme(theme: var): void { use(library.applied(theme, style)); }
    property string confirmRemove: ""       // the file of the own theme asked about

    // A preset is a look: where the island sits and how large it is stay.
    function choosePreset(preset: string): void {
        const next = Styles.defaults(preset);
        next.top = style.top; next.offsetX = style.offsetX; next.scale = style.scale;
        use(next);
    }
    function saveProfile(name: string): void {
        const trimmed = name.trim();
        if (trimmed.length === 0) return;
        const list = profiles.filter(p => p.name !== trimmed).concat([{ name: trimmed, style: style }]);
        cfg_styleProfiles = JSON.stringify(list);
        cfg_activeProfile = trimmed;
    }
    function loadProfile(name: string): void {
        const found = profiles.find(p => p.name === name);
        if (!found) return;
        cfg_activeProfile = name;
        use(found.style);
    }
    function deleteProfile(name: string): void {
        cfg_styleProfiles = JSON.stringify(profiles.filter(p => p.name !== name));
        if (cfg_activeProfile === name) cfg_activeProfile = "";
    }
    function hex(c: color): string { return String(Qt.rgba(c.r, c.g, c.b, 1)).slice(0, 7); }

    // The stored style, also after "Defaults" replaced it from outside.
    onCfg_customStyleChanged: if (cfg_customStyle !== JSON.stringify(style)) style = stored()

    // ---- live preview ------------------------------------------------------------
    // The widget's configuration (null outside a settings window).
    function widget(): var { try { return Plasmoid.configuration; } catch (e) { return null; } }
    // Plasma also creates the page once without showing it; only the one that is
    // in the settings window previews, and only that one ends the preview.
    readonly property bool placed: Window.window !== null
    property bool published: false
    function publish(): void {
        const c = widget();
        if (!placed || !c) return;
        c.previewMode = cfg_appearanceMode;
        c.previewSource = cfg_followSource;
        c.previewStyle = JSON.stringify(style);
        c.previewTop = cfg_topMargin;
        c.previewOffsetX = cfg_horizontalOffset;
        c.previewFollowStyle = cfg_followStyle;
        c.previewActive = true;
        published = true;
    }
    onPlacedChanged: publish()
    onStyleChanged: publish()
    onCfg_appearanceModeChanged: publish()
    onCfg_followSourceChanged: publish()
    onCfg_topMarginChanged: publish()
    onCfg_horizontalOffsetChanged: publish()
    onCfg_followStyleChanged: publish()
    Component.onCompleted: {
        style = stored();
        publish();
    }
    Component.onDestruction: { const c = widget(); if (published && c) c.previewActive = false; }
    // The applied colour scheme, as the island last read it.
    readonly property var systemScheme: { const c = widget(); return c ? Styles.schemeFromText(c.systemScheme) : null; }

    // What the island looks like with this page's settings (the automatic colours).
    Theme {
        id: shown
        follow: !page.custom
        systemSource: page.cfg_followSource
        systemScheme: page.systemScheme
        systemStyle: page.tuning
        style: page.style
        blurActive: true
    }

    // The notch with this page's settings (its preview, the layout's card).
    Theme {
        id: notchShown
        follow: !page.custom
        systemSource: page.cfg_followSource
        systemScheme: page.systemScheme
        systemStyle: page.tuning
        style: page.style
        blurActive: true
        notch: true
        notchBlack: page.cfg_notchColor === 0
        notchLook: page.cfg_notchColor === 2
        notchEars: page.cfg_notchEars
        notchBorderEnabled: page.cfg_notchBorderEnabled
        notchBorderWidth: page.cfg_notchBorderWidth
        notchBorderColor: page.cfg_notchBorderColor
        notchBorderOpacity: page.cfg_notchBorderOpacity
        // the panel the island found there (36 px where it has not looked yet), or as set
        notchPixels: page.cfg_notchHeightMode === 1 ? page.cfg_notchHeight : page.cfg_notchPanelSeen > 0 ? page.cfg_notchPanelSeen : 36
    }

    // A layout as a card: a small picture of it over a strip of panel, its name.
    component LayoutCard: QQC2.AbstractButton {
        id: layoutCard
        property bool current: false
        default property alias picture: frame.data
        implicitWidth: Kirigami.Units.gridUnit * 9
        implicitHeight: Kirigami.Units.gridUnit * 5.5
        checkable: true
        checked: current
        Accessible.name: text
        background: Rectangle {
            radius: Kirigami.Units.cornerRadius
            color: layoutCard.current ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18) : layoutCard.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.06) : "transparent"
            border.width: layoutCard.current ? 2 : 1
            border.color: layoutCard.current ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.15)
        }
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            Rectangle {
                id: frame
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Kirigami.Units.smallSpacing
                radius: Kirigami.Units.cornerRadius / 2
                color: "#2b3a4a"
                clip: true
                // a strip of panel at the top
                Rectangle { width: parent.width; height: 9; color: Qt.rgba(0.85, 0.86, 0.88, 1) }
            }
            QQC2.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: layoutCard.text
                font.weight: layoutCard.current ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
        }
    }

    // A look as a card: the island in that style, its name; an own theme can be deleted.
    component LookCard: QQC2.AbstractButton {
        id: card
        property var look
        property string title
        property bool current: false
        property bool removable: false
        property bool asking: false
        signal removeRequested()
        signal removeConfirmed()
        signal removeCancelled()
        width: Kirigami.Units.gridUnit * 7.5
        height: column.implicitHeight + Kirigami.Units.smallSpacing * 2
        Accessible.name: title
        background: Rectangle {
            radius: Kirigami.Units.cornerRadius
            color: card.current ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18) : card.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.06) : "transparent"
            border.width: card.current ? 2 : 1
            border.color: card.current ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.15)
        }
        contentItem: ColumnLayout {
            id: column
            spacing: Kirigami.Units.smallSpacing
            ThemePreview {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                Layout.margins: Kirigami.Units.smallSpacing
                style: card.look
                systemScheme: page.systemScheme
                // an own theme: delete it (asks once more)
                QQC2.ToolButton {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    visible: card.removable && !card.asking && (card.hovered || hovered)
                    icon.name: "edit-delete"
                    display: QQC2.AbstractButton.IconOnly
                    text: Lang.i18n("Delete")
                    onClicked: card.removeRequested()
                }
            }
            QQC2.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: !card.asking
                horizontalAlignment: Text.AlignHCenter
                text: card.title
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: card.asking
                spacing: 0
                QQC2.Label { textFormat: Text.PlainText; text: Lang.i18n("Delete?"); font: Kirigami.Theme.smallFont }
                QQC2.ToolButton {
                    icon.name: "edit-delete"
                    display: QQC2.AbstractButton.IconOnly
                    text: Lang.i18n("Delete")
                    onClicked: card.removeConfirmed()
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: text
                }
                QQC2.ToolButton {
                    icon.name: "dialog-cancel"
                    display: QQC2.AbstractButton.IconOnly
                    text: Lang.i18n("Cancel")
                    onClicked: card.removeCancelled()
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: text
                }
            }
        }
    }

    ThemeAddDialog {
        id: addDialog
        library: library
        store: store
        systemScheme: page.systemScheme
        onChosen: theme => page.applyTheme(theme)
    }
    ThemeExportDialog {
        id: exportDialog
        library: library
        style: page.style
        suggestedName: page.activeTheme !== null ? page.activeTheme.name : page.activeProfile !== null ? page.activeProfile.name : ""
    }

    component Swatch: ColorPickerButton {
        property color value
        signal picked(string hex)
        showAlphaChannel: false
        onValueChanged: if (!Qt.colorEqual(color, value)) color = value
        Component.onCompleted: color = value
        onAccepted: c => picked(page.hex(c))
    }
    // Controls that keep showing the style after they were used (a plain binding
    // would be gone with the first click).
    component Check: QQC2.CheckBox {
        id: check
        property bool on
        Binding { target: check; property: "checked"; value: check.on }
        Accessible.name: text
    }
    component Choice: QQC2.ComboBox {
        id: choice
        property int index
        Binding { target: choice; property: "currentIndex"; value: choice.index }
        // A model whose texts change (the language is set after the page is made)
        // starts again at its first entry: the choice is put back.
        onModelChanged: Qt.callLater(() => { if (choice.currentIndex !== choice.index) choice.currentIndex = choice.index; })
    }
    component Hint: QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }
    component ValueSlider: RowLayout {
        id: row
        property alias from: slider.from
        property alias to: slider.to
        property alias stepSize: slider.stepSize
        property real value
        property string valueText
        // (the value's room is as wide as its widest text: the row does not move while it changes)
        property string widestText: ""
        signal moved(real value)
        QQC2.Slider {
            id: slider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            onMoved: row.moved(value)
            Binding { target: slider; property: "value"; value: row.value; when: !slider.pressed }
            Accessible.name: row.Kirigami.FormData.label + " " + row.valueText
        }
        QQC2.Label {
            textFormat: Text.PlainText
            text: row.valueText
            font.features: { "tnum": 1 }
            Layout.minimumWidth: widest.advanceWidth
            TextMetrics { id: widest; font.features: { "tnum": 1 }; text: row.widestText }
        }
    }

    ColumnLayout {
    spacing: 0
    // ---- the layout ------------------------------------------------------------------
    Kirigami.FormLayout {
        id: layoutForm
        Layout.fillWidth: true
        twinFormLayouts: [notchForm, ovalForm, fullscreenForm, lookForm]
        RowLayout {
            objectName: "setting-islandLayout"
            Kirigami.FormData.label: Lang.i18n("Layout:")
            spacing: Kirigami.Units.smallSpacing
            LayoutCard {
                objectName: "layoutNotch"
                text: Lang.i18n("Notch")
                current: page.notch
                onClicked: page.cfg_islandLayout = 0
                NotchOutline {
                    readonly property real k: 0.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(notchShown.pillWidth * k)
                    height: Math.round(Math.max(9, notchShown.pillHeight * k))
                    radius: notchShown.notchRadius * k
                    ear: notchShown.notchEar * k
                    earDepth: notchShown.notchEarDepth * k
                    fillColor: notchShown.notchBody.length === 3 ? "transparent" : notchShown.bodyMid
                    gradientColors: notchShown.notchBody
                    gradientKind: notchShown.notchBodyKind
                    gradientAngle: notchShown.notchBodyAngle
                }
            }
            LayoutCard {
                objectName: "layoutOval"
                text: Lang.i18n("Oval layout")
                current: !page.notch
                onClicked: page.cfg_islandLayout = 1
                ThemePreview {
                    anchors.fill: parent
                    anchors.topMargin: 9
                    style: page.style
                    systemScheme: page.systemScheme
                }
            }
        }
        Hint {
            text: page.notch ? Lang.i18n("Hangs from the top edge as one piece, over a top panel, and opens downwards.")
                             : Lang.i18n("The rounded island of earlier versions, a little below the top edge.")
        }
    }
    // ---- the notch's own settings ----------------------------------------------------------
    NotchSettings {
        id: notchForm
        objectName: "notchSettings"
        Layout.fillWidth: true
        visible: page.notch
        twinFormLayouts: [layoutForm, ovalForm, fullscreenForm, lookForm]
        page: page
        shown: notchShown
    }
    // ---- where the oval island sits (the notch sits at the edge itself) --------------------------
    Kirigami.FormLayout {
        id: ovalForm
        objectName: "ovalSettings"
        Layout.fillWidth: true
        visible: !page.notch
        twinFormLayouts: [layoutForm, notchForm, fullscreenForm, lookForm]
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Oval layout")
        }
        // (set in both looks: a custom style keeps its own, up to 40 px; following the system up to 200 px)
        ValueSlider {
            id: topSlider
            objectName: "setting-topMargin"
            // (search needs: "islandLayout": the oval one, 1)
            readonly property int shown: page.look.top
            Kirigami.FormData.label: Lang.i18n("Distance from top:")
            from: 0; to: page.custom ? 40 : 200
            value: shown
            valueText: Lang.i18n("%1 px", shown)
            onMoved: value => page.put("top", Math.round(value))
        }
        QQC2.CheckBox {
            id: avoidPanelsCheck
            objectName: "setting-avoidPanels"
            // (search needs: "islandLayout": the oval one, 1)
            text: Lang.i18n("Place below top panels")
            Binding { target: avoidPanelsCheck; property: "checked"; value: page.cfg_avoidPanels }
            onToggled: page.cfg_avoidPanels = checked
            Accessible.name: text
        }
    }
    // ---- over a window that fills the screen, both layouts ------------------------------------
    FullscreenSettings {
        id: fullscreenForm
        objectName: "fullscreenSettings"
        Layout.fillWidth: true
        twinFormLayouts: [layoutForm, notchForm, ovalForm, lookForm]
        // (labels beside or above their controls as in the section above it)
        wideMode: notchForm.visible ? notchForm.wideMode : layoutForm.wideMode
        page: page
        shown: notchShown
    }
    Kirigami.FormLayout {
        id: lookForm
        Layout.fillWidth: true
        twinFormLayouts: [layoutForm, notchForm, ovalForm, fullscreenForm]
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Look")
        }
        QQC2.ButtonGroup { id: modeGroup }
        RowLayout {
            objectName: "setting-appearanceMode"
            Kirigami.FormData.label: Lang.i18n("Look:")
            QQC2.RadioButton {
                QQC2.ButtonGroup.group: modeGroup
                id: followRadio
                text: Lang.i18n("Follow the system")
                Binding { target: followRadio; property: "checked"; value: !page.custom }
                onToggled: if (checked) page.cfg_appearanceMode = 0
            }
            QQC2.RadioButton {
                QQC2.ButtonGroup.group: modeGroup
                id: customRadio
                text: Lang.i18n("Custom")
                Binding { target: customRadio; property: "checked"; value: page.custom }
                onToggled: if (checked) page.cfg_appearanceMode = 1
            }
            Kirigami.ContextualHelpButton {
                toolTipText: page.custom ? Lang.i18n("The island keeps the look set below, whatever the system's theme is.")
                    : Lang.i18n("Background, text, border and accent colour come from Plasma and change with it at once: the colour scheme, dark and light, the accent colour. The colours below do not apply; opacity, blur, place, size, roundness, border and shadow under Fine tuning can still be set.")
            }
        }
        QQC2.ComboBox {
            id: sourceCombo
            objectName: "setting-followSource"
            Kirigami.FormData.label: Lang.i18n("Colours from:")
            visible: !page.custom
            model: [Lang.i18n("The colour scheme (like applications)"), Lang.i18n("The Plasma style (like the panel)")]
            Binding { target: sourceCombo; property: "currentIndex"; value: page.cfg_followSource }
            onActivated: index => page.cfg_followSource = index
            Accessible.name: Lang.i18n("Colours from:") + " " + currentText
        }
        Hint {
            visible: !page.custom && sourceCombo.currentIndex === 0 && page.systemScheme === null
            text: Lang.i18n("The colour scheme can only be read with the native helper; the Plasma style's colours are used instead.")
        }
        ValueSlider {
            id: sizeSlider
            objectName: "setting-look.scale"
            Kirigami.FormData.label: Lang.i18n("Size:")
            from: Styles.scaleMin; to: Styles.scaleMax
            stepSize: 5
            value: page.look.scale
            valueText: Lang.percent(page.look.scale)
            widestText: Lang.percent(Styles.scaleMax)
            // (in steps of 5; the island's own size, 100 %, is one of them)
            onMoved: value => page.put("scale", Math.round(value / 5) * 5)
        }
        Kirigami.InlineMessage {
            objectName: "screenLimitMessage"
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            visible: page.cfg_scaleLimitSeen > 0 && page.look.scale > page.cfg_scaleLimitSeen
            type: Kirigami.MessageType.Information
            text: Lang.i18n("Screen limit reached: the open island fits this screen up to %1, so it is shown at that size.", Lang.percent(page.cfg_scaleLimitSeen))
        }
        ValueSlider {
            objectName: "setting-look.opacity"
            Kirigami.FormData.label: Lang.i18n("Opacity:")
            from: 0; to: 100
            value: page.look.opacity
            valueText: Lang.percent(page.look.opacity)
            onMoved: value => page.put("opacity", Math.round(value))
        }

        // ---- presets (a custom look only: hidden while following the system) ------------------
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Ready-made looks")
            visible: page.custom
        }
        // Themes from files and from the store join the list below.
        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            visible: page.custom
            // (without the native module theme files cannot be read or written: said once, briefly; how to get it in Diagnostics)
            RequirementNotice {
                visible: !library.available
                requirement: "native"
                brief: true
            }
            Item { Layout.fillWidth: true; visible: library.available }
            QQC2.Button {
                enabled: library.available
                icon.name: "list-add"
                text: Lang.i18n("Add New…")
                onClicked: addDialog.open()
            }
        }
        Flow {
            objectName: "setting-look.preset"
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            spacing: Kirigami.Units.smallSpacing
            visible: page.custom
            Accessible.name: Lang.i18n("Ready-made looks")
            Repeater {
                model: Styles.order
                delegate: LookCard {
                    required property string modelData
                    look: Styles.defaults(modelData)
                    title: Styles.title(modelData)
                    current: page.style.preset === modelData && page.activeTheme === null
                    onClicked: page.choosePreset(modelData)
                }
            }
            // The user's own themes: all of their settings, as they were saved.
            Repeater {
                model: library.themes
                delegate: LookCard {
                    required property var modelData
                    look: modelData.style
                    title: modelData.name
                    current: page.activeTheme !== null && page.activeTheme.file === modelData.file
                    removable: true
                    asking: page.confirmRemove === modelData.file
                    onClicked: page.applyTheme(modelData)
                    onRemoveRequested: page.confirmRemove = modelData.file
                    onRemoveCancelled: page.confirmRemove = ""
                    onRemoveConfirmed: { page.confirmRemove = ""; library.remove(modelData.file); }
                    // (a tooltip of its own: the shared one would read what a theme's file says as rich text)
                    QQC2.ToolTip {
                        id: about
                        visible: parent.hovered && text.length > 0
                        text: (modelData.author.length > 0 ? Lang.i18n("by %1", modelData.author) : "") + (modelData.author.length > 0 && modelData.description.length > 0 ? "\n" : "") + modelData.description
                        contentItem: QQC2.Label {
                            text: about.text
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
        RowLayout {
            visible: page.custom
            QQC2.Button {
                enabled: !Styles.same(page.style, Styles.defaults(page.style.preset))
                icon.name: "edit-undo"
                text: Lang.i18n("Reset to the preset")
                onClicked: page.use(Styles.defaults(page.style.preset))
            }
            QQC2.Button {
                enabled: library.available
                icon.name: "document-export"
                text: Lang.i18n("Export Theme…")
                onClicked: exportDialog.open()
            }
        }

        // ---- profiles (a custom look only) ---------------------------------------------------
        SettingsFold {
            title: Lang.i18n("Saved looks")
            foldId: "appearance.profiles"
            twin: lookForm
            visible: page.custom
            needs: "appearanceMode"
            keys: ["look.profile"]
            content: Kirigami.FormLayout {
                RowLayout {
                    Kirigami.FormData.label: Lang.i18n("Profile:")
                    Choice {
                        id: profileCombo
                        objectName: "setting-look.profile"
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        enabled: page.profiles.length > 0
                        model: page.profiles.map(p => p.name)
                        index: page.profiles.findIndex(p => p.name === page.cfg_activeProfile)
                        displayText: currentIndex < 0 ? (page.profiles.length > 0 ? Lang.i18n("Choose…") : Lang.i18n("None saved yet"))
                                   : page.profileChanged ? Lang.i18n("%1 (changed)", currentText) : currentText
                        onActivated: page.loadProfile(currentText)
                        Accessible.name: Lang.i18n("Profile:") + " " + displayText
                    }
                    QQC2.Button {
                        visible: page.profileChanged
                        icon.name: "document-save"
                        text: Lang.i18n("Update")
                        onClicked: page.saveProfile(page.cfg_activeProfile)
                    }
                    QQC2.Button {
                        enabled: page.activeProfile !== null
                        icon.name: "edit-delete"
                        text: Lang.i18n("Delete")
                        onClicked: page.deleteProfile(page.cfg_activeProfile)
                    }
                }
                RowLayout {
                    Kirigami.FormData.label: Lang.i18n("Save as:")
                    QQC2.TextField {
                        id: profileName
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        placeholderText: Lang.i18n("e.g. Work, Night")
                        onAccepted: saveButton.clicked()
                        Accessible.name: Lang.i18n("Save as:")
                    }
                    QQC2.Button {
                        id: saveButton
                        enabled: profileName.text.trim().length > 0
                        icon.name: "document-save-as"
                        text: Lang.i18n("Save")
                        onClicked: { page.saveProfile(profileName.text); profileName.text = ""; }
                    }
                }
            }
        }

        // ---- fine tuning ---------------------------------------------------------------
        SettingsFold {
            title: Lang.i18n("Fine tuning")
            foldId: "appearance.tuning"
            twin: lookForm
            keys: ["look.blur", "look.offsetX", "look.radius", "look.background", "look.gradient", "look.control",
                   "look.buttonFill", "look.text", "look.border", "look.shadow"]
            content: Kirigami.FormLayout {
                RowLayout {
                    objectName: "setting-look.blur"
                    Kirigami.FormData.label: Lang.i18n("Blur:")
                    Check {
                        text: Lang.i18n("Blur what is behind the island")
                        on: page.look.blur
                        onToggled: page.put("blur", checked)
                    }
                    Choice {
                        enabled: page.look.blur
                        model: [Lang.i18n("Low"), Lang.i18n("Medium"), Lang.i18n("High")]
                        index: page.look.blurLevel
                        onActivated: page.put("blurLevel", currentIndex)
                        Accessible.name: Lang.i18n("Blur:") + " " + currentText
                    }
                    Kirigami.ContextualHelpButton {
                        toolTipText: Lang.i18n("Needs the optional native helper and the KWin Blur effect. How strongly KWin blurs is one setting for the whole desktop (System Settings → Desktop Effects → Blur); the level here adds frosting over it.")
                    }
                }
                ValueSlider {
                    id: offsetSlider
                    objectName: "setting-look.offsetX"
                    readonly property int shown: page.look.offsetX
                    Kirigami.FormData.label: Lang.i18n("Horizontal position:")
                    from: -100; to: 100
                    value: shown
                    valueText: shown === 0 ? Lang.i18n("Centred") : Lang.i18n("%1 px", (shown > 0 ? "+" : "") + shown)
                    onMoved: value => page.put("offsetX", Math.abs(value) < 4 ? 0 : Math.round(value))
                }
                ValueSlider {
                    objectName: "setting-look.radius"
                    Kirigami.FormData.label: Lang.i18n("Corner roundness:")
                    from: 0; to: 100
                    value: page.look.radius
                    valueText: page.look.radius === 100 ? Lang.i18n("Capsule") : page.look.radius === 0 ? Lang.i18n("Sharp") : Lang.percent(page.look.radius)
                    onMoved: value => page.put("radius", Math.round(value))
                }
                // (the colours: a custom look only, hidden while following the system)
                RowLayout {
                    objectName: "setting-look.background"
                    Kirigami.FormData.label: Lang.i18n("Background:")
                    visible: page.custom
                    Choice {
                        model: [Lang.i18n("Solid colour"), Lang.i18n("Gradient")]
                        index: page.gradient ? 1 : 0
                        onActivated: page.set("fill", currentIndex === 1 ? "gradient" : "solid")
                        Accessible.name: Lang.i18n("Background:") + " " + currentText
                    }
                    Swatch {
                        visible: !page.gradient
                        enabled: page.style.background !== "accent"
                        value: page.style.background === "accent" ? shown.systemAccent : page.style.background
                        onPicked: hex => page.set("background", hex)
                    }
                    Check {
                        visible: !page.gradient
                        text: Lang.i18n("Use the system's accent colour")
                        on: page.style.background === "accent"
                        onToggled: page.set("background", checked ? "accent" : page.hex(shown.systemAccent))
                    }
                }
                RowLayout {
                    objectName: "setting-look.gradient"
                    Kirigami.FormData.label: Lang.i18n("Gradient colours:")
                    visible: page.custom && page.gradient
                    // Three buttons that stay, not a Repeater: delegates that go away while
                    // this row is hidden (a solid look is chosen) crash the layout.
                    Swatch {
                        value: page.style.gradientStops[0]
                        onPicked: hex => page.setStop(0, hex)
                    }
                    Swatch {
                        visible: page.style.gradientStops.length === 3
                        value: page.style.gradientStops[1]
                        onPicked: hex => page.setStop(1, hex)
                    }
                    Swatch {
                        value: page.style.gradientStops[page.style.gradientStops.length - 1]
                        onPicked: hex => page.setStop(page.style.gradientStops.length - 1, hex)
                    }
                    Check {
                        text: Lang.i18n("Three colours")
                        on: page.style.gradientStops.length === 3
                        onToggled: page.setThirdStop(checked)
                    }
                }
                RowLayout {
                    Kirigami.FormData.label: Lang.i18n("Gradient type:")
                    visible: page.custom && page.gradient
                    Choice {
                        model: [Lang.i18n("Linear"), Lang.i18n("Radial (from the middle)")]
                        index: page.style.gradientType === "radial" ? 1 : 0
                        onActivated: page.set("gradientType", currentIndex === 1 ? "radial" : "linear")
                        Accessible.name: Lang.i18n("Gradient type:") + " " + currentText
                    }
                }
                ValueSlider {
                    Kirigami.FormData.label: Lang.i18n("Gradient angle:")
                    visible: page.custom && page.gradient
                    enabled: page.style.gradientType === "linear"
                    from: 0; to: 360
                    stepSize: 5
                    value: page.style.gradientAngle
                    valueText: Lang.i18n("%1°", page.style.gradientAngle)
                    onMoved: value => page.set("gradientAngle", Math.round(value))
                }
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                    visible: page.custom && shown.gradientUneven
                    type: Kirigami.MessageType.Warning
                    text: Lang.i18n("This gradient has both very light and very dark parts: one text colour cannot be read well on all of it (the weakest contrast is %1:1). Bring the colours closer in brightness, or set the text colour yourself.", shown.gradientContrast.toFixed(1))
                }
                RowLayout {
                    objectName: "setting-look.control"
                    Kirigami.FormData.label: Lang.i18n("Buttons and controls:")
                    visible: page.custom
                    Swatch {
                        enabled: page.style.control !== "accent"
                        value: shown.controlGiven
                        onPicked: hex => page.set("control", hex)
                    }
                    Check {
                        text: Lang.i18n("Use the system's accent colour")
                        on: page.style.control === "accent"
                        onToggled: page.set("control", checked ? "accent" : page.hex(shown.controlGiven))
                    }
                }
                RowLayout {
                    objectName: "setting-look.buttonFill"
                    Kirigami.FormData.label: Lang.i18n("Button colour:")
                    visible: page.custom
                    Swatch {
                        objectName: "buttonFillSwatch"
                        enabled: page.style.buttonFill.length > 0
                        value: shown.faint
                        onPicked: hex => page.set("buttonFill", hex)
                    }
                    Check {
                        objectName: "buttonFillAutomatic"
                        text: Lang.i18n("Automatic (a hint of the text colour)")
                        on: page.style.buttonFill.length === 0
                        onToggled: page.set("buttonFill", checked ? "" : page.hex(shown.over(shown.faint, shown.surface)))
                    }
                    Kirigami.ContextualHelpButton {
                        toolTipText: Lang.i18n("The fill of the island's buttons, tiles and cards. A colour set here is made lighter or darker as far as the text on it needs to stay readable. Buttons and controls above is the colour of what is chosen or switched on.")
                    }
                }
                RowLayout {
                    objectName: "setting-look.text"
                    Kirigami.FormData.label: Lang.i18n("Text colour:")
                    visible: page.custom
                    Swatch {
                        enabled: page.style.text.length > 0
                        value: shown.text
                        onPicked: hex => page.set("text", hex)
                    }
                    Check {
                        text: Lang.i18n("Automatic (readable on the background)")
                        on: page.style.text.length === 0
                        onToggled: page.set("text", checked ? "" : page.hex(shown.text))
                    }
                }
                // (the look's border and shadow: not the notch's, which has a border of its own)
                RowLayout {
                    objectName: "setting-look.border"
                    Kirigami.FormData.label: Lang.i18n("Border:")
                    visible: !page.notch
                    Check {
                        text: Lang.i18n("Show")
                        on: page.look.border
                        onToggled: page.put("border", checked)
                    }
                    QQC2.SpinBox {
                        enabled: page.look.border
                        id: widthSpin
                        from: 1; to: 4
                        Binding { target: widthSpin; property: "value"; value: page.look.borderWidth }
                        textFromValue: v => Lang.i18n("%1 px", v)
                        valueFromText: t => parseInt(t)
                        onValueModified: page.put("borderWidth", value)
                        Accessible.name: Lang.i18n("Border:")
                    }
                }
                RowLayout {
                    visible: !page.notch && page.custom && page.style.border
                    Swatch {
                        enabled: page.style.borderColor.length > 0
                        value: Qt.rgba(shown.rimTop.r, shown.rimTop.g, shown.rimTop.b, 1)
                        onPicked: hex => page.set("borderColor", hex)
                    }
                    Check {
                        text: Lang.i18n("The look's own border colour")
                        on: page.style.borderColor.length === 0
                        onToggled: page.set("borderColor", checked ? "" : page.hex(shown.rimTop))
                    }
                }
                Choice {
                    objectName: "setting-look.shadow"
                    Kirigami.FormData.label: Lang.i18n("Shadow:")
                    visible: !page.notch
                    model: [Lang.i18n("None"), Lang.i18n("Light"), Lang.i18n("Strong")]
                    index: page.look.shadow
                    onActivated: page.put("shadow", currentIndex)
                    Accessible.name: Lang.i18n("Shadow:") + " " + currentText
                }
            }
        }
    }
    }
}
