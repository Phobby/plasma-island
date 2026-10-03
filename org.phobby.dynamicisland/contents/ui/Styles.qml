/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The looks of the island (Settings → Appearance): the ready-made presets and
    a custom style as plain data.

    A style is { preset, material (metal | flat | glass), strong (high
    contrast), opacity (0–100), blur, blurLevel (0–2), top (px), offsetX (px),
    scale (%), radius (0–100, % of a full capsule), background, control, text,
    border, borderWidth, borderColor, shadow (0–2) }. Colours are "#rrggbb";
    "" means the preset's own / automatic, "accent" the system's accent colour
    (background and control only). Theme.qml turns a style into colours.
*/
pragma Singleton
import QtQuick

QtObject {
    readonly property var order: ["oxygen", "breezeDark", "breezeLight", "glass", "contrast"]
    readonly property var presets: ({
        oxygen: { material: "metal", strong: false, opacity: 82, blur: true, blurLevel: 0, top: 6, offsetX: 0, scale: 100, radius: 100,
                  background: "#1a1b1d", control: "#0a84ff", text: "", border: true, borderWidth: 1, borderColor: "", shadow: 2 },
        breezeDark: { material: "flat", strong: false, opacity: 90, blur: true, blurLevel: 1, top: 6, offsetX: 0, scale: 100, radius: 100,
                      background: "#202326", control: "#3daee9", text: "", border: true, borderWidth: 1, borderColor: "", shadow: 1 },
        breezeLight: { material: "flat", strong: false, opacity: 90, blur: true, blurLevel: 1, top: 6, offsetX: 0, scale: 100, radius: 100,
                       background: "#eff0f1", control: "#3daee9", text: "", border: true, borderWidth: 1, borderColor: "", shadow: 1 },
        glass: { material: "glass", strong: false, opacity: 30, blur: true, blurLevel: 2, top: 6, offsetX: 0, scale: 100, radius: 100,
                 background: "#14161a", control: "#ffffff", text: "", border: true, borderWidth: 1, borderColor: "", shadow: 1 },
        contrast: { material: "flat", strong: true, opacity: 100, blur: false, blurLevel: 0, top: 6, offsetX: 0, scale: 100, radius: 100,
                    background: "#000000", control: "#ffd60a", text: "#ffffff", border: true, borderWidth: 2, borderColor: "#ffffff", shadow: 0 }
    })
    function title(preset: string): string {
        return preset === "oxygen" ? Lang.i18n("Oxygen Metallic") : preset === "breezeDark" ? Lang.i18n("Breeze Dark")
             : preset === "breezeLight" ? Lang.i18n("Breeze Light") : preset === "glass" ? Lang.i18n("Pure Glass (Minimal)")
             : preset === "contrast" ? Lang.i18n("High Contrast") : preset;
    }
    // The preset as it comes, as a style of its own.
    function defaults(preset: string): var {
        const key = presets[preset] !== undefined ? preset : "oxygen";
        return Object.assign({ preset: key }, presets[key]);
    }
    function isColor(text: var): bool { return typeof text === "string" && /^#[0-9a-fA-F]{6}$/.test(text); }
    // Any object made a complete, valid style: what is missing or out of range comes from its preset.
    function normalize(given: var): var {
        const g = given && typeof given === "object" ? given : {};
        const out = defaults(String(g.preset || "oxygen"));
        const num = (key, min, max) => { const v = Number(g[key]); if (g[key] !== undefined && isFinite(v)) out[key] = Math.max(min, Math.min(max, Math.round(v))); };
        num("opacity", 0, 100); num("blurLevel", 0, 2); num("top", 0, 40); num("offsetX", -100, 100);
        num("scale", 80, 120); num("radius", 0, 100); num("borderWidth", 1, 4); num("shadow", 0, 2);
        for (const key of ["blur", "border", "strong"]) if (typeof g[key] === "boolean") out[key] = g[key];
        if (g.material === "metal" || g.material === "flat" || g.material === "glass") out.material = g.material;
        if (isColor(g.background) || g.background === "accent") out.background = g.background;
        if (isColor(g.control) || g.control === "accent") out.control = g.control;
        if (isColor(g.text) || g.text === "") out.text = g.text;
        if (isColor(g.borderColor) || g.borderColor === "") out.borderColor = g.borderColor;
        return out;
    }
    // The stored custom style. Nothing stored yet: Oxygen Metallic with what the
    // earlier settings (opacity, blur, distance from top, light metal) said.
    function parse(json: string, legacy: var): var {
        try {
            const given = JSON.parse(json || "");
            if (given && typeof given === "object" && !Array.isArray(given)) return normalize(given);
        } catch (e) {}
        const seed = defaults("oxygen");
        if (legacy) {
            seed.opacity = legacy.opacity;
            seed.blur = legacy.blur;
            seed.top = Math.min(40, legacy.top);
            if (legacy.light) seed.background = "#d6d9de";
        }
        return normalize(seed);
    }
    // Saved profiles: [{ name, style }]
    function parseProfiles(json: string): var {
        try {
            const list = JSON.parse(json || "[]");
            if (Array.isArray(list))
                return list.filter(p => p && typeof p.name === "string" && p.name.length > 0).map(p => ({ name: p.name, style: normalize(p.style) }));
        } catch (e) {}
        return [];
    }
    // The colour scheme as the island hands it to the settings page: "background,text,accent".
    function schemeText(colors: var): string {
        return colors ? [colors.background, colors.text, colors.accent].map(c => String(c)).join(",") : "";
    }
    function schemeFromText(text: string): var {
        const parts = String(text || "").split(",");
        return parts.length === 3 && parts.every(isColor) ? { background: parts[0], text: parts[1], accent: parts[2] } : null;
    }
    function same(a: var, b: var): bool { return JSON.stringify(normalize(a)) === JSON.stringify(normalize(b)); }
}
