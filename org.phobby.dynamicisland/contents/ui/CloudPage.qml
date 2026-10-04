/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Cloud": the clouds of this computer in one place. On top the clouds
    (each with its sync state and how full it is), under them where one is
    (Cloud > Folder > Subfolder), a search over the open folder and the
    order, then the folder itself: names, sizes, dates. Nothing of a file is
    read or previewed; a name is shown as plain text.

    Out of the cloud: a file is fetched into the island's cache and can then
    be dragged to the desktop or a file manager; a small one is fetched when
    the pointer rests on it, a large one when asked. A click on a file shows
    what else can be done: Download (to the Downloads folder, never over a
    file that is there), Show in folder, Copy path. A folder is measured
    before it is downloaded.

    Into the cloud: files dropped on the list (or chosen with "Upload…") are
    copied into the open folder, after a question that says how much goes
    where; what is there already is only written over when that is chosen.

    Nothing can be deleted, moved or renamed here. A command that installs
    rclone or renews a sign-in is only ever shown to be copied.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "cloud/Rclone.js" as Rclone

Item {
    id: page

    required property Theme theme
    required property var cloud             // CloudBackend

    // "browse" | "missing" (no rclone) | "empty" (no remote) | "upload" (the question before one)
    // | "folder" (before a folder is downloaded) | "file" (what can be done with one) | "syncthing" (its key)
    property string view: "browse"
    property bool typing: false
    readonly property bool interacting: visible && typing
    readonly property bool holdOpen: visible && (dropping || view === "upload" || picking)
    readonly property bool keepsWheel: visible && view === "browse" && shown.length > 0
    readonly property bool tall: visible && view !== "missing" && view !== "empty"

    Binding { target: page.cloud; property: "viewing"; value: page.visible; restoreMode: Binding.RestoreNone }
    Component.onDestruction: cloud.viewing = false
    onVisibleChanged: if (visible) arrive(); else typing = false
    Component.onCompleted: arrive()

    // ---- where one is ----------------------------------------------------------------
    property string current: ""             // the cloud's id
    property string path: ""
    property var entries: []
    property bool more: false
    property bool loading: false
    property var trouble: null              // { kind, detail } of the last listing
    property string query: ""
    property string order: "name"           // "name" | "date" | "size"
    property bool descending: false
    readonly property var shown: Rclone.sorted(Rclone.filtered(entries, query), order, descending)
    readonly property var here: cloud.cloud(current)
    readonly property var crumbs: path.length > 0 ? path.split("/") : []
    property int asked: 0
    // name ↑ ↓, date ↓ ↑ (newest first), size ↓ ↑ (largest first), and round again
    function nextOrder(): void {
        const first = order === "name" ? false : true;
        if (descending === first) { descending = !first; return; }
        order = order === "name" ? "date" : order === "date" ? "size" : "name";
        descending = order !== "name";
    }

    function arrive(): void {
        if (!visible) return;
        if (!cloud.looked) { cloud.detect(settle); return; }
        settle();
    }
    function settle(): void {
        if (cloud.command.length === 0) { view = "missing"; return; }
        if (cloud.clouds.length === 0) { view = "empty"; return; }
        if (view === "missing" || view === "empty") view = "browse";
        if (cloud.cloud(current) === null) {
            // where the last upload went, else the first cloud
            const last = /^([^:]+):(.*)$/.exec(cloud.lastTarget);
            if (last !== null && cloud.cloud(last[1]) !== null) open(last[1], last[2], false); else open(cloud.clouds[0].id, "", false);
        } else if (entries.length === 0 && !loading && trouble === null) open(current, path, false);
    }
    function open(id: string, where: string, fresh: bool): void {
        const mine = ++asked;
        current = id; path = Rclone.cleanPath(where);
        query = ""; searchField.text = "";
        loading = true; trouble = null;
        if (view !== "upload") view = "browse";
        cloud.list(id, path, fresh, result => {
            if (mine !== asked) return;
            loading = false;
            entries = result.ok ? result.entries : [];
            more = result.ok && result.more;
            trouble = result.ok ? null : result.problem;
        });
    }
    function up(levels: int): void { open(current, crumbs.slice(0, crumbs.length - levels).join("/"), false); }
    Connections {
        target: page.cloud
        function onUploaded(id, where) { if (id === page.current && where === page.path) page.open(id, where, true); }
        function onCloudsChanged() { if (page.visible && page.cloud.looked) page.settle(); }
    }

    function when(t: real): string {
        if (!(t > 0)) return "";
        const d = new Date(t), now = new Date();
        return d.toDateString() === now.toDateString() ? Qt.formatTime(d, Lang.locale.timeFormat(Locale.ShortFormat))
             : d.toLocaleDateString(Lang.locale, d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy");
    }
    property string status: ""
    function say(text: string): void { status = text; statusTimer.restart(); }
    Timer { id: statusTimer; interval: 5000; onTriggered: page.status = "" }
    TextEdit { id: clip; visible: false; textFormat: TextEdit.PlainText }
    function copy(text: string): void { clip.text = text; clip.selectAll(); clip.copy(); clip.text = ""; }

    // ---- a file ------------------------------------------------------------------------
    property var chosen: null               // the entry of the "file" and "folder" views
    property string saved: ""               // where "Download" put it
    property var measured: null             // { count, bytes } of a folder
    function key(entry: var): string { return Rclone.target(current, Rclone.join(path, entry.name)); }
    function choose(entry: var): void {
        if (entry.dir) { open(current, Rclone.join(path, entry.name), false); return; }
        chosen = entry; saved = "";
        view = "file";
    }
    function download(entry: var): void {
        cloud.download(current, Rclone.join(path, entry.name), entry, local => {
            if (local.length > 0) { page.saved = local; page.say(Lang.i18n("Saved to %1", Rclone.baseName(page.cloud.downloadsFolder))); }
        });
    }
    function askFolder(entry: var): void {
        chosen = entry; measured = null; saved = "";
        view = "folder";
        cloud.measure(current, Rclone.join(path, entry.name), result => { if (page.chosen === entry) page.measured = result.ok ? { count: result.count, bytes: result.bytes } : { count: -1, bytes: -1 }; });
    }
    function showInFolder(local: string): void {
        if (cloud.core !== null) cloud.core.call(false, "org.freedesktop.FileManager1", "/org/freedesktop/FileManager1", "org.freedesktop.FileManager1", "ShowItems", [[Rclone.fileUrl(local)], ""], null);
    }
    // The pointer rests on a small file: fetched quietly, so that it can be dragged.
    function rest(entry: var): void {
        if (entry.dir || !(entry.size >= 0) || entry.size > cloud.autoFetchMB * 1048576) return;
        cloud.fetch(current, Rclone.join(path, entry.name), entry, true, null);
    }

    // ---- into the cloud ------------------------------------------------------------------
    property bool dropping: false
    property bool picking: false
    property var planned: null              // { items, bytes, count, big }
    readonly property int clashes: planned !== null ? planned.items.filter(i => i.exists).length : 0
    function dropped(urls: var): void {
        if (here === null || urls.length === 0) return;
        const id = current, where = path;
        cloud.plan(urls.map(String), id, where, plan => {
            if (plan.items.length === 0) { page.say(Lang.i18n("Only files of this computer can be uploaded.")); return; }
            if (!page.cloud.confirmUpload && !plan.big && plan.items.every(i => !i.exists)) { page.cloud.upload(plan.items, id, where, "skip"); return; }
            page.planned = plan;
            page.view = "upload";
        });
    }
    function send(choice: string): void {
        cloud.upload(planned.items, current, path, choice);
        planned = null;
        view = "browse";
    }
    Loader {
        id: picker
        active: false
        source: "CloudFilePicker.qml"
        onLoaded: item.open()
        Connections {
            target: picker.item
            function onPicked(urls) { page.picking = false; picker.active = false; page.dropped(urls); }
            function onCancelled() { page.picking = false; picker.active = false; }
        }
    }

    // =====================================================================================
    component Dot: Rectangle {
        property string state
        width: 6; height: 6; radius: 3
        color: state === "synced" ? page.theme.live : state === "syncing" ? page.theme.blue : state === "error" ? page.theme.red
             : state === "paused" || state === "offline" ? page.theme.orange : page.theme.track
    }
    component Heading: RowLayout {
        id: heading
        property string title
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
        Text {
            Layout.fillWidth: true
            text: heading.title
            textFormat: Text.PlainText
            color: page.theme.text
            font.pointSize: page.theme.fontSmall
            font.weight: Font.DemiBold
            elide: Text.ElideMiddle
        }
    }
    component CommandLine: RowLayout {
        id: line
        property string command
        spacing: 6
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 13
            color: page.theme.faint
            clip: true
            Text {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
                text: line.command
                color: page.theme.text
                font.family: "monospace"
                font.pointSize: page.theme.fontSmall * 0.85
                elide: Text.ElideRight
            }
        }
        PillButton {
            theme: page.theme
            primary: true
            implicitHeight: 24
            text: lineCopied.running ? Lang.i18n("Copied") : Lang.i18n("Copy")
            onClicked: { page.copy(line.command); lineCopied.restart(); }
            Timer { id: lineCopied; interval: 2000 }
        }
    }

    // ---- rclone is not there, or has no cloud yet ------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "missing" || page.view === "empty"
        spacing: 5
        Text {
            Layout.fillWidth: true
            text: page.view === "missing" ? Lang.i18n("rclone was not found") : Lang.i18n("No cloud is set up yet")
            color: page.theme.text
            font.pointSize: page.theme.fontSmall
            font.weight: Font.DemiBold
        }
        Text {
            objectName: "setupText"
            Layout.fillWidth: true
            Layout.fillHeight: true
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            text: page.view === "missing"
                ? Lang.i18n("The clouds are reached through rclone, a free program for Google Drive, OneDrive, Dropbox, Nextcloud and many more. To install it, run this command in your own terminal, then come back.")
                : Lang.i18n("rclone is here but knows no cloud. Add one in your own terminal: the command asks which cloud it is and lets you sign in in the browser. Then come back.")
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.9
        }
        CommandLine {
            Layout.fillWidth: true
            command: page.view === "missing" ? "sudo -v ; curl https://rclone.org/install.sh | sudo bash" : "rclone config"
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PillButton { theme: page.theme; implicitHeight: 22; text: Lang.i18n("Check again"); onClicked: page.cloud.detect(page.settle) }
        }
    }

    // ---- the folder --------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "browse"
        spacing: 3

        // the clouds
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Flickable {
                Layout.fillWidth: true
                implicitHeight: 22
                clip: true
                contentWidth: chips.implicitWidth
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: chips
                    spacing: 4
                    Repeater {
                        model: page.cloud.clouds
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool mine: modelData.id === page.current
                            readonly property var sync: page.cloud.syncOf(modelData.id)
                            objectName: "cloud-" + modelData.id
                            width: chipRow.implicitWidth + 16
                            height: 22
                            radius: 11
                            color: mine ? page.theme.faint : chipMouse.containsMouse ? page.theme.hoverFill : "transparent"
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 5
                                Dot { anchors.verticalCenter: parent.verticalCenter; state: chip.sync.state }
                                Text {
                                    text: chip.modelData.name
                                    textFormat: Text.PlainText
                                    color: chip.mine ? page.theme.text : page.theme.subText
                                    font.pointSize: page.theme.fontSmall * 0.9
                                    font.weight: Font.DemiBold
                                }
                                // nearly full, or full
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property string level: page.cloud.level(chip.modelData.id)
                                    visible: level === "warning" || level === "critical"
                                    width: 6; height: 6; radius: 3
                                    color: level === "critical" ? page.theme.red : page.theme.orange
                                }
                            }
                            MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.open(chip.modelData.id, "", false) }
                        }
                    }
                    // Syncthing: its state, nothing to browse
                    Rectangle {
                        objectName: "syncthingChip"
                        visible: page.cloud.syncthingFound
                        readonly property var sync: page.cloud.sync["Syncthing"] || ({ state: "unknown", progress: -1, problem: "" })
                        width: stRow.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: stMouse.containsMouse ? page.theme.hoverFill : "transparent"
                        Row {
                            id: stRow
                            anchors.centerIn: parent
                            spacing: 5
                            Dot { anchors.verticalCenter: parent.verticalCenter; state: parent.parent.sync.state }
                            Text {
                                text: "Syncthing · " + (parent.parent.sync.problem === "key" ? Lang.i18n("its key is needed") : page.cloud.stateText(parent.parent.sync.state)
                                      + (parent.parent.sync.progress >= 0 && parent.parent.sync.state === "syncing" ? " " + Lang.percent(Math.round(parent.parent.sync.progress * 100)) : ""))
                                color: page.theme.subText
                                font.pointSize: page.theme.fontSmall * 0.9
                            }
                        }
                        MouseArea { id: stMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { page.view = "syncthing"; page.typing = true; Qt.callLater(page.focusKey); } }
                    }
                }
            }
            IconButton {
                objectName: "refresh"
                iconName: "view-refresh-symbolic"
                iconSize: 12
                implicitWidth: 22; implicitHeight: 22
                color: page.theme.subText
                hoverColor: page.theme.faint
                enabled: !page.loading
                onClicked: { page.cloud.refreshStorage(); page.open(page.current, page.path, true); }
            }
        }

        // where one is, and how full the cloud is
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Flickable {
                Layout.fillWidth: true
                implicitHeight: 18
                clip: true
                contentWidth: crumbRow.implicitWidth
                contentX: Math.max(0, contentWidth - width)
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: crumbRow
                    spacing: 2
                    Repeater {
                        model: [page.here !== null ? page.here.name : ""].concat(page.crumbs)
                        delegate: Row {
                            id: crumb
                            required property string modelData
                            required property int index
                            spacing: 2
                            Text { visible: crumb.index > 0; text: "›"; color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.9 }
                            Text {
                                text: Rclone.display(crumb.modelData).slice(0, 28)
                                textFormat: Text.PlainText
                                color: crumb.index === page.crumbs.length ? page.theme.text : page.theme.subText
                                font.pointSize: page.theme.fontSmall * 0.9
                                font.weight: crumb.index === page.crumbs.length ? Font.DemiBold : Font.Normal
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.up(page.crumbs.length - crumb.index) }
                            }
                        }
                    }
                }
            }
            // used / total, where the cloud says it
            Rectangle {
                id: bar
                readonly property var about: page.cloud.abouts[page.current] || null
                readonly property real full: Rclone.fullness(about)
                visible: full >= 0
                Layout.preferredWidth: 46
                Layout.preferredHeight: 4
                radius: 2
                color: page.theme.track
                Rectangle {
                    width: parent.width * Math.max(0, bar.full) / 100
                    height: parent.height
                    radius: 2
                    color: page.cloud.level(page.current) === "critical" ? page.theme.red : page.cloud.level(page.current) === "warning" ? page.theme.orange : page.theme.subText
                }
            }
            Text {
                objectName: "storageText"
                visible: bar.about !== null && bar.about !== undefined
                text: !visible ? "" : bar.full >= 0 ? Lang.i18n("%1 of %2", page.cloud.size(bar.about.used), page.cloud.size(bar.about.total)) : Lang.i18n("%1 used", page.cloud.size(bar.about.used))
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.8
            }
        }

        // search in this folder, the order, upload
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            PillField {
                id: searchField
                objectName: "search"
                theme: page.theme
                Layout.fillWidth: true
                implicitHeight: 22
                placeholder: Lang.i18n("Search this folder…")
                onEdited: page.query = text
                onEscaped: { page.typing = false; text = ""; page.query = ""; }
                MouseArea { anchors.fill: parent; visible: !page.typing; cursorShape: Qt.IBeamCursor; onClicked: { page.typing = true; Qt.callLater(page.focusSearch); } }
            }
            PillButton {
                objectName: "order"
                theme: page.theme
                implicitHeight: 22
                text: (page.order === "name" ? Lang.i18n("Name") : page.order === "date" ? Lang.i18n("Date") : Lang.i18n("Size")) + (page.descending ? " ↓" : " ↑")
                onClicked: page.nextOrder()
            }
            PillButton {
                objectName: "uploadButton"
                theme: page.theme
                implicitHeight: 22
                enabled: page.here !== null && page.trouble === null
                text: Lang.i18n("Upload…")
                onClicked: { page.picking = true; picker.active = true; }
            }
        }

        // what the listing could not do; a sign-in that ran out comes with the command that renews it
        ColumnLayout {
            Layout.fillWidth: true
            visible: page.trouble !== null
            spacing: 3
            Text {
                objectName: "trouble"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: page.trouble !== null && page.here !== null ? page.cloud.problemText(page.trouble, page.here.name) : ""
                color: page.theme.readable(page.theme.warning, page.theme.surface)
                font.pointSize: page.theme.fontSmall * 0.9
            }
            CommandLine {
                Layout.fillWidth: true
                visible: page.trouble !== null && page.trouble.kind === "auth"
                command: page.cloud.reconnectCommand(page.current)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                objectName: "entries"
                anchors.fill: parent
                clip: true
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds
                // only the rows on screen exist
                reuseItems: true
                cacheBuffer: 60
                model: page.shown
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property string key: page.key(modelData)
                    readonly property string local: page.cloud.readyPath(page.current, Rclone.join(page.path, modelData.name), modelData)
                    readonly property bool fetching: page.cloud.fetching[key] !== undefined
                    width: list.width
                    height: 24
                    radius: 8
                    color: rowMouse.pressed ? page.theme.pressedFill : rowMouse.containsMouse ? page.theme.hoverFill : "transparent"

                    // dragged out as a file, once it is here
                    Drag.active: rowMouse.drag.active && row.local.length > 0
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: ({ "text/uri-list": row.local.length > 0 ? Rclone.fileUrl(row.local) + "\r\n" : "" })

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 8
                        spacing: 7
                        Kirigami.Icon {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            source: Rclone.icon(row.modelData)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.shown
                            textFormat: Text.PlainText
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                        }
                        // fetched: can be dragged; being fetched: how far
                        Text {
                            visible: row.fetching || row.local.length > 0
                            text: row.local.length > 0 ? Lang.i18n("drag") : page.cloud.fetching[row.key] >= 0 ? Lang.percent(Math.round(page.cloud.fetching[row.key])) : "…"
                            color: row.local.length > 0 ? page.theme.readable(page.theme.live, page.theme.surface) : page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.8
                        }
                        Text {
                            visible: !row.modelData.dir
                            text: page.cloud.size(row.modelData.size)
                            color: page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.85
                            font.features: { "tnum": 1 }
                        }
                        Text {
                            Layout.preferredWidth: 46
                            horizontalAlignment: Text.AlignRight
                            text: page.when(row.modelData.modified)
                            color: page.theme.subText
                            font.pointSize: page.theme.fontSmall * 0.85
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        drag.target: row.local.length > 0 ? dragGhost : null
                        onContainsMouseChanged: if (containsMouse) restTimer.restart(); else restTimer.stop()
                        onClicked: mouse => { if (mouse.button === Qt.RightButton && row.modelData.dir) page.askFolder(row.modelData); else page.choose(row.modelData); }
                        Timer { id: restTimer; interval: 350; onTriggered: page.rest(row.modelData) }
                    }
                    Item { id: dragGhost }
                }
            }
            Text {
                anchors.centerIn: parent
                width: parent.width
                visible: list.count === 0 && page.trouble === null
                horizontalAlignment: Text.AlignHCenter
                text: page.loading ? Lang.i18n("Asking the cloud…") : page.query.trim().length > 0 ? Lang.i18n("No name matches") : Lang.i18n("This folder is empty")
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall
            }

            // files dragged here go into the open folder
            DropArea {
                id: drop
                objectName: "drop"
                anchors.fill: parent
                enabled: page.here !== null && page.trouble === null
                keys: ["text/uri-list"]
                onEntered: drag => { page.dropping = true; drag.accepted = true; }
                onExited: page.dropping = false
                onDropped: drop => { page.dropping = false; drop.acceptProposedAction(); page.dropped(drop.urls); }
            }
            Rectangle {
                objectName: "dropHint"
                anchors.fill: parent
                visible: page.dropping
                radius: 10
                color: Qt.rgba(page.theme.control.r, page.theme.control.g, page.theme.control.b, 0.18)
                border.width: 1
                border.color: page.theme.control
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                    text: page.here !== null ? Lang.i18n("Upload to %1", page.crumbs.length > 0 ? Rclone.display(page.crumbs[page.crumbs.length - 1]) : page.here.name) : ""
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                }
            }
        }

        // the sync state of this cloud, or why it is not known; a list that was cut
        Text {
            objectName: "note"
            Layout.fillWidth: true
            readonly property var sync: page.here !== null ? page.cloud.syncOf(page.current) : null
            text: page.status.length > 0 ? page.status
                : page.more ? Lang.i18n("There are more items than are shown. Use the search to find a name.")
                : sync === null ? "" : sync.source.length > 0 ? Lang.i18n("%1 (from %2)", page.cloud.stateText(sync.state), sync.source)
                : page.cloud.stateText(sync.state) + ": " + sync.note
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall * 0.8
            elide: Text.ElideRight
        }
    }
    function focusSearch(): void { searchField.input.forceActiveFocus(); }
    function focusKey(): void { keyField.input.forceActiveFocus(); }

    // ---- what can be done with a file ---------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "file"
        spacing: 6
        readonly property string local: page.chosen !== null ? page.cloud.readyPath(page.current, Rclone.join(page.path, page.chosen.name), page.chosen) : ""
        Heading {
            Layout.fillWidth: true
            title: page.chosen !== null ? page.chosen.shown : ""
            onBack: page.view = "browse"
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: page.chosen === null ? "" : page.cloud.size(page.chosen.size) + " · " + page.when(page.chosen.modified) + "\n"
                + (parent.local.length > 0 ? Lang.i18n("It is on this computer now: back in the list it can be dragged to the desktop or a file manager.")
                   : Lang.i18n("To drag it out it is fetched first. Or download it to the Downloads folder."))
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall * 0.9
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            PillButton {
                objectName: "fileDownload"
                theme: page.theme
                primary: true
                text: Lang.i18n("Download")
                onClicked: page.download(page.chosen)
            }
            PillButton {
                objectName: "fileFetch"
                visible: parent.parent.local.length === 0
                theme: page.theme
                enabled: page.chosen !== null && page.cloud.fetching[page.key(page.chosen)] === undefined
                text: enabled ? Lang.i18n("Fetch for dragging") : Lang.i18n("Fetching…")
                onClicked: page.cloud.fetch(page.current, Rclone.join(page.path, page.chosen.name), page.chosen, false, null)
            }
            PillButton {
                objectName: "fileShow"
                visible: page.saved.length > 0
                theme: page.theme
                text: Lang.i18n("Show in folder")
                onClicked: page.showInFolder(page.saved)
            }
            PillButton {
                objectName: "fileCopyPath"
                visible: page.saved.length > 0 || parent.parent.local.length > 0
                theme: page.theme
                text: pathCopied.running ? Lang.i18n("Copied") : Lang.i18n("Copy path")
                onClicked: { page.copy(page.saved.length > 0 ? page.saved : parent.parent.local); pathCopied.restart(); }
                Timer { id: pathCopied; interval: 2000 }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: page.status.length > 0
            text: page.status
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall * 0.9
        }
        Item { Layout.fillHeight: true }
    }

    // ---- a folder: measured before it is downloaded -------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "folder"
        spacing: 6
        readonly property bool known: page.measured !== null && page.measured.count >= 0
        readonly property bool tooMuch: known && (page.measured.bytes > page.cloud.refuseAbove.bytes || page.measured.count > page.cloud.refuseAbove.count)
        readonly property bool much: known && (page.measured.bytes > page.cloud.askAbove.bytes || page.measured.count > page.cloud.askAbove.count)
        Heading {
            Layout.fillWidth: true
            title: page.chosen !== null ? page.chosen.shown : ""
            onBack: page.view = "browse"
        }
        Text {
            objectName: "folderText"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: page.measured === null ? Lang.i18n("Measuring the folder…")
                : !parent.known ? Lang.i18n("The folder could not be measured.")
                : parent.tooMuch ? Lang.i18n("%1 in %2: too much to download from here. Use rclone in a terminal for this.", page.cloud.size(page.measured.bytes), Lang.i18np("%1 file", "%1 files", page.measured.count))
                : Lang.i18n("%1 in %2. Download the whole folder to the Downloads folder?", page.cloud.size(page.measured.bytes), Lang.i18np("%1 file", "%1 files", page.measured.count))
                  + (parent.much ? " " + Lang.i18n("That is a lot.") : "")
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.9
        }
        RowLayout {
            spacing: 6
            PillButton {
                objectName: "folderDownload"
                theme: page.theme
                primary: true
                enabled: parent.parent.known && !parent.parent.tooMuch
                text: Lang.i18n("Download")
                onClicked: { page.download(page.chosen); page.view = "browse"; }
            }
            PillButton { theme: page.theme; text: Lang.i18n("Open"); onClicked: page.choose(page.chosen) }
            PillButton { theme: page.theme; text: Lang.i18n("Cancel"); onClicked: page.view = "browse" }
        }
        Item { Layout.fillHeight: true }
    }

    // ---- before an upload: how much goes where, and what about files that are there ---------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "upload"
        spacing: 6
        Heading {
            Layout.fillWidth: true
            title: Lang.i18n("Upload")
            onBack: { page.planned = null; page.view = "browse"; }
        }
        Text {
            objectName: "uploadText"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: page.planned === null || page.here === null ? ""
                : Lang.i18n("%1, %2 → %3. Upload?", Lang.i18np("%1 item", "%1 items", page.planned.items.length), page.cloud.size(page.planned.bytes),
                            page.here.name + (page.path.length > 0 ? "/" + Rclone.display(page.path) : ""))
                  + (page.planned.big ? "\n" + Lang.i18n("That is a large upload (%1).", Lang.i18np("%1 file", "%1 files", page.planned.count)) : "")
                  + (page.clashes > 0 ? "\n" + Lang.i18np("%1 of them is there already:", "%1 of them are there already:", page.clashes) + " "
                                          + page.planned.items.filter(i => i.exists).slice(0, 3).map(i => Rclone.display(i.name)).join(", ") : "")
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.9
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            PillButton {
                objectName: "uploadGo"
                visible: page.clashes === 0
                theme: page.theme
                primary: true
                text: Lang.i18n("Upload")
                onClicked: page.send("skip")
            }
            PillButton { objectName: "uploadBoth"; visible: page.clashes > 0; theme: page.theme; primary: true; text: Lang.i18n("Keep both"); onClicked: page.send("both") }
            PillButton { objectName: "uploadSkip"; visible: page.clashes > 0; theme: page.theme; text: Lang.i18n("Skip those"); onClicked: page.send("skip") }
            PillButton { objectName: "uploadOver"; visible: page.clashes > 0; theme: page.theme; tint: page.theme.red; text: Lang.i18n("Overwrite"); onClicked: page.send("overwrite") }
            PillButton { theme: page.theme; text: Lang.i18n("Cancel"); onClicked: { page.planned = null; page.view = "browse"; } }
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Lang.i18n("Files are copied; nothing on this computer is changed.")
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall * 0.85
        }
        Item { Layout.fillHeight: true }
    }

    // ---- Syncthing's key ------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "syncthing"
        spacing: 6
        Heading {
            Layout.fillWidth: true
            title: "Syncthing"
            onBack: { page.typing = false; page.view = "browse"; }
        }
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            wrapMode: Text.Wrap
            text: Lang.i18n("Syncthing says how far its sync is through its own interface on this computer, which wants its API key: in Syncthing, Actions → Settings → API Key. The key is kept in KDE Wallet; Syncthing's own files are not read.")
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.9
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            PillField {
                id: keyField
                theme: page.theme
                Layout.fillWidth: true
                secret: true
                placeholder: Lang.i18n("API key")
                onAccepted: { page.cloud.setSyncthingKey(text); text = ""; page.typing = false; page.view = "browse"; }
                onEscaped: { page.typing = false; page.view = "browse"; }
            }
            PillButton {
                theme: page.theme
                primary: true
                text: Lang.i18n("Save")
                onClicked: { page.cloud.setSyncthingKey(keyField.text); keyField.text = ""; page.typing = false; page.view = "browse"; }
            }
        }
    }
}
