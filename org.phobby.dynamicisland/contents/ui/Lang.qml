/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The island's own translations: English source strings (as in KDE's
    i18n) looked up in translations/<language>.js. The language is chosen in
    Settings → Language ("auto" follows the system: Turkish when the system
    is Turkish, English otherwise) and changes at once, for this widget only;
    KDE's i18n picks the language for all of plasmashell and cannot do that.

    Same calls as KDE's: Lang.i18n(text, args…), Lang.i18nc(context, text,
    args…), Lang.i18np(singular, plural, n, args…). Bindings that call them
    follow `language`. A string missing from a table stays English.
*/
pragma Singleton
import QtQuick
import "translations/tr.js" as Tr

QtObject {
    // "auto", "tr" or "en": the widget's setting (main.qml, the settings pages).
    property string setting: "auto"
    readonly property string systemLanguage: Qt.locale().name.toLowerCase().startsWith("tr") ? "tr" : "en"
    readonly property string language: setting === "tr" || setting === "en" ? setting : systemLanguage
    // Month and day names, date and time formats in that language: the system's
    // own locale when it is that language, else a Turkish or English one.
    readonly property var locale: language === systemLanguage ? Qt.locale() : Qt.locale(language === "tr" ? "tr_TR" : "en_US")
    readonly property var tables: ({ tr: Tr.table })

    // How the island writes the time (Settings → General): 0 as the system does (its
    // region's time format, LC_TIME, whatever the island's language), 1 always in 24
    // hours, 2 always in 12. Plasma has no 24-hour switch of its own beyond the region.
    property int clockSetting: 0
    readonly property string timeFormat: shortTime(Qt.locale().timeFormat(Locale.ShortFormat), clockSetting)
    // A short time format made 24- or 12-hour (as Plasma's digital clock does it): the
    // morning/afternoon marker (AP, ap, A, a) taken out or added, the hours' letter changed.
    function shortTime(format: string, mode: int): string {
        // C and some regional short formats include seconds. Explicit 12/24-hour
        // choices show hours and minutes; system mode keeps the original format.
        if (mode === 1 || mode === 2)
            format = format.replace(/[:.]s{1,2}(?:[.,]z{1,3})?/g, "");
        if (mode === 1)
            return format.replace(/[\s  ]*[aA][pP]?[\s  ]*/g, " ").replace(/[hH]+/g, "HH").trim();
        if (mode === 2)
            return /[aA]/.test(format) ? format.replace(/H+/g, "h") : format.replace(/[hH]+/g, "h") + " AP";
        return format;
    }

    function lookup(key: string, fallback: var): var {
        const table = tables[language];
        const found = table ? table[key] : undefined;
        return found === undefined ? fallback : found;
    }
    // %1, %2… in one pass, so an argument containing "%2" stays as it is.
    function substitute(text: string, args: var): string {
        return text.replace(/%(\d+)/g, (match, n) => {
            const i = Number(n) - 1;
            return i >= 0 && i < args.length ? String(args[i]) : match;
        });
    }
    // "%45" in Turkish, "45%" in English.
    function percent(value: var): string {
        return language === "tr" ? "%" + value : value + "%";
    }
    function i18n(text: string, ...args): string {
        return substitute(lookup(text, text), args);
    }
    function i18nc(context: string, text: string, ...args): string {
        return substitute(lookup(context + "\u0004" + text, lookup(text, text)), args);
    }
    function i18np(singular: string, plural: string, n: var, ...args): string {
        const found = lookup(singular + "\u0005" + plural, null);
        const one = Number(n) === 1;
        const text = found === null ? (one ? singular : plural) : Array.isArray(found) ? found[one ? 0 : 1] : found;
        return substitute(text, [n].concat(args));
    }
}
