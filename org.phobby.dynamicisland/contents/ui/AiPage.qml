/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "AI": a box for quick questions. On top the source of the answers and its
    model, under them the conversation, at the bottom a field of several
    lines: Enter sends, Shift+Enter makes a new line; while an answer is
    written the button stops it. The answer is shown as it arrives, as
    Markdown; a code block gets a box of its own with "Copy".

    Deliberately small. Text only: no file, picture or drop is taken, and
    nothing of the clipboard, the screen, the notes or the calendar is ever
    added by itself; what is to be asked is typed or pasted by the user. A
    question longer than the limit is not sent (the Claude app or a terminal
    is the place for that). Not an agent: see ai/ClaudeCliProvider.qml.

    What an answer contains is never acted on: a link is only opened after
    asking, and only a web address; a picture is not fetched (it is shown as
    its link) and HTML is shown as text (AiMarkdown.js).

    Before the first question to a source its notice is shown once: where the
    text goes and that it uses up that account's usage. The backend refuses
    to send before it was accepted.

    Sources are connected right here, like the notes apps on the Notes page:
    what is found on this computer (Claude Code, Ollama) is offered first, a
    key or a server of one's own under "Add another". A command that
    installs or starts something is only ever shown to be copied.

    The conversation and the running request live in AiBackend, not here: the
    page is made anew each time the island opens and finds them again. While
    an answer is written the island stays open (Escape lets it go; the
    answer goes on and the island says when it is ready).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "AiMarkdown.js" as Markdown
import "ai/AiStream.js" as Stream

Item {
    id: page

    required property Theme theme
    required property var ai                // AiBackend
    signal defaultPicked(string id)

    // "chat" | "cards" (nothing connected) | "kinds" (add another) | "form" (connect `formKind`)
    // | "install" (how to get or start `helpKind`) | "notice" | "models" | "sources" | "link"
    property string view: "chat"
    // The field has the keyboard (the island only takes it on request).
    property bool typing: false
    // Escape while an answer is written: the island may close, the answer goes on.
    property bool letGo: false
    readonly property bool interacting: visible && typing && (view === "chat" || view === "form" || view === "models")
    readonly property bool holdOpen: visible && ai.busy && !letGo
    // A conversation needs more room than the other pages: the taller island.
    // (Not for typing alone: the field that was just clicked would move away from under the pointer.)
    readonly property bool tall: visible && (view === "chat" ? ai.messages.length > 0 || ai.busy : view !== "cards")

    Binding { target: page.ai; property: "viewing"; value: page.visible; restoreMode: Binding.RestoreNone }
    Component.onDestruction: ai.viewing = false
    onVisibleChanged: if (visible) arrive(); else typing = false
    Component.onCompleted: arrive()
    function arrive(): void {
        if (!visible) return;
        ai.restore();
        if (ai.available) { if (view === "cards") view = "chat"; return; }
        if (view === "chat") view = "cards";
        if (!detected) detect();
    }
    Connections {
        target: page.ai
        function onAvailableChanged() { if (!page.ai.available && (page.view === "chat" || page.view === "sources" || page.view === "models")) { page.view = "cards"; page.detect(); } }
        function onBusyChanged() { if (!page.ai.busy) page.letGo = false; }
    }

    property string status: ""
    property bool statusIsError: false
    function say(text: string, error: bool): void {
        status = text; statusIsError = error;
        statusTimer.restart();
    }
    Timer { id: statusTimer; interval: 6000; onTriggered: page.status = "" }

    // Copies without the window having the keyboard (as the Notes page does).
    TextEdit { id: clip; visible: false; textFormat: TextEdit.PlainText }
    function copy(text: string): void {
        clip.text = text;
        clip.selectAll();
        clip.copy();
        clip.text = "";
    }

    // ---- asking ----------------------------------------------------------------------
    readonly property var current: ai.current
    readonly property int over: input.length - ai.maxChars
    property string waitingText: ""
    // The keyboard goes to `item` once the island has taken it (a call on the page itself: dropped if the page is gone by then).
    property Item focusTarget: null
    function focusLater(item: Item): void {
        typing = true;
        focusTarget = item;
        Qt.callLater(page.focusNow);
    }
    function focusNow(): void {
        if (focusTarget !== null) focusTarget.forceActiveFocus();
        focusTarget = null;
    }
    function focusInput(): void { focusLater(input); }
    function submit(): void {
        const why = ai.send(input.text);
        if (why === "consent") {
            waitingText = input.text;
            typing = false;
            view = "notice";
        } else if (why === "") {
            input.text = "";
            scroll.stick = true;
            letGo = false;
        }
        // ("empty", "long", "busy", "none": the button is off for those, and the reason stands beside the field)
    }
    // The notice's "Continue".
    function accept(): void {
        if (current === null) { view = "cards"; return; }
        ai.acknowledge(current.id);
        view = "chat";
        const text = waitingText;
        waitingText = "";
        if (text.length > 0 && ai.send(text) === "") { input.text = ""; scroll.stick = true; }
        else if (retrying && ai.retry() === "") scroll.stick = true;
        retrying = false;
        focusInput();
    }
    property bool retrying: false
    function retry(): void {
        const why = ai.retry();
        if (why === "consent") { retrying = true; view = "notice"; }
        else if (why === "") scroll.stick = true;
    }
    // Escape: the keyboard is given back; while an answer is written the island may close and the answer goes on.
    function release(): void {
        typing = false;
        if (ai.busy) letGo = true;
    }

    // ---- links -----------------------------------------------------------------------
    property string link: ""
    property string viewBeforeLink: "chat"
    function askLink(address: string): void {
        link = String(address);
        viewBeforeLink = view;
        typing = false;
        view = "link";
    }

    // ---- connecting ------------------------------------------------------------------
    property var found: ({})                // kind → what detect() said
    property bool detected: false
    property bool connecting: false
    property string formKind: ""
    property string formError: ""
    property bool farAccepted: false
    property string helpKind: ""
    readonly property var kinds: ai.catalog.kinds
    function info(kind: string): var { return ai.catalog.kind(kind); }
    function detect(): void {
        ai.detect(result => { found = result; detected = true; });
    }
    function whereIcon(where: string): string {
        return where === "cli" ? "utilities-terminal-symbolic" : where === "device" ? "computer-symbolic" : "globe-symbolic";
    }
    function connected(result: var, kind: string): void {
        ai.chosenId = result.id;
        if (info(kind).key === true && !result.kept) say(Lang.i18n("KDE Wallet could not be reached: the key is kept only until the shell restarts."), true);
        const s = ai.source(result.id);
        // several models and none preferred: the user chooses
        if (s !== null && s.model.length === 0 && info(kind).modelOptional !== true) showModels(); else view = "chat";
    }
    // A command is there when it was found, a model server when it answers.
    function here(kind: string, state: var): bool {
        return info(kind).where === "cli" ? state.found === true : state.running === true;
    }
    // A kind that needs nothing typed (Claude Code, Ollama): connect, or say how to get it.
    function pickCard(kind: string): void {
        const state = found[kind] || {};
        if (!here(kind, state)) { helpKind = kind; view = "install"; return; }
        if (connecting) return;
        connecting = true;
        ai.connect(kind, {}, result => {
            connecting = false;
            if (!result.ok) { say(result.error, true); return; }
            connected(result, kind);
        });
    }
    function showForm(kind: string): void {
        formKind = kind; formError = ""; farAccepted = false; connecting = false;
        serverField.text = ""; keyField.text = "";
        view = "form";
        focusLater(info(kind).needsServer === true ? serverField.input : keyField.input);
    }
    // The address typed into the form: where it is, and whether that is this computer.
    readonly property var typedAddress: Stream.address(serverField.text)
    readonly property bool far: view === "form" && formKind.length > 0 && info(formKind).needsServer === true && typedAddress.ok && !Stream.isThisDevice(typedAddress.host)
    function submitForm(): void {
        if (connecting) return;
        const kind = info(formKind);
        // a server that is not this computer, given as a "local" one: said first, connected on the second press
        if (far && kind.where === "device" && !farAccepted) { farAccepted = true; return; }
        connecting = true; formError = "";
        ai.connect(formKind, { server: serverField.text, key: keyField.text }, result => {
            connecting = false;
            if (!result.ok) { formError = result.error; return; }
            keyField.text = "";
            typing = false;
            connected(result, formKind);
        });
    }
    function showSources(): void {
        typing = false;
        view = "sources";
        detect();
    }

    // ---- models ----------------------------------------------------------------------
    property var modelList: []
    property string modelError: ""
    property bool modelBusy: false
    property string modelFilter: ""
    readonly property var shownModels: {
        const q = modelFilter.trim().toLowerCase();
        return q.length === 0 ? modelList : modelList.filter(m => m.id.toLowerCase().indexOf(q) >= 0 || m.name.toLowerCase().indexOf(q) >= 0);
    }
    function modelName(s: var): string {
        if (s === null) return "";
        if (s.model.length === 0) return info(s.kind).modelOptional === true ? Lang.i18n("Own choice") : Lang.i18n("Model…");
        const known = (ai.modelLists[s.id] || []).find(m => m.id === s.model);
        return known ? known.name : s.model;
    }
    function showModels(): void {
        if (current === null) return;
        view = "models";
        typing = false;
        modelFilter = ""; modelField.text = "";
        loadModels(false);
    }
    function loadModels(fresh: bool): void {
        const s = current;
        modelBusy = true; modelError = "";
        const done = (list, problem) => {
            modelBusy = false;
            modelList = list;
            modelError = problem ? ai.problemText(problem, ai.whereOf(s), s.name) : list.length === 0 ? Lang.i18n("The source lists no model.") : "";
        };
        if (fresh) ai.fetchModels(s, done); else ai.models(s, done);
    }
    function chooseModel(id: string): void {
        ai.setModel(current.id, id);
        view = "chat";
    }

    // =====================================================================================
    component Chip: Rectangle {
        id: chip
        property string label
        property string icon
        signal clicked()
        implicitWidth: Math.min(170, chipRow.implicitWidth + 16)
        implicitHeight: 22
        radius: 11
        color: chipMouse.pressed ? page.theme.pressedFill : chipMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface)) : page.theme.faint
        Behavior on color { ColorAnimation { duration: 120 } }
        RowLayout {
            id: chipRow
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 4
            Kirigami.Icon {
                visible: chip.icon.length > 0
                Layout.preferredWidth: 11
                Layout.preferredHeight: 11
                source: chip.icon
                color: page.theme.subText
                isMask: true
            }
            Text {
                Layout.fillWidth: true
                text: chip.label
                color: page.theme.text
                font.pointSize: page.theme.fontSmall * 0.9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }
    // A view's title with the way back.
    component Heading: RowLayout {
        id: heading
        property string title
        property string icon
        signal back()
        spacing: 6
        IconButton {
            iconName: "go-previous-symbolic"
            iconSize: 12
            implicitWidth: 20; implicitHeight: 20
            color: page.theme.text
            hoverColor: page.theme.faint
            onClicked: heading.back()
        }
        Kirigami.Icon {
            visible: heading.icon.length > 0
            Layout.preferredWidth: 13
            Layout.preferredHeight: 13
            source: heading.icon
            color: page.theme.subText
            isMask: true
        }
        Text {
            Layout.fillWidth: true
            text: heading.title
            color: page.theme.text
            font.pointSize: page.theme.fontSmall
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }
    // A command to be copied and run by the user, never by the island.
    component CommandLine: RowLayout {
        id: line
        property string command
        spacing: 6
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 14
            color: page.theme.faint
            clip: true
            TextEdit {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextEdit.AlignVCenter
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.PlainText
                text: line.command
                color: page.theme.text
                selectionColor: page.theme.control
                font.family: "monospace"
                font.pointSize: page.theme.fontSmall * 0.85
            }
        }
        PillButton {
            theme: page.theme
            primary: true
            text: copiedTimer.running ? Lang.i18n("Copied") : Lang.i18n("Copy")
            onClicked: { page.copy(line.command); copiedTimer.restart(); }
            Timer { id: copiedTimer; interval: 2000 }
        }
    }

    // An answer: text as Markdown, code blocks in boxes of their own.
    component Answer: Column {
        id: answer
        property string text
        spacing: 5
        Repeater {
            model: Markdown.segments(answer.text)
            delegate: Column {
                id: part
                required property var modelData
                width: answer.width
                Text {
                    visible: !part.modelData.code
                    width: parent.width
                    wrapMode: Text.Wrap
                    textFormat: Text.MarkdownText
                    text: part.modelData.code ? "" : Markdown.safe(part.modelData.text)
                    color: page.theme.text
                    linkColor: page.theme.readable(page.theme.control, page.theme.surface)
                    font.pointSize: page.theme.fontSmall
                    onLinkActivated: link => page.askLink(link)
                    HoverHandler { cursorShape: parent.hoveredLink.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }
                Rectangle {
                    visible: part.modelData.code
                    width: parent.width
                    height: visible ? codeColumn.implicitHeight + 10 : 0
                    radius: 8
                    color: page.theme.faint
                    Column {
                        id: codeColumn
                        x: 8
                        y: 5
                        width: parent.width - 16
                        spacing: 2
                        RowLayout {
                            width: parent.width
                            Text {
                                Layout.fillWidth: true
                                text: part.modelData.code && part.modelData.lang.length > 0 ? part.modelData.lang : Lang.i18n("code")
                                color: page.theme.subText
                                font.pointSize: page.theme.fontSmall * 0.85
                                elide: Text.ElideRight
                            }
                            PillButton {
                                theme: page.theme
                                implicitHeight: 18
                                text: codeCopied.running ? Lang.i18n("Copied") : Lang.i18n("Copy")
                                onClicked: { page.copy(part.modelData.text); codeCopied.restart(); }
                                Timer { id: codeCopied; interval: 2000 }
                            }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            textFormat: Text.PlainText
                            text: part.modelData.code ? part.modelData.text : ""
                            color: page.theme.text
                            font.family: "monospace"
                            font.pointSize: page.theme.fontSmall * 0.9
                        }
                    }
                }
            }
        }
    }

    // ---- the conversation ------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "chat"
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Chip {
                objectName: "sourceChip"
                icon: page.current !== null ? page.whereIcon(page.ai.whereOf(page.current)) : ""
                label: page.current !== null ? page.ai.label(page.current) : ""
                onClicked: page.showSources()
            }
            Chip {
                objectName: "modelChip"
                label: page.modelName(page.current)
                onClicked: page.showModels()
            }
            Item { Layout.fillWidth: true }
            PillButton {
                objectName: "newChat"
                visible: page.ai.messages.length > 0
                theme: page.theme
                implicitHeight: 22
                text: Lang.i18n("New chat")
                onClicked: { page.ai.newChat(); page.focusInput(); }
            }
        }
        Text {
            Layout.fillWidth: true
            readonly property string note: page.status.length > 0 ? page.status : Lang.i18n("For quick questions.")
            text: note
            color: page.status.length > 0 && page.statusIsError ? page.theme.readable(page.theme.warning, page.theme.surface) : page.theme.subText
            font.pointSize: page.theme.fontSmall * 0.85
            elide: Text.ElideRight
        }

        IslandFlickable {
            id: scroll
            objectName: "conversation"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: column.implicitHeight
            // Follows the end while the answer is written, until the user scrolls away from it.
            property bool stick: true
            function toEnd(): void { if (stick) contentY = Math.max(0, contentHeight - height); }
            onContentHeightChanged: toEnd()
            onHeightChanged: toEnd()
            onMovementEnded: stick = atYEnd

            Column {
                id: column
                width: scroll.width
                spacing: 6

                Repeater {
                    model: page.ai.messages
                    delegate: Column {
                        id: message
                        required property var modelData
                        required property int index
                        readonly property bool mine: modelData.role === "user"
                        readonly property bool last: index === page.ai.messages.length - 1
                        width: column.width
                        spacing: 2

                        // the question
                        Rectangle {
                            visible: message.mine
                            anchors.right: parent.right
                            width: Math.min(parent.width * 0.88, question.implicitWidth + 16)
                            height: visible ? question.implicitHeight + 8 : 0
                            radius: 10
                            color: page.theme.faint
                            Text {
                                id: question
                                x: 8
                                y: 4
                                width: parent.width - 16
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                text: message.mine ? message.modelData.text : ""
                                color: page.theme.text
                                font.pointSize: page.theme.fontSmall
                            }
                        }
                        // the answer
                        Loader {
                            active: !message.mine
                            visible: active
                            width: parent.width
                            sourceComponent: Answer { text: message.modelData.text }
                        }
                        // what happened to it, and what can be done
                        RowLayout {
                            visible: message.modelData.problem !== undefined || message.modelData.stopped === true || message.modelData.cut === true || !message.mine
                            width: parent.width
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                horizontalAlignment: message.mine ? Text.AlignRight : Text.AlignLeft
                                text: message.modelData.problem !== undefined ? page.ai.problemOf(message.modelData)
                                    : message.modelData.stopped === true ? Lang.i18n("Stopped.")
                                    : message.modelData.cut === true ? Lang.i18n("Cut off at the length limit (Settings → AI).") : ""
                                color: message.modelData.problem !== undefined ? page.theme.readable(page.theme.danger, page.theme.surface) : page.theme.subText
                                font.pointSize: page.theme.fontSmall * 0.85
                            }
                            PillButton {
                                visible: message.last && !page.ai.busy && (message.modelData.problem !== undefined || message.modelData.stopped === true)
                                theme: page.theme
                                implicitHeight: 18
                                text: Lang.i18n("Try again")
                                onClicked: page.retry()
                            }
                            PillButton {
                                visible: !message.mine
                                theme: page.theme
                                implicitHeight: 18
                                text: answerCopied.running ? Lang.i18n("Copied") : Lang.i18n("Copy")
                                onClicked: { page.copy(message.modelData.text); answerCopied.restart(); }
                                Timer { id: answerCopied; interval: 2000 }
                            }
                        }
                    }
                }

                // nothing asked yet: what the box is for
                Item {
                    objectName: "emptyHint"
                    visible: page.ai.messages.length === 0 && !page.ai.busy
                    width: column.width
                    height: Math.max(hint.implicitHeight, scroll.height - 2)
                    Text {
                        id: hint
                        anchors.centerIn: parent
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: Lang.i18n("Short questions, short answers.\nFor longer work use the Claude app or a terminal.")
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.9
                    }
                }
                // the answer that is being written
                Loader {
                    active: page.ai.busy
                    visible: active
                    width: column.width
                    sourceComponent: Column {
                        spacing: 4
                        Answer { width: parent.width; text: page.ai.streaming }
                        AiDots {
                            objectName: "thinking"
                            color: page.theme.subText
                            running: visible && page.visible
                        }
                    }
                }
            }
        }

        // why it would not be sent, or that the chat has grown long
        RowLayout {
            Layout.fillWidth: true
            visible: page.over > 0 || (page.ai.lengthy && !page.ai.busy)
            spacing: 6
            Text {
                objectName: "limitNote"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: page.over > 0 ? Lang.i18n("Too long for this box (%1 of %2 characters). Use the Claude app or a terminal for this.", input.length, page.ai.maxChars)
                                    : Lang.i18n("This chat has grown long: all of it is sent with every question. A new chat answers faster.")
                color: page.theme.readable(page.theme.warning, page.theme.surface)
                font.pointSize: page.theme.fontSmall * 0.85
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(28, Math.min(74, input.implicitHeight + 10))
                radius: Math.min(14, height / 2)
                color: page.theme.faint
                border.width: 1
                border.color: input.activeFocus ? (page.over > 0 ? page.theme.danger : page.theme.control) : "transparent"
                IslandFlickable {
                    id: inputView
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    contentHeight: input.implicitHeight
                    function follow(r: rect): void {
                        if (r.y < contentY) contentY = r.y;
                        else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height;
                    }
                    TextEdit {
                        id: input
                        objectName: "question"
                        width: inputView.width
                        height: Math.max(implicitHeight, inputView.height)
                        wrapMode: TextEdit.Wrap
                        // text only: nothing but characters is ever taken
                        textFormat: TextEdit.PlainText
                        color: page.theme.text
                        selectionColor: page.theme.control
                        font.pointSize: page.theme.fontSmall
                        selectByMouse: true
                        text: page.ai.draft
                        onTextChanged: if (page.ai.draft !== text) page.ai.draft = text
                        onCursorRectangleChanged: inputView.follow(cursorRectangle)
                        Keys.onEscapePressed: page.release()
                        Keys.onPressed: event => {
                            // Enter sends; Shift+Enter is a new line
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                event.accepted = true;
                                if (!page.ai.busy) page.submit();
                            }
                        }
                    }
                }
                Text {
                    anchors.fill: inputView
                    visible: input.length === 0
                    text: Lang.i18n("Ask something…")
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall
                    elide: Text.ElideRight
                }
                // The first click asks the island for the keyboard.
                MouseArea { anchors.fill: parent; visible: !page.typing; cursorShape: Qt.IBeamCursor; onClicked: page.focusInput() }
            }
            IconButton {
                objectName: "sendOrStop"
                Layout.alignment: Qt.AlignBottom
                iconName: page.ai.busy ? "media-playback-stop-symbolic" : "document-send-symbolic"
                iconSize: 14
                implicitWidth: 28; implicitHeight: 28
                enabled: page.ai.busy || (input.text.trim().length > 0 && page.over <= 0)
                color: page.theme.text
                hoverColor: page.theme.faint
                onClicked: { if (page.ai.busy) page.ai.stop(); else page.submit(); }
            }
        }
    }

    // ---- the notice of a source, once ------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 30
        visible: page.view === "notice"
        spacing: 6
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: page.current !== null ? page.whereIcon(page.ai.whereOf(page.current)) : ""
            color: page.theme.subText
            isMask: true
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Lang.i18n("Before the first question")
            color: page.theme.text
            font.pointSize: page.theme.fontSmall
            font.weight: Font.DemiBold
        }
        Text {
            objectName: "noticeText"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: page.view === "notice" && page.current !== null ? page.ai.noticeText(page.current) : ""
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.9
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            PillButton {
                objectName: "noticeContinue"
                theme: page.theme
                primary: true
                text: Lang.i18n("Continue")
                onClicked: page.accept()
            }
            PillButton {
                theme: page.theme
                text: Lang.i18n("Cancel")
                onClicked: { page.waitingText = ""; page.retrying = false; page.view = "chat"; }
            }
        }
    }

    // ---- a link an answer contains ---------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 30
        visible: page.view === "link"
        spacing: 6
        readonly property string web: Markdown.webLink(page.link)
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: parent.web.length > 0 ? Lang.i18n("Open this address in the browser?") : Lang.i18n("This is not a web address; it is not opened from here.")
            color: page.theme.text
            font.pointSize: page.theme.fontSmall
            font.weight: Font.DemiBold
        }
        Text {
            objectName: "linkAddress"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 4
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: page.link
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall * 0.9
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            PillButton {
                objectName: "linkOpen"
                visible: parent.parent.web.length > 0
                theme: page.theme
                primary: true
                text: Lang.i18n("Open")
                onClicked: { Qt.openUrlExternally(parent.parent.web); page.view = page.viewBeforeLink; }
            }
            PillButton {
                theme: page.theme
                text: Lang.i18n("Copy address")
                onClicked: { page.copy(page.link); page.view = page.viewBeforeLink; }
            }
            PillButton {
                theme: page.theme
                text: Lang.i18n("Cancel")
                onClicked: page.view = page.viewBeforeLink
            }
        }
    }

    // ---- nothing connected: what is on this computer, and "add another" -------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "cards"
        spacing: 6
        Text {
            Layout.fillWidth: true
            text: page.status.length > 0 ? page.status
                : !page.detected ? Lang.i18n("Looking for what can answer on this computer…")
                : Lang.i18n("For quick questions. Connect what is to answer:")
            color: page.status.length > 0 && page.statusIsError ? page.theme.readable(page.theme.warning, page.theme.surface) : page.theme.text
            font.pointSize: page.theme.fontSmall
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Loader { Layout.fillWidth: true; Layout.fillHeight: true; active: parent.visible; sourceComponent: cards }
    }
    Component {
        id: cards
        RowLayout {
            spacing: 6
            Repeater {
                // what is looked for by itself and not connected yet (a quiet kind only once it was found), then "add another"
                model: page.ai.catalog.order.filter(k => page.info(k).probe === true && !page.ai.sources.some(s => s.kind === k)
                                                         && (page.info(k).quiet !== true || page.here(k, page.found[k] || {}))).concat(["+"])
                delegate: Rectangle {
                    id: card
                    required property string modelData
                    readonly property bool more: modelData === "+"
                    readonly property var state: page.found[modelData] || ({})
                    readonly property bool here: !more && page.here(modelData, state)
                    objectName: "card-" + modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: 14
                    opacity: page.connecting ? 0.5 : 1
                    color: cardMouse.pressed ? page.theme.pressedFill
                         : cardMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                         : page.theme.faint
                    Behavior on color { ColorAnimation { duration: 120 } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 3
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            source: card.more ? "list-add-symbolic" : page.whereIcon(page.info(card.modelData).where)
                            color: page.theme.text
                            isMask: true
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: card.more ? Lang.i18n("Add another") : page.info(card.modelData).name
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: card.more ? Lang.i18n("A key, or a model server of your own")
                                : page.info(card.modelData).where === "cli" ? (card.here ? Lang.i18n("Found · no key needed") : card.state.helper === false ? Lang.i18n("Needs the island's helper")
                                                                      : page.detected ? Lang.i18n("Not found · Install") : Lang.i18n("Already signed in, no key"))
                                : card.here ? Lang.i18n("On this device, no account")
                                : card.state.installed === true ? Lang.i18n("Not running · Start it")
                                : page.detected ? Lang.i18n("Not found · Install") : Lang.i18n("On this device")
                            color: card.here ? page.theme.readable(page.theme.live, page.theme.surface) : page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.85
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (card.more) page.view = "kinds"; else page.pickCard(card.modelData); }
                    }
                }
            }
        }
    }

    // ---- add another: the kinds that need a key or an address -----------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "kinds"
        spacing: 4
        Heading {
            Layout.fillWidth: true
            title: Lang.i18n("Add another")
            onBack: page.view = page.ai.available ? "sources" : "cards"
        }
        IslandListView {
            objectName: "kindList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            model: page.view === "kinds" ? page.ai.catalog.order.filter(k => page.info(k).probe !== true) : []
            delegate: Rectangle {
                id: kindRow
                required property string modelData
                readonly property var kind: page.info(modelData)
                width: ListView.view.width
                height: 30
                radius: 10
                color: kindMouse.pressed ? page.theme.pressedFill
                     : kindMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface)) : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 8
                    spacing: 8
                    Kirigami.Icon {
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        source: page.whereIcon(kindRow.kind.where)
                        color: page.theme.subText
                        isMask: true
                    }
                    Text {
                        text: kindRow.kind.name
                        color: page.theme.text
                        font.pointSize: page.theme.fontSmall
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: kindRow.kind.key === true ? Lang.i18n("A key · may cost money") : Lang.i18n("On this device, no account")
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.85
                        elide: Text.ElideRight
                    }
                }
                MouseArea { id: kindMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.showForm(kindRow.modelData) }
            }
        }
    }

    // ---- connect form: an address, a key ------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "form"
        spacing: 5
        readonly property var kind: page.formKind.length > 0 ? page.info(page.formKind) : null
        Heading {
            Layout.fillWidth: true
            title: parent.kind !== null ? parent.kind.name : ""
            icon: parent.kind !== null ? page.whereIcon(parent.kind.where) : ""
            onBack: { page.typing = false; page.view = "kinds"; }
        }
        IslandFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: formInfo.implicitHeight
            ColumnLayout {
                id: formInfo
                width: parent.width
                spacing: 4
                readonly property var kind: page.formKind.length > 0 ? page.info(page.formKind) : null
                Text {
                    objectName: "formError"
                    Layout.fillWidth: true
                    visible: page.formError.length > 0
                    wrapMode: Text.Wrap
                    text: page.formError
                    color: page.theme.readable(page.theme.danger, page.theme.surface)
                    font.pointSize: page.theme.fontSmall * 0.9
                }
                // where what is written will go, when that is not this computer
                Text {
                    objectName: "farNote"
                    Layout.fillWidth: true
                    visible: page.far
                    wrapMode: Text.Wrap
                    text: page.far ? Lang.i18n("What you write will be sent to %1.", page.typedAddress.host)
                                     + (page.typedAddress.scheme === "http" ? " " + Lang.i18n("The connection is not encrypted.") : "") : ""
                    color: page.theme.readable(page.theme.warning, page.theme.surface)
                    font.pointSize: page.theme.fontSmall * 0.9
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: formInfo.kind === null ? ""
                        : formInfo.kind.key !== true ? Lang.i18n("The address of the model server, up to and including its version part. No account and no key: on this computer nothing leaves the device.") + "\n" + String(formInfo.kind.examples || "")
                        : formInfo.kind.needsServer === true ? Lang.i18n("The address of the service, up to and including its version part (for example https://example.org/v1), and its key. The key is kept in KDE Wallet and nowhere else. Using a service may cost money.")
                        : Lang.i18n("1. Make a key at the address below.\n2. Paste it here and press Connect.\nThe key is kept in KDE Wallet and nowhere else. Using this service may cost money.")
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall * 0.9
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: formInfo.kind !== null && String(formInfo.kind.keyUrl || "").length > 0
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: formInfo.kind !== null ? String(formInfo.kind.keyUrl || "") : ""
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.85
                        elide: Text.ElideMiddle
                    }
                    PillButton {
                        theme: page.theme
                        implicitHeight: 20
                        text: Lang.i18n("Open the page")
                        onClicked: page.askLink(formInfo.kind.keyUrl)
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            PillField {
                id: serverField
                objectName: "serverField"
                visible: parent.parent.kind !== null && parent.parent.kind.needsServer === true
                theme: page.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                placeholder: Lang.i18n("Address (http://…)")
                enabled: !page.connecting
                onEdited: { page.formError = ""; page.farAccepted = false; }
                onAccepted: { if (keyField.visible) keyField.input.forceActiveFocus(); else page.submitForm(); }
                onEscaped: { page.typing = false; page.view = "kinds"; }
            }
            PillField {
                id: keyField
                objectName: "keyField"
                visible: parent.parent.kind !== null && parent.parent.kind.key === true
                theme: page.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                secret: true
                placeholder: Lang.i18n("Key")
                enabled: !page.connecting
                onEdited: page.formError = ""
                onAccepted: page.submitForm()
                onEscaped: { page.typing = false; page.view = "kinds"; }
            }
            PillButton {
                objectName: "formConnect"
                theme: page.theme
                primary: true
                enabled: !page.connecting
                text: page.connecting ? Lang.i18n("Connecting…") : page.far && page.farAccepted ? Lang.i18n("Connect anyway") : Lang.i18n("Connect")
                onClicked: page.submitForm()
            }
        }
    }

    // ---- not installed, or not running: how to get it (never run from here) ---------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "install"
        spacing: 5
        readonly property var kind: page.helpKind.length > 0 ? page.info(page.helpKind) : null
        readonly property var state: page.found[page.helpKind] || ({})
        // "helper" (the native module is missing) | "start" (installed, not running) | "install"
        readonly property string need: page.helpKind === "claude-cli" ? (state.helper === false ? "helper" : "install") : state.installed === true ? "start" : "install"
        Heading {
            Layout.fillWidth: true
            icon: parent.kind !== null ? page.whereIcon(parent.kind.where) : ""
            title: parent.kind === null ? "" : parent.need === "start" ? Lang.i18n("%1 is not running", parent.kind.name)
                 : parent.need === "helper" ? Lang.i18n("The island's helper is missing") : Lang.i18n("%1 was not found", parent.kind.name)
            onBack: page.view = page.ai.available ? "sources" : "cards"
        }
        Text {
            objectName: "installText"
            Layout.fillWidth: true
            Layout.fillHeight: true
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            text: parent.kind === null ? ""
                : parent.need === "helper" ? Lang.i18n("Claude Code is asked through the island's native helper, which is not installed. Run the widget's install.sh again, then restart the shell.")
                : parent.need === "start" ? Lang.i18n("It is installed but does not answer. Start it yourself, in your own terminal, then come back.")
                : page.helpKind === "claude-cli" ? Lang.i18n("Claude Code is not on this computer. To install it, run this command in your own terminal and sign in there; then come back.")
                : Lang.i18n("It runs models on this computer: no account, and nothing leaves the device. To install it, run this command in your own terminal and get a model; then come back.")
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.9
        }
        CommandLine {
            Layout.fillWidth: true
            command: parent.kind === null ? "" : parent.need === "helper" ? "./install.sh" : parent.need === "start" ? String(parent.kind.start || "") : String(parent.kind.install || "")
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PillButton {
                theme: page.theme
                text: Lang.i18n("Check again")
                onClicked: page.ai.detect(result => {
                    page.found = result; page.detected = true;
                    const state = result[page.helpKind] || {};
                    if (page.here(page.helpKind, state)) page.pickCard(page.helpKind);
                })
            }
        }
    }

    // ---- the models of the source ----------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "models"
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Heading {
                Layout.fillWidth: true
                title: page.current !== null ? Lang.i18n("Model of %1", page.current.name) : ""
                onBack: { page.typing = false; page.view = "chat"; }
            }
            PillButton {
                theme: page.theme
                implicitHeight: 20
                enabled: !page.modelBusy
                text: page.modelBusy ? Lang.i18n("Asking…") : Lang.i18n("Ask again")
                onClicked: page.loadModels(true)
            }
        }
        PillField {
            id: modelField
            objectName: "modelField"
            theme: page.theme
            Layout.fillWidth: true
            implicitHeight: 24
            placeholder: Lang.i18n("Search, or type a model's name…")
            onEdited: page.modelFilter = text
            onAccepted: { const name = text.trim(); if (page.shownModels.length === 1) page.chooseModel(page.shownModels[0].id); else if (name.length > 0) page.chooseModel(name); }
            onEscaped: { page.typing = false; page.view = "chat"; }
            MouseArea { anchors.fill: parent; visible: !page.typing; cursorShape: Qt.IBeamCursor; onClicked: page.focusLater(modelField.input) }
        }
        Text {
            Layout.fillWidth: true
            visible: page.modelError.length > 0
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            text: page.modelError
            color: page.theme.readable(page.theme.warning, page.theme.surface)
            font.pointSize: page.theme.fontSmall * 0.9
        }
        IslandListView {
            id: modelView
            objectName: "modelList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            // a name typed by hand that the list does not have can be taken as it is
            readonly property string typed: page.modelFilter.trim()
            readonly property bool own: typed.length > 0 && !page.modelList.some(m => m.id === typed)
            model: page.view === "models" ? (own ? [{ id: typed, name: Lang.i18n("Use “%1”", typed), own: true }] : []).concat(page.shownModels) : []
            delegate: Rectangle {
                id: modelRow
                required property var modelData
                readonly property bool chosen: page.current !== null && page.current.model === modelData.id && modelData.own !== true
                width: ListView.view.width
                height: 26
                radius: 9
                color: modelMouse.pressed ? page.theme.pressedFill
                     : modelMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                     : chosen ? page.theme.faint : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: modelRow.modelData.name
                        color: page.theme.text
                        font.pointSize: page.theme.fontSmall
                        font.weight: modelRow.chosen ? Font.DemiBold : Font.Normal
                        elide: Text.ElideMiddle
                    }
                    Text {
                        visible: modelRow.modelData.own !== true && modelRow.modelData.name !== modelRow.modelData.id && modelRow.modelData.id.length > 0
                        text: modelRow.modelData.id
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.85
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 150
                    }
                    Kirigami.Icon {
                        visible: modelRow.chosen
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        source: "checkmark-symbolic"
                        color: page.theme.text
                        isMask: true
                    }
                }
                MouseArea { id: modelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.chooseModel(modelRow.modelData.id) }
            }
        }
    }

    // ---- connected sources + add ------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "sources"
        spacing: 4
        Heading {
            Layout.fillWidth: true
            title: page.status.length > 0 ? page.status : Lang.i18n("What answers")
            onBack: page.view = page.ai.available ? "chat" : "cards"
        }
        IslandFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: sourceColumn.implicitHeight
            ColumnLayout {
                id: sourceColumn
                width: parent.width
                spacing: 3
                Repeater {
                    model: page.view === "sources" ? page.ai.sources : []
                    delegate: RowLayout {
                        id: sourceRow
                        required property var modelData
                        readonly property bool inUse: page.current !== null && page.current.id === modelData.id
                        readonly property bool isDefault: (page.ai.source(page.ai.defaultId) || page.ai.sources[0]).id === modelData.id
                        Layout.fillWidth: true
                        spacing: 5
                        Kirigami.Icon {
                            Layout.preferredWidth: 13
                            Layout.preferredHeight: 13
                            source: page.whereIcon(page.ai.whereOf(sourceRow.modelData))
                            color: page.theme.subText
                            isMask: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.ai.label(sourceRow.modelData)
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            font.weight: sourceRow.inUse ? Font.DemiBold : Font.Normal
                            elide: Text.ElideMiddle
                        }
                        PillButton {
                            theme: page.theme
                            implicitHeight: 20
                            primary: sourceRow.inUse
                            text: sourceRow.inUse ? Lang.i18n("In use") : Lang.i18n("Use")
                            onClicked: { page.ai.chosenId = sourceRow.modelData.id; page.view = "chat"; }
                        }
                        PillButton {
                            theme: page.theme
                            implicitHeight: 20
                            visible: !sourceRow.isDefault
                            text: Lang.i18n("Make default")
                            onClicked: page.defaultPicked(sourceRow.modelData.id)
                        }
                        PillButton {
                            theme: page.theme
                            implicitHeight: 20
                            text: Lang.i18n("Disconnect")
                            onClicked: page.ai.disconnect(sourceRow.modelData.id)
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    text: Lang.i18n("Connect another:")
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                }
                Loader { Layout.fillWidth: true; Layout.preferredHeight: 66; active: page.view === "sources"; sourceComponent: cards }
            }
        }
    }
}
