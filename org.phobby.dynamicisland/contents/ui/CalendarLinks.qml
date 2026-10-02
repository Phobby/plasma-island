/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Shared logic for connecting a calendar link (.ics): used by the wizard in
    the island (CalendarConnect.qml) and by the settings page. Google Calendar
    and Apple iCloud work the same way; only the instructions differ. The
    step-by-step instructions are deliberately English only.
*/
import QtQuick

QtObject {
    id: links

    // Stored list of { id, type, url, name, color, enabled }
    property var sources: []

    readonly property var palette: ["#0a84ff", "#32d74b", "#ff9f0a", "#bf5af2", "#ff453a", "#64d2ff", "#ffd60a", "#ac8e68"]
    readonly property var typeNames: ({ google: "Google Calendar", apple: "Apple Calendar (iCloud)" })
    readonly property var typeIcons: ({ google: Qt.resolvedUrl("../icons/google.svg"), apple: Qt.resolvedUrl("../icons/apple.svg") })
    readonly property string secretWarning: i18n("⚠️ Bu link takvimine erişim sağlar, kimseyle paylaşma.")
    readonly property string notCalendarMessage: i18n("Bu link bir takvim dosyasına benzemiyor. Lütfen adımları tekrar kontrol et.")

    readonly property var instructions: ({
        google: "1. Open Google Calendar in a browser on a computer (not the phone app).\n"
              + "2. Click the Settings gear at the top right, then \"Settings\".\n"
              + "3. On the left, under \"Settings for my calendars\", click the calendar you want.\n"
              + "4. Click \"Integrate calendar\" (or scroll down to that section).\n"
              + "5. Copy the link under \"Secret address in iCal format\".\n"
              + "6. Paste it below.\n"
              + "Work or school account and no secret address? Your administrator has turned it off.",
        iphone: "1. Open the Calendar app.\n"
              + "2. Tap \"Calendars\" at the bottom, then tap the (i) icon next to the calendar.\n"
              + "3. Turn on \"Public Calendar\".\n"
              + "4. Tap \"Share Link\" and copy it.\n"
              + "5. Paste it below.",
        mac: "1. Open the Calendar app.\n"
           + "2. Right-click the calendar in the sidebar and choose \"Share Calendar…\".\n"
           + "3. Check \"Public Calendar\" and click \"Done\".\n"
           + "4. Click the sharing icon next to the calendar again and copy the link.\n"
           + "5. Paste it below."
    })
    readonly property string appleInstructions: "On iPhone / iPad:\n" + instructions.iphone + "\n\nOn Mac:\n" + instructions.mac

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

    // Downloads the link once: it must really be an iCalendar file.
    // done({ ok, name, count, error })
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
            done({ ok: false, error: links.notCalendarMessage + " " + detail });
        };
        xhr.open("GET", normalize(url));
        xhr.send();
    }

    function freeColor(): string {
        const used = sources.map(s => s.color);
        const free = palette.filter(c => used.indexOf(c) < 0);
        const pool = free.length > 0 ? free : palette;
        return pool[Math.floor(Math.random() * pool.length)];
    }
    function makeSource(type: string, url: string, name: string, color: string): var {
        return { id: Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36), type: type,
                 url: normalize(url), name: name.trim(), color: color, enabled: true };
    }
}
