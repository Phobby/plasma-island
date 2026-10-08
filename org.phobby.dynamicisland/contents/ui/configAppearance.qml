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
import org.kde.kquickcontrols as KQC
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property int cfg_appearanceMode
    property alias cfg_followSource: sourceCombo.currentIndex
    property string cfg_customStyle
    property string cfg_styleProfiles
    property string cfg_activeProfile
    // Earlier settings: the first custom style starts from them (see Styles.parse).
    property int cfg_surfaceOpacity
    property bool cfg_blurEnabled
    property int cfg_themeMode
    // Where the island sits while following the system (a custom style brings its own).
    property int cfg_topMargin
    property int cfg_horizontalOffset
    // The Habits calendar: 0 = GitHub's greens, 1 = the system's accent colour (also in Habits).
    property int cfg_habitsColorSource

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
        c.previewActive = true;
        published = true;
    }
    onPlacedChanged: publish()
    onStyleChanged: publish()
    onCfg_appearanceModeChanged: publish()
    onCfg_followSourceChanged: publish()
    onCfg_topMarginChanged: publish()
    onCfg_horizontalOffsetChanged: publish()
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
        style: page.style
        blurActive: true
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

    component Swatch: KQC.ColorButton {
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
        signal moved(real value)
        QQC2.Slider {
            id: slider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            onMoved: row.moved(value)
            Binding { target: slider; property: "value"; value: row.value; when: !slider.pressed }
        }
        QQC2.Label { textFormat: Text.PlainText; text: row.valueText; font.features: { "tnum": 1 } }
    }

    Kirigami.FormLayout {
        QQC2.ButtonGroup { id: modeGroup }
        QQC2.RadioButton {
            Kirigami.FormData.label: Lang.i18n("Look:")
            QQC2.ButtonGroup.group: modeGroup
            id: followRadio
            text: Lang.i18n("Follow the system")
            Binding { target: followRadio; property: "checked"; value: !page.custom }
            onToggled: if (checked) page.cfg_appearanceMode = 0
        }
        Hint {
            text: Lang.i18n("Background, text, border and accent colour come from Plasma and change with it at once: the colour scheme, dark and light, the accent colour. Of what is below, only where the island sits applies: its distance from the top and its horizontal position.")
        }
        QQC2.ComboBox {
            id: sourceCombo
            Kirigami.FormData.label: Lang.i18n("Colours from:")
            enabled: !page.custom
            model: [Lang.i18n("The colour scheme (like applications)"), Lang.i18n("The Plasma style (like the panel)")]
        }
        Hint {
            visible: !page.custom && sourceCombo.currentIndex === 0 && page.systemScheme === null
            text: Lang.i18n("The colour scheme can only be read with the native helper; the Plasma style's colours are used instead.")
        }
        QQC2.RadioButton {
            QQC2.ButtonGroup.group: modeGroup
            id: customRadio
            text: Lang.i18n("Custom")
            Binding { target: customRadio; property: "checked"; value: page.custom }
            onToggled: if (checked) page.cfg_appearanceMode = 1
        }
        Hint {
            text: Lang.i18n("The island keeps the look set below, whatever the system's theme is.")
        }

        // ---- presets ---------------------------------------------------------------
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Ready-made looks")
        }
        // Themes from files and from the store join the list below.
        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            QQC2.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: !library.available
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("Theme files need the native helper (install.sh builds it).")
            }
            Item { Layout.fillWidth: true; visible: library.available }
            QQC2.Button {
                enabled: page.custom && library.available
                icon.name: "list-add"
                text: Lang.i18n("Add New…")
                onClicked: addDialog.open()
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            spacing: Kirigami.Units.smallSpacing
            enabled: page.custom
            opacity: enabled ? 1 : 0.45
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
            QQC2.Button {
                enabled: page.custom && !Styles.same(page.style, Styles.defaults(page.style.preset))
                icon.name: "edit-undo"
                text: Lang.i18n("Reset to the preset")
                onClicked: page.use(Styles.defaults(page.style.preset))
            }
            QQC2.Button {
                enabled: page.custom && library.available
                icon.name: "document-export"
                text: Lang.i18n("Export Theme…")
                onClicked: exportDialog.open()
            }
        }

        // ---- profiles ---------------------------------------------------------------
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Saved looks")
        }
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Profile:")
            enabled: page.custom
            Choice {
                id: profileCombo
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                enabled: page.profiles.length > 0
                model: page.profiles.map(p => p.name)
                index: page.profiles.findIndex(p => p.name === page.cfg_activeProfile)
                displayText: currentIndex < 0 ? (page.profiles.length > 0 ? Lang.i18n("Choose…") : Lang.i18n("None saved yet"))
                           : page.profileChanged ? Lang.i18n("%1 (changed)", currentText) : currentText
                onActivated: page.loadProfile(currentText)
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
            enabled: page.custom
            QQC2.TextField {
                id: profileName
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                placeholderText: Lang.i18n("e.g. Work, Night")
                onAccepted: saveButton.clicked()
            }
            QQC2.Button {
                id: saveButton
                enabled: profileName.text.trim().length > 0
                icon.name: "document-save-as"
                text: Lang.i18n("Save")
                onClicked: { page.saveProfile(profileName.text); profileName.text = ""; }
            }
        }

        // ---- fine tuning ---------------------------------------------------------------
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Fine tuning")
        }
        ValueSlider {
            Kirigami.FormData.label: Lang.i18n("Opacity:")
            enabled: page.custom
            from: 0; to: 100
            value: page.style.opacity
            valueText: Lang.percent(page.style.opacity)
            onMoved: value => page.set("opacity", Math.round(value))
        }
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Blur:")
            enabled: page.custom
            Check {
                text: Lang.i18n("Blur what is behind the island")
                on: page.style.blur
                onToggled: page.set("blur", checked)
            }
            Choice {
                enabled: page.style.blur
                model: [Lang.i18n("Low"), Lang.i18n("Medium"), Lang.i18n("High")]
                index: page.style.blurLevel
                onActivated: page.set("blurLevel", currentIndex)
            }
        }
        Hint {
            text: Lang.i18n("Needs the optional native helper and the KWin Blur effect. How strongly KWin blurs is one setting for the whole desktop (System Settings → Desktop Effects → Blur); the level here adds frosting over it.")
        }
        // Where the island sits is set in both looks: a custom style keeps its own place,
        // following the system has one of its own (the distance is General's, up to 200 px there).
        ValueSlider {
            id: topSlider
            objectName: "topSlider"
            readonly property int shown: page.custom ? page.style.top : page.cfg_topMargin
            Kirigami.FormData.label: Lang.i18n("Distance from top:")
            from: 0; to: page.custom ? 40 : 200
            value: shown
            valueText: Lang.i18n("%1 px", shown)
            onMoved: value => { if (page.custom) page.set("top", Math.round(value)); else page.cfg_topMargin = Math.round(value); }
        }
        ValueSlider {
            id: offsetSlider
            objectName: "offsetSlider"
            readonly property int shown: page.custom ? page.style.offsetX : page.cfg_horizontalOffset
            Kirigami.FormData.label: Lang.i18n("Horizontal position:")
            from: -100; to: 100
            value: shown
            valueText: shown === 0 ? Lang.i18n("Centred") : Lang.i18n("%1 px", (shown > 0 ? "+" : "") + shown)
            onMoved: value => {
                const px = Math.abs(value) < 4 ? 0 : Math.round(value);
                if (page.custom) page.set("offsetX", px); else page.cfg_horizontalOffset = px;
            }
        }
        ValueSlider {
            Kirigami.FormData.label: Lang.i18n("Size:")
            enabled: page.custom
            from: 80; to: 120
            value: page.style.scale
            valueText: Lang.percent(page.style.scale)
            onMoved: value => page.set("scale", Math.round(value))
        }
        ValueSlider {
            Kirigami.FormData.label: Lang.i18n("Corner roundness:")
            enabled: page.custom
            from: 0; to: 100
            value: page.style.radius
            valueText: page.style.radius === 100 ? Lang.i18n("Capsule") : page.style.radius === 0 ? Lang.i18n("Sharp") : Lang.percent(page.style.radius)
            onMoved: value => page.set("radius", Math.round(value))
        }
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Background:")
            enabled: page.custom
            Choice {
                model: [Lang.i18n("Solid colour"), Lang.i18n("Gradient")]
                index: page.gradient ? 1 : 0
                onActivated: page.set("fill", currentIndex === 1 ? "gradient" : "solid")
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
            Kirigami.FormData.label: Lang.i18n("Gradient colours:")
            visible: page.gradient
            enabled: page.custom
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
            visible: page.gradient
            enabled: page.custom
            Choice {
                model: [Lang.i18n("Linear"), Lang.i18n("Radial (from the middle)")]
                index: page.style.gradientType === "radial" ? 1 : 0
                onActivated: page.set("gradientType", currentIndex === 1 ? "radial" : "linear")
            }
        }
        ValueSlider {
            Kirigami.FormData.label: Lang.i18n("Gradient angle:")
            visible: page.gradient
            enabled: page.custom && page.style.gradientType === "linear"
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
            Kirigami.FormData.label: Lang.i18n("Buttons and controls:")
            enabled: page.custom
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
            Kirigami.FormData.label: Lang.i18n("Text colour:")
            enabled: page.custom
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
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Border:")
            enabled: page.custom
            Check {
                text: Lang.i18n("Show")
                on: page.style.border
                onToggled: page.set("border", checked)
            }
            QQC2.SpinBox {
                enabled: page.style.border
                id: widthSpin
                from: 1; to: 4
                Binding { target: widthSpin; property: "value"; value: page.style.borderWidth }
                textFromValue: v => Lang.i18n("%1 px", v)
                valueFromText: t => parseInt(t)
                onValueModified: page.set("borderWidth", value)
            }
        }
        RowLayout {
            enabled: page.custom && page.style.border
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
            Kirigami.FormData.label: Lang.i18n("Shadow:")
            enabled: page.custom
            model: [Lang.i18n("None"), Lang.i18n("Light"), Lang.i18n("Strong")]
            index: page.style.shadow
            onActivated: page.set("shadow", currentIndex)
        }

        // ---- the Habits calendar (whatever the look above is) -------------------------
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Habits")
        }
        Check {
            Kirigami.FormData.label: Lang.i18n("Calendar:")
            text: Lang.i18n("Use the system's accent colour")
            on: page.cfg_habitsColorSource === 1
            onToggled: page.cfg_habitsColorSource = checked ? 1 : 0
        }
        Hint {
            text: Lang.i18n("The days of the Habits calendar are shaded in GitHub's green otherwise.")
        }
    }
}
