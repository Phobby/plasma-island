/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Calendar": a month grid with a dot per calendar on every day that has
    events, next to the events of the selected day (one row per event, in the
    colour of its calendar). Clicking a row shows the details of that event;
    links and places in it open in the browser.
    "+" adds an event through the iCloud account (CalendarEventForm), asking
    for the account first (CalendarAccount). Calendars are connected under the
    gear button (CalendarConnect: the account, or a read-only link).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    property var provider: null            // CalendarProvider
    readonly property var pinned: provider ? provider.pinned : null
    readonly property bool connected: provider !== null && provider.calendar.available
    // Stored calendar links (also the disabled ones), for the duplicate check.
    property var sources: []
    signal sourceAdded(var source)

    property var client: null              // CalDavClient: the iCloud account
    property var google: null              // GoogleCalendar: the Google account
    signal googleClientSaved(string id, string secret)
    // Calendars a new event can go to: [{ key, kind, name, color, ref }]
    readonly property var writeCalendars: {
        const list = [];
        if (client !== null && client.ready) {
            const first = client.defaultCalendar;
            for (const c of client.account.calendars) list[c === first ? "unshift" : "push"]({ key: c.url, kind: "apple", name: c.name, color: c.color, ref: c });
        }
        if (google !== null && google.ready)
            for (const c of google.writableCalendars) list.push({ key: "google:" + c.id, kind: "google", name: c.name, color: c.color, ref: c });
        return list;
    }
    readonly property bool writable: writeCalendars.length > 0
    property string pickedCalendar: ""
    function canDelete(e: var): bool {
        if (!e || e.todo) return false;
        return e.google ? google !== null && google.ready : client !== null && client.ready;
    }

    // What covers the month: "" | "link" (connect wizard) | "account" | "google" | "event"
    property string overlay: ""
    // The account was asked for by "+": go on to the new event afterwards.
    property bool eventAfterAccount: false
    readonly property bool connecting: overlay !== ""
    // Keyboard focus for the island while something is typed.
    readonly property bool interacting: overlay === "link" ? wizard.interacting
                                      : overlay === "google" ? googleLoader.item !== null && googleLoader.item.interacting
                                      : overlay === "account" || overlay === "event"

    function newEvent(): void {
        eventAfterAccount = !writable;
        // Without an account: connect one first (the wizard asks which).
        overlay = writable ? "event" : "link";
    }
    onOverlayChanged: {
        if (overlay === "link") wizard.reset();
        else if (overlay === "account") accountLoader.item.reset();
        else if (overlay === "google") googleLoader.item.reset();
        else if (overlay === "event") eventLoader.item.reset(selectedDay);
    }

    CalendarConnect {
        id: wizard
        anchors.fill: parent
        visible: page.overlay === "link"
        theme: page.theme
        sources: page.sources
        accountAvailable: page.client !== null
        accountUser: page.client !== null && page.client.connected ? page.client.account.user : ""
        googleAvailable: page.google !== null && page.google.core !== null && page.google.core.loopback !== null
        googleUser: page.google !== null && page.google.ready ? page.google.account.user : ""
        onAccountRequested: type => page.overlay = type === "google" ? "google" : "account"
        onAdded: source => { page.overlay = ""; page.sourceAdded(source); }
        onCancelled: page.overlay = ""
    }
    Loader {
        id: accountLoader
        anchors.fill: parent
        active: page.client !== null
        visible: page.overlay === "account"
        sourceComponent: CalendarAccount {
            theme: page.theme
            client: page.client
            onFinished: page.overlay = page.eventAfterAccount ? "event" : ""
            onCancelled: page.overlay = ""
        }
    }
    Loader {
        id: googleLoader
        anchors.fill: parent
        active: page.google !== null
        visible: page.overlay === "google"
        sourceComponent: CalendarGoogle {
            theme: page.theme
            google: page.google
            onFinished: { page.overlay = page.eventAfterAccount ? "event" : ""; if (page.provider) page.provider.calendar.refresh(); }
            onCancelled: page.overlay = ""
            onClientSaved: (id, secret) => page.googleClientSaved(id, secret)
        }
    }
    Loader {
        id: eventLoader
        anchors.fill: parent
        active: page.client !== null || page.google !== null
        visible: page.overlay === "event"
        sourceComponent: CalendarEventForm {
            theme: page.theme
            client: page.client
            google: page.google
            calendars: page.writeCalendars
            preferred: page.pickedCalendar
            onPicked: key => {
                page.pickedCalendar = key;
                const c = page.writeCalendars.find(w => w.key === key);
                if (c && c.kind === "apple") page.client.setDefaultCalendar(c.ref.url);
            }
            onCreated: (result, calendar, day) => {
                // Shown at once (iCloud); the published link follows later.
                if (page.provider) {
                    if (result.text) page.provider.calendar.addEvent(result.uid, result.text, calendar.name, calendar.color);
                    page.provider.calendar.refresh();
                }
                page.overlay = "";
                page.select(day);
            }
            onCancelled: page.overlay = ""
        }
    }

    // Opening the page fetches the calendars right away (not only on the timer).
    function refresh(): void {
        updateView();
        if (visible && provider) provider.calendar.refreshIfStale();
    }
    onVisibleChanged: refresh()
    onProviderChanged: refresh()
    Component.onCompleted: refresh()

    // ---- month ----------------------------------------------------------------
    readonly property real now: provider ? provider.coarseNow : Date.now()
    readonly property real todayStart: dayStart(new Date(now))
    // First day of the month on screen, and the selected day (both local midnight, ms).
    property real monthStart: { const d = new Date(); return new Date(d.getFullYear(), d.getMonth(), 1).getTime(); }
    property real selectedDay: dayStart(new Date())
    // The event whose details are shown instead of the day's list.
    property var detail: null
    onSelectedDayChanged: detail = null
    onDetailChanged: { confirmDelete = false; deleting = false; detailError = ""; }
    property bool confirmDelete: false
    property bool deleting: false
    property string detailError: ""

    function deleteDetail(): void {
        const e = detail;
        if (!e || deleting || !canDelete(e)) return;
        deleting = true; detailError = "";
        const finished = result => {
            deleting = false;
            if (!result.ok) { confirmDelete = false; detailError = result.error; return; }
            if (provider) { provider.calendar.removeEvent(e.uid); provider.calendar.refresh(); }
            if (detail === e) detail = null;
        };
        if (e.google) google.deleteEvent(e.google.calendarId, e.google.eventId, finished); else client.deleteEvent(e.uid, finished);
    }

    // Text for Text.StyledText: escaped, with its web addresses made clickable.
    function escapeHtml(text: string): string {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }
    function linkify(text: string): string {
        return escapeHtml(text).replace(/https?:\/\/[^\s<]+[^\s<.,;:!?)\]]/g, url => '<a href="' + url + '">' + url + "</a>").replace(/\r?\n/g, "<br>");
    }
    // A place opens in the maps site unless it already is a link.
    function placeHtml(place: string): string {
        if (/https?:\/\//i.test(place)) return linkify(place);
        return '<a href="https://www.google.com/maps/search/?api=1&amp;query=' + encodeURIComponent(place) + '">' + escapeHtml(place) + "</a>";
    }

    readonly property int firstWeekDay: Lang.locale.firstDayOfWeek       // 0 = Sunday
    readonly property int leadingDays: (new Date(monthStart).getDay() - firstWeekDay + 7) % 7
    readonly property int weekCount: {
        const d = new Date(monthStart);
        return Math.ceil((leadingDays + new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()) / 7);
    }
    readonly property real gridStart: shiftDays(monthStart, -leadingDays)
    readonly property real gridEnd: shiftDays(gridStart, weekCount * 7)

    function dayStart(d: var): real {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    }
    function shiftDays(t: real, days: int): real {
        const d = new Date(t);
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() + days).getTime();
    }
    function shiftMonth(delta: int): void {
        const d = new Date(monthStart);
        monthStart = new Date(d.getFullYear(), d.getMonth() + delta, 1).getTime();
    }
    function showToday(): void {
        const d = new Date(todayStart);
        monthStart = new Date(d.getFullYear(), d.getMonth(), 1).getTime();
        selectedDay = todayStart;
    }
    function select(day: real): void {
        selectedDay = day;
        const d = new Date(day), m = new Date(monthStart);
        if (d.getMonth() !== m.getMonth() || d.getFullYear() !== m.getFullYear())
            monthStart = new Date(d.getFullYear(), d.getMonth(), 1).getTime();
    }
    // Events touching the day that starts at `from`, in chronological order.
    function eventsOn(from: real): var {
        const to = shiftDays(from, 1);
        return allEvents.filter(e => e.start < to && (e.end > from || e.start >= from));
    }
    readonly property var allEvents: {
        if (!provider || !provider.usable) return [];
        return provider.calendar.rangeEvents.filter(e => provider.showAllDay || !e.allDay);
    }
    readonly property var dayEvents: eventsOn(selectedDay)
    // One entry per cell of the grid: { day (ms), number, inMonth, colors }
    readonly property var cells: {
        const out = [], month = new Date(monthStart).getMonth();
        for (let i = 0; i < weekCount * 7; ++i) {
            const day = shiftDays(gridStart, i), d = new Date(day), colors = [];
            for (const e of eventsOn(day)) if (colors.indexOf(e.color) < 0 && colors.length < 3) colors.push(e.color);
            out.push({ day: day, number: d.getDate(), inMonth: d.getMonth() === month, colors: colors });
        }
        return out;
    }
    function dateRange(e: var): string {
        const locale = Lang.locale;
        const first = new Date(e.start), last = new Date(e.allDay ? Math.max(e.start, e.end - 1) : e.end);
        const sameDay = dayStart(first) === dayStart(last);
        const day = d => d.toLocaleDateString(locale, "d MMMM");
        if (e.allDay) return sameDay ? Lang.i18n("All day") : day(first) + " – " + day(last);
        if (sameDay) return page.provider.timeRange(e);
        return day(first) + " " + page.provider.clock(e.start) + " – " + day(last) + " " + page.provider.clock(e.end);
    }

    // The backend expands the days on screen (no download).
    function updateView(): void {
        if (provider) provider.calendar.setView(gridStart, gridEnd);
    }
    onGridStartChanged: updateView()
    onGridEndChanged: updateView()

    RowLayout {
        anchors.fill: parent
        visible: page.connected && !page.connecting
        spacing: 10

        // Month grid: every day carries a dot per calendar that has an event on it.
        ColumnLayout {
            id: month
            readonly property real cell: Math.floor(Math.min(30, page.width * 0.48 / 7))
            Layout.fillWidth: false
            Layout.preferredWidth: cell * 7
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                spacing: 0
                IconButton {
                    iconName: "go-previous-symbolic"
                    iconSize: 12
                    implicitWidth: 18; implicitHeight: 18
                    color: page.theme.text
                    hoverColor: page.theme.faint
                    onClicked: page.shiftMonth(-1)
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: new Date(page.monthStart).toLocaleDateString(Lang.locale, "MMMM yyyy")
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                    font.capitalization: Font.Capitalize
                    elide: Text.ElideRight
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.showToday() }
                }
                IconButton {
                    iconName: "go-next-symbolic"
                    iconSize: 12
                    implicitWidth: 18; implicitHeight: 18
                    color: page.theme.text
                    hoverColor: page.theme.faint
                    onClicked: page.shiftMonth(1)
                }
            }
            Row {
                Layout.preferredHeight: 12
                Repeater {
                    model: 7
                    delegate: Text {
                        required property int index
                        width: month.cell
                        height: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Lang.locale.dayName((page.firstWeekDay + index) % 7, Locale.ShortFormat)
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.75
                    }
                }
            }
            Grid {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                readonly property real rowHeight: Math.floor(height / page.weekCount)
                Repeater {
                    model: page.cells
                    delegate: Item {
                        id: cell
                        required property var modelData
                        readonly property bool today: modelData.day === page.todayStart
                        readonly property bool selected: modelData.day === page.selectedDay
                        width: month.cell
                        height: grid.rowHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 6
                            color: cell.today ? page.theme.accent
                                 : cell.selected ? page.theme.faint
                                 : cellMouse.containsMouse ? page.theme.hoverFill : "transparent"
                            border.width: cell.today && cell.selected ? 1 : 0
                            border.color: page.theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: Math.max(0, Math.round((parent.height - 5 - implicitHeight) / 2))
                            text: cell.modelData.number
                            color: cell.today ? page.theme.onColor(page.theme.accent) : page.theme.text
                            opacity: cell.modelData.inMonth || cell.today ? 1 : 0.4
                            font.pointSize: page.theme.fontSmall * 0.9
                            font.weight: cell.today || cell.selected ? Font.DemiBold : Font.Normal
                            font.features: { "tnum": 1 }
                        }
                        // Pins: the colours of the calendars with an event on this day
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            spacing: 2
                            opacity: cell.modelData.inMonth || cell.today ? 1 : 0.5
                            Repeater {
                                model: cell.modelData.colors
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 4; height: 4; radius: 2
                                    color: modelData
                                    border.width: cell.today ? 0.5 : 0
                                    border.color: page.theme.onColor(page.theme.accent)
                                }
                            }
                        }
                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.select(cell.modelData.day)
                        }
                    }
                }
            }
        }

        // The selected day: its events, or the details of one of them.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                spacing: 2
                IconButton {
                    visible: page.detail !== null
                    iconName: "go-previous-symbolic"
                    iconSize: 12
                    implicitWidth: 18; implicitHeight: 18
                    color: page.theme.text
                    hoverColor: page.theme.faint
                    onClicked: page.detail = null
                }
                Text {
                    Layout.fillWidth: true
                    text: page.selectedDay === page.todayStart
                        ? Lang.i18nc("@title today's date", "Today · %1", new Date(page.selectedDay).toLocaleDateString(Lang.locale, "d MMMM"))
                        : new Date(page.selectedDay).toLocaleDateString(Lang.locale, "d MMMM, dddd")
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                // New event on the selected day
                IconButton {
                    visible: (page.client !== null || page.google !== null) && page.detail === null
                    iconName: "list-add-symbolic"
                    iconSize: 12
                    implicitWidth: 18; implicitHeight: 18
                    color: page.theme.text
                    hoverColor: page.theme.faint
                    onClicked: page.newEvent()
                }
                // Delete the event shown (asks once more)
                IconButton {
                    visible: page.canDelete(page.detail) && !page.confirmDelete
                    iconName: "edit-delete-symbolic"
                    iconSize: 12
                    implicitWidth: 18; implicitHeight: 18
                    color: page.theme.text
                    hoverColor: page.theme.faint
                    onClicked: page.confirmDelete = true
                }
                PillButton {
                    visible: page.detail !== null && page.confirmDelete
                    theme: page.theme
                    implicitHeight: 18
                    primary: true
                    tint: page.theme.danger
                    enabled: !page.deleting
                    text: page.deleting ? Lang.i18n("Deleting…") : page.detail && page.detail.recurring ? Lang.i18n("Delete whole series") : Lang.i18n("Delete")
                    onClicked: page.deleteDetail()
                }
                // Calendars: connect an account or a link
                IconButton {
                    visible: page.detail === null
                    iconName: "configure-symbolic"
                    iconSize: 12
                    implicitWidth: 18; implicitHeight: 18
                    color: page.theme.subText
                    hoverColor: page.theme.faint
                    onClicked: { page.eventAfterAccount = false; page.overlay = "link"; }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: page.provider !== null && page.provider.errorNames.length > 0
                text: visible ? Lang.i18n("Could not update: %1", page.provider.errorNames.join(", ")) : ""
                color: page.theme.readable(page.theme.warning, page.theme.surface)
                font.pointSize: page.theme.fontSmall * 0.9
                elide: Text.ElideRight
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: page.detail === null
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: page.dayEvents

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool current: page.pinned !== null && page.pinned.key === modelData.key
                    readonly property bool running: !modelData.allDay && !modelData.todo && page.now >= modelData.start && page.now < modelData.end
                    readonly property bool over: !modelData.allDay && page.now >= modelData.end && modelData.end >= modelData.start

                    width: list.width
                    height: 32
                    radius: 10
                    color: rowMouse.pressed ? page.theme.pressedFill
                         : rowMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                         : current || running ? page.theme.faint : "transparent"
                    opacity: over ? 0.55 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 6

                        // Source calendar colour
                        Rectangle {
                            Layout.preferredWidth: 4
                            Layout.preferredHeight: 20
                            radius: 2
                            color: row.modelData.color
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: (row.modelData.todo ? "☐ " : "") + (row.modelData.title || Lang.i18n("Event"))
                                color: page.theme.text
                                font.pointSize: page.theme.fontSmall
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: [row.modelData.allDay ? Lang.i18n("All day") : page.provider.timeRange(row.modelData), row.modelData.calendar].filter(s => s.length > 0).join(" · ")
                                color: row.running ? page.theme.text : page.theme.subText
                                font.pointSize: page.theme.fontSmall * 0.85
                                font.features: { "tnum": 1 }
                                elide: Text.ElideRight
                            }
                        }
                        Kirigami.Icon {
                            visible: row.modelData.link.length > 0
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            source: "camera-video-symbolic"
                            color: page.theme.text
                            isMask: true
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.detail = row.modelData
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: !page.provider.calendar.loaded ? Lang.i18n("Loading calendar…") : Lang.i18n("No events on this day")
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall
                }
            }

            // Details of one event
            Flickable {
                id: details
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: page.detail !== null
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentHeight: detailColumn.implicitHeight
                readonly property var e: page.detail
                readonly property string where: e && e.location && e.location !== e.link ? e.location : ""

                ColumnLayout {
                    id: detailColumn
                    width: details.width
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Rectangle {
                            Layout.preferredWidth: 4
                            Layout.fillHeight: true
                            radius: 2
                            color: details.e ? details.e.color : "transparent"
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: details.e ? (details.e.todo ? "☐ " : "") + (details.e.title || Lang.i18n("Event")) : ""
                                color: page.theme.text
                                font.pointSize: page.theme.fontNormal
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: details.e ? page.dateRange(details.e) : ""
                                color: page.theme.subText
                                font.pointSize: page.theme.fontSmall
                                font.features: { "tnum": 1 }
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: page.detailError.length > 0
                        text: page.detailError
                        color: page.theme.readable(page.theme.danger, page.theme.surface)
                        font.pointSize: page.theme.fontSmall * 0.9
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: !details.e ? [] : [
                            { icon: "view-calendar-symbolic", text: page.escapeHtml(details.e.calendar) },
                            { icon: "mark-location-symbolic", text: details.where.length > 0 ? page.placeHtml(details.where) : "" },
                            { icon: "view-list-text-symbolic", text: page.linkify(details.e.notes || "") }
                        ].filter(line => line.text.length > 0)
                        delegate: RowLayout {
                            id: line
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6
                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                                Layout.topMargin: 2
                                source: line.modelData.icon
                                color: page.theme.subText
                                isMask: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: line.modelData.text
                                textFormat: Text.StyledText
                                color: page.theme.subText
                                linkColor: page.theme.readable(page.theme.blue, page.theme.surface)
                                font.pointSize: page.theme.fontSmall * 0.9
                                wrapMode: Text.Wrap
                                onLinkActivated: link => Qt.openUrlExternally(link)
                                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                            }
                        }
                    }
                    Rectangle {
                        visible: details.e !== null && details.e.link.length > 0
                        Layout.topMargin: 2
                        implicitWidth: linkLabel.implicitWidth + 22
                        implicitHeight: 24
                        radius: 12
                        color: linkMouse.pressed ? page.theme.pressedFill
                             : linkMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                             : page.theme.faint
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            id: linkLabel
                            anchors.centerIn: parent
                            text: Lang.i18nc("@action:button opens the link of a calendar event", "Open link")
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall
                            font.weight: Font.DemiBold
                        }
                        MouseArea { id: linkMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.provider.open(details.e) }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !page.connected && !page.connecting
        spacing: 6
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            source: "view-calendar-symbolic"
            color: page.theme.subText
            isMask: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Lang.i18n("No calendar connected")
            color: page.theme.subText
            font.pointSize: page.theme.fontNormal
        }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: !page.connected
            implicitWidth: connectLabel.implicitWidth + 24
            implicitHeight: 28
            radius: 14
            color: connectMouse.pressed ? page.theme.pressedFill
                 : connectMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                 : page.theme.faint
            scale: connectMouse.pressed ? 0.95 : connectMouse.containsMouse ? 1.05 : 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Text {
                id: connectLabel
                anchors.centerIn: parent
                text: Lang.i18nc("@action:button starts connecting a calendar link", "Connect a calendar…")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
            MouseArea { id: connectMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.overlay = "link" }
        }
    }
}
