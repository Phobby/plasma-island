/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Calendar: timing options and the list of connected calendars. Calendars are
    iCalendar (.ics) subscription links; "+ Takvim Bağla" opens a small wizard
    (Google Calendar / Apple iCloud) that explains where to find the link,
    downloads it once to make sure it really is a calendar, and adds it.

    Sources are stored in cfg_calendarSources as a JSON list of
    { id, type: "google" | "apple", url, name, color, enabled }.
    The step-by-step instructions are deliberately English only.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_showCalendar: enableCheck.checked
    property alias cfg_calendarLeadMinutes: leadSpin.value
    property alias cfg_calendarLingerMinutes: lingerSpin.value
    property alias cfg_calendarShowAllDay: allDayCheck.checked
    property alias cfg_calendarRefreshMinutes: refreshSpin.value
    property string cfg_calendarSources: "[]"
    // Written by the widget after every download: { id: { t: ms, error } }
    property string cfg_calendarStatus: "{}"

    readonly property var sources: {
        try {
            const list = JSON.parse(cfg_calendarSources || "[]");
            return Array.isArray(list) ? list.filter(s => s && typeof s.url === "string") : [];
        } catch (e) { return []; }
    }
    readonly property var status: {
        try { return JSON.parse(cfg_calendarStatus || "{}") || {}; } catch (e) { return {}; }
    }
    readonly property var palette: ["#0a84ff", "#32d74b", "#ff9f0a", "#bf5af2", "#ff453a", "#64d2ff", "#ffd60a", "#ac8e68"]

    function store(list: var): void {
        cfg_calendarSources = JSON.stringify(list);
    }

    // ---- link checks ----------------------------------------------------------------
    // webcal:// is only a hint for calendar apps; the file is served over https.
    function normalize(url: string): string {
        return String(url).trim().replace(/^webcals?:\/\//i, "https://");
    }
    function isConnected(url: string): bool {
        const u = normalize(url);
        return sources.some(s => normalize(s.url) === u);
    }
    // "" when the text can be a calendar link; otherwise what is wrong with it.
    function formatProblem(url: string): string {
        const u = String(url).trim();
        if (u.length === 0) return i18n("Önce takvim linkini yapıştır.");
        if (!/^(https?|webcals?):\/\/[^\s]+$/i.test(u)) return i18n("Bu bir link değil. Link http://, https:// veya webcal:// ile başlamalı.");
        if (/calendar\.google\.com\/calendar\/(embed|u\/\d+\/r|r)\b/i.test(u))
            return i18n("Bu, Google Takvim sayfasının adresi. Gereken link \"Secret address in iCal format\" alanındaki, sonu basic.ics ile biten adres.");
        if (isConnected(u)) return i18n("Bu takvim zaten bağlı.");
        return "";
    }
    readonly property string notCalendarMessage: i18n("Bu link bir takvim dosyasına benzemiyor. Lütfen adımları tekrar kontrol et.")

    // Downloads the link once. done({ ok, name, count, error })
    function check(url: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            const text = xhr.responseText || "";
            if (xhr.status === 200 && /^\s*BEGIN:VCALENDAR/i.test(text)) {
                const name = /^X-WR-CALNAME[^:\r\n]*:(.*)$/im.exec(text);
                done({ ok: true, name: name ? name[1].trim().replace(/\\([,;\\])/g, "$1") : "", count: (text.match(/^BEGIN:VEVENT/gim) || []).length });
                return;
            }
            const detail = xhr.status === 200 ? i18n("İndirilen dosya bir takvim (VCALENDAR) değil.")
                         : xhr.status > 0 ? i18n("Sunucu %1 yanıtı verdi.", xhr.status)
                         : i18n("Bağlantı kurulamadı.");
            done({ ok: false, error: page.notCalendarMessage + " " + detail });
        };
        xhr.open("GET", normalize(url));
        xhr.send();
    }

    function addSource(type: string, url: string, name: string, color: string): void {
        const list = sources.slice();
        list.push({ id: Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36), type: type,
                    url: normalize(url), name: name.trim(), color: color, enabled: true });
        store(list);
    }
    function removeSource(index: int): void {
        const list = sources.slice();
        list.splice(index, 1);
        store(list);
    }
    function setEnabled(index: int, on: bool): void {
        const list = sources.slice();
        list[index] = Object.assign({}, list[index], { enabled: on });
        store(list);
    }
    function freeColor(): string {
        const used = sources.map(s => s.color);
        const free = palette.filter(c => used.indexOf(c) < 0);
        const pool = free.length > 0 ? free : palette;
        return pool[Math.floor(Math.random() * pool.length)];
    }

    // ---- wizard state ---------------------------------------------------------------
    // step: "pick" → "link" → "name"
    property string wizardStep: "pick"
    property string wizardType: "google"
    property string wizardError: ""
    property bool wizardBusy: false
    property string wizardUrl: ""
    property string wizardName: ""
    property string wizardColor: palette[0]
    property int wizardCount: 0

    function startWizard(): void {
        wizardStep = "pick"; wizardError = ""; wizardBusy = false; wizardUrl = ""; wizardName = ""; wizardCount = 0;
        wizardColor = freeColor();
    }
    function connectLink(url: string): void {
        wizardError = formatProblem(url);
        if (wizardError !== "" || wizardBusy) return;
        wizardBusy = true;
        check(url, result => {
            wizardBusy = false;
            if (!result.ok) { wizardError = result.error; return; }
            wizardUrl = normalize(url);
            wizardName = result.name;
            wizardCount = result.count;
            wizardStep = "name";
        });
    }
    function finishWizard(name: string): bool {
        if (name.trim().length === 0) { wizardError = i18n("Takvime kısa bir ad ver (ör. İş, Kişisel)."); return false; }
        if (isConnected(wizardUrl)) { wizardError = i18n("Bu takvim zaten bağlı."); return false; }
        addSource(wizardType, wizardUrl, name, wizardColor);
        wizardError = "";
        return true;
    }

    readonly property var instructions: ({
        google: "1. Open Google Calendar in a browser on a computer (not the phone app).\n"
              + "2. Click the Settings gear at the top right, then \"Settings\".\n"
              + "3. On the left, under \"Settings for my calendars\", click the calendar you want.\n"
              + "4. Click \"Integrate calendar\" (or scroll down to that section).\n"
              + "5. Copy the link under \"Secret address in iCal format\".\n"
              + "6. Paste it below.\n\n"
              + "Work or school account and no secret address? Your administrator has turned it off.",
        apple: "On iPhone / iPad:\n"
             + "1. Open the Calendar app.\n"
             + "2. Tap \"Calendars\" at the bottom, then tap the (i) icon next to the calendar.\n"
             + "3. Turn on \"Public Calendar\".\n"
             + "4. Tap \"Share Link\" and copy it.\n"
             + "5. Paste it below.\n\n"
             + "On Mac:\n"
             + "1. Open the Calendar app.\n"
             + "2. Right-click the calendar in the sidebar and choose \"Share Calendar…\".\n"
             + "3. Check \"Public Calendar\" and click \"Done\".\n"
             + "4. Click the sharing icon next to the calendar again and copy the link.\n"
             + "5. Paste it below."
    })
    readonly property var typeNames: ({ google: "Google Calendar", apple: "Apple Calendar (iCloud)" })

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.CheckBox {
                id: enableCheck
                Kirigami.FormData.label: i18n("Takvim:")
                text: i18n("Yaklaşan etkinlikleri adada göster")
            }
            QQC2.SpinBox {
                id: leadSpin
                Kirigami.FormData.label: i18n("Etkinlikten önce pinle:")
                enabled: enableCheck.checked
                from: 1; to: 120
                textFromValue: (v) => i18n("%1 dk kala", v)
                valueFromText: (t) => parseInt(t)
            }
            QQC2.SpinBox {
                id: lingerSpin
                Kirigami.FormData.label: i18n("Bittikten sonra kalsın:")
                enabled: enableCheck.checked
                from: 0; to: 120
                textFromValue: (v) => i18n("%1 dk", v)
                valueFromText: (t) => parseInt(t)
            }
            QQC2.CheckBox {
                id: allDayCheck
                Kirigami.FormData.label: i18n("Takvim sayfası:")
                enabled: enableCheck.checked
                text: i18n("Tüm gün etkinliklerini listede göster")
            }
            QQC2.SpinBox {
                id: refreshSpin
                Kirigami.FormData.label: i18n("Takvimleri güncelle:")
                enabled: enableCheck.checked
                from: 1; to: 60
                textFromValue: (v) => i18n("%1 dakikada bir", v)
                valueFromText: (t) => parseInt(t)
            }
        }

        Kirigami.Heading {
            level: 4
            text: i18n("Bağlı takvimler")
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: page.sources.length === 0
            wrapMode: Text.Wrap
            opacity: 0.7
            text: i18n("Henüz takvim bağlanmadı. Google Takvim veya Apple iCloud takvimini bağlamak için aşağıdaki düğmeyi kullan.")
        }

        Repeater {
            model: page.sources
            delegate: RowLayout {
                id: sourceRow
                required property var modelData
                required property int index
                readonly property var state: page.status[modelData.id] ?? null
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // Included in the island?
                QQC2.CheckBox {
                    checked: sourceRow.modelData.enabled !== false
                    onToggled: page.setEnabled(sourceRow.index, checked)
                    QQC2.ToolTip.text: i18n("Bu takvimi dahil et")
                    QQC2.ToolTip.visible: hovered
                }
                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    radius: width / 2
                    color: sourceRow.modelData.color || page.palette[0]
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: sourceRow.modelData.name || i18n("Takvim")
                        elide: Text.ElideRight
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                        elide: Text.ElideRight
                        color: sourceRow.state && sourceRow.state.error ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        opacity: sourceRow.state && sourceRow.state.error ? 1 : 0.7
                        text: {
                            const kind = page.typeNames[sourceRow.modelData.type] || i18n(".ics linki");
                            const st = sourceRow.state;
                            if (!st) return i18n("%1 · henüz güncellenmedi", kind);
                            const at = Qt.formatDateTime(new Date(st.t), Qt.locale().dateTimeFormat(Locale.ShortFormat));
                            return st.error ? i18n("%1 · güncellenemedi (%2): %3", kind, at, st.error) : i18n("%1 · son güncelleme: %2", kind, at);
                        }
                    }
                }
                QQC2.ToolButton {
                    icon.name: "edit-delete"
                    text: i18n("Kaldır")
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: page.removeSource(sourceRow.index)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                }
            }
        }

        QQC2.Button {
            icon.name: "list-add"
            text: i18n("Takvim Bağla")
            onClicked: { page.startWizard(); wizard.open(); }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Değişiklikler \"Uygula\"ya basınca geçerli olur. Takvim linkleri bu bilgisayardaki Plasma ayar dosyasında saklanır; dosyayı yalnızca senin kullanıcın okuyabilir.")
        }
    }

    Kirigami.Dialog {
        id: wizard
        title: page.wizardStep === "pick" ? i18n("Takvim Bağla") : page.typeNames[page.wizardType]
        preferredWidth: Kirigami.Units.gridUnit * 26
        padding: Kirigami.Units.largeSpacing
        standardButtons: Kirigami.Dialog.NoButton
        onClosed: { linkField.text = ""; nameField.text = ""; }

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // ---- step 1: which calendar ----
            RowLayout {
                visible: page.wizardStep === "pick"
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: [{ type: "google", icon: "im-google", fallback: "view-calendar-month" },
                            { type: "apple", icon: "phone-apple-iphone", fallback: "view-calendar-day" }]
                    delegate: QQC2.Button {
                        id: pickButton
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 6
                        onClicked: { page.wizardType = modelData.type; page.wizardError = ""; page.wizardStep = "link"; linkField.forceActiveFocus(); }
                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                                Layout.preferredHeight: Kirigami.Units.iconSizes.large
                                source: pickButton.modelData.icon
                                fallback: pickButton.modelData.fallback
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                text: page.typeNames[pickButton.modelData.type]
                            }
                        }
                    }
                }
            }

            // ---- step 2: instructions + link ----
            ColumnLayout {
                visible: page.wizardStep === "link"
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: page.instructions[page.wizardType]
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                    text: i18n("⚠️ Bu link takvimine erişim sağlar, kimseyle paylaşma.")
                }
                QQC2.TextField {
                    id: linkField
                    Layout.fillWidth: true
                    placeholderText: "Paste your calendar link here"
                    enabled: !page.wizardBusy
                    onAccepted: page.connectLink(text)
                    onTextEdited: page.wizardError = ""
                }
            }

            // ---- step 3: name + colour ----
            ColumnLayout {
                visible: page.wizardStep === "name"
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: i18np("Takvim bulundu: %1 etkinlik içeriyor.", "Takvim bulundu: %1 etkinlik içeriyor.", page.wizardCount)
                }
                QQC2.TextField {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: i18n("Takvimin adı (ör. İş, Kişisel)")
                    onAccepted: if (page.finishWizard(text)) wizard.close()
                    onTextEdited: page.wizardError = ""
                }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label { text: i18n("Renk:") }
                    Repeater {
                        model: page.palette
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            radius: width / 2
                            color: modelData
                            border.width: page.wizardColor === modelData ? 3 : 0
                            border.color: Kirigami.Theme.textColor
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.wizardColor = parent.modelData }
                        }
                    }
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: page.wizardError.length > 0
                type: Kirigami.MessageType.Error
                text: page.wizardError
            }

            RowLayout {
                visible: page.wizardStep !== "pick"
                Layout.fillWidth: true
                QQC2.Button {
                    icon.name: "go-previous"
                    text: i18n("Geri")
                    enabled: !page.wizardBusy
                    onClicked: { page.wizardError = ""; page.wizardStep = page.wizardStep === "name" ? "link" : "pick"; }
                }
                Item { Layout.fillWidth: true }
                QQC2.BusyIndicator {
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    visible: page.wizardBusy
                    running: visible
                }
                QQC2.Button {
                    visible: page.wizardStep === "link"
                    icon.name: "network-connect"
                    text: i18n("Bağla")
                    enabled: !page.wizardBusy
                    onClicked: page.connectLink(linkField.text)
                }
                QQC2.Button {
                    visible: page.wizardStep === "name"
                    icon.name: "list-add"
                    text: i18n("Ekle")
                    onClicked: if (page.finishWizard(nameField.text)) wizard.close()
                }
            }
        }
    }
    // The name found in the file is only a suggestion the user can edit.
    onWizardStepChanged: if (wizardStep === "name") { nameField.text = wizardName; nameField.forceActiveFocus(); }
}
