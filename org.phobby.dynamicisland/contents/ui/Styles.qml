/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The looks of the island (Settings → Appearance): the ready-made presets and
    a custom style as plain data.

    A style is { preset, material (metal | flat | glass), strong (high
    contrast), opacity (0–100), blur, blurLevel (0–2), top (px), offsetX (px),
    scale (%), radius (0–100, % of a full capsule), background, control, text,
    border, borderWidth, borderColor, shadow (0–2), fill (solid | gradient),
    gradientType (linear | radial), gradientAngle (0–360°, as in CSS: 0 runs
    upwards, 90 to the right), gradientStops (2 or 3 colours) }. Colours are
    "#rrggbb"; "" means the preset's own / automatic, "accent" the system's
    accent colour (background and control only). `background` is the solid
    fill; a gradient fill takes gradient* instead. Theme.qml turns a style
    into colours.
*/
pragma Singleton
import QtQuick

QtObject {
    readonly property var order: ["oxygen", "breezeDark", "breezeLight", "glass", "contrast", "aurora", "sunset", "ocean", "midnight"]
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
                    background: "#000000", control: "#ffd60a", text: "#ffffff", border: true, borderWidth: 2, borderColor: "#ffffff", shadow: 0 },
        // Gradients. Every colour of one is dark enough for the light text to read on (4.5:1).
        aurora: { material: "flat", strong: false, opacity: 90, blur: true, blurLevel: 1, top: 6, offsetX: 0, scale: 100, radius: 100,
                  background: "#0e6f74", control: "#5eead4", text: "", border: true, borderWidth: 1, borderColor: "", shadow: 1,
                  fill: "gradient", gradientType: "linear", gradientAngle: 120, gradientStops: ["#047857", "#0e7490", "#6d28d9"] },
        sunset: { material: "flat", strong: false, opacity: 90, blur: true, blurLevel: 1, top: 6, offsetX: 0, scale: 100, radius: 100,
                  background: "#a52a4a", control: "#fdba74", text: "", border: true, borderWidth: 1, borderColor: "", shadow: 1,
                  fill: "gradient", gradientType: "linear", gradientAngle: 90, gradientStops: ["#c2410c", "#be185d", "#6b21a8"] },
        ocean: { material: "flat", strong: false, opacity: 90, blur: true, blurLevel: 1, top: 6, offsetX: 0, scale: 100, radius: 100,
                 background: "#165a9f", control: "#67e8f9", text: "", border: true, borderWidth: 1, borderColor: "", shadow: 1,
                 fill: "gradient", gradientType: "linear", gradientAngle: 180, gradientStops: ["#0e7490", "#1e40af"] },
        midnight: { material: "flat", strong: false, opacity: 92, blur: true, blurLevel: 1, top: 6, offsetX: 0, scale: 100, radius: 100,
                    background: "#141f52", control: "#93c5fd", text: "", border: true, borderWidth: 1, borderColor: "", shadow: 2,
                    fill: "gradient", gradientType: "radial", gradientAngle: 0, gradientStops: ["#1e3a8a", "#0b1026"] }
    })
    function title(preset: string): string {
        return preset === "oxygen" ? Lang.i18n("Oxygen Metallic") : preset === "breezeDark" ? Lang.i18n("Breeze Dark")
             : preset === "breezeLight" ? Lang.i18n("Breeze Light") : preset === "glass" ? Lang.i18n("Pure Glass (Minimal)")
             : preset === "contrast" ? Lang.i18n("High Contrast") : preset === "aurora" ? Lang.i18n("Aurora")
             : preset === "sunset" ? Lang.i18n("Sunset") : preset === "ocean" ? Lang.i18n("Ocean")
             : preset === "midnight" ? Lang.i18n("Midnight Blue") : preset;
    }
    // The preset as it comes, as a style of its own.
    function defaults(preset: string): var {
        const key = presets[preset] !== undefined ? preset : "oxygen";
        const out = Object.assign({ preset: key, fill: "solid", gradientType: "linear", gradientAngle: 135, gradientStops: [] }, presets[key]);
        if (out.gradientStops.length < 2) out.gradientStops = stopsFor(out);
        return out;
    }
    function isColor(text: var): bool { return typeof text === "string" && /^#[0-9a-fA-F]{6}$/.test(text); }
    // "#rrggbb" between two of them (t = 0 the first, 1 the second).
    function mixHex(a: string, b: string, t: real): string {
        const x = parseInt(a.slice(1), 16), y = parseInt(b.slice(1), 16);
        const part = shift => { const p = (x >> shift) & 255, q = (y >> shift) & 255; return Math.round(p + (q - p) * t); };
        return "#" + ((1 << 24) | (part(16) << 16) | (part(8) << 8) | part(0)).toString(16).slice(1);
    }
    // The gradient a solid style starts with when it is switched to one: from its background towards its control colour.
    function stopsFor(style: var): var {
        const from = isColor(style.background) ? style.background : "#1a1b1d";
        return [from, mixHex(from, isColor(style.control) ? style.control : "#0a84ff", 0.45)];
    }
    // Any object made a complete, valid style: what is missing or out of range comes from its preset.
    function normalize(given: var): var {
        const g = given && typeof given === "object" ? given : {};
        const out = defaults(String(g.preset || "oxygen"));
        const num = (key, min, max) => { const v = Number(g[key]); if (g[key] !== undefined && isFinite(v)) out[key] = Math.max(min, Math.min(max, Math.round(v))); };
        num("opacity", 0, 100); num("blurLevel", 0, 2); num("top", 0, 40); num("offsetX", -100, 100);
        num("scale", 80, 120); num("radius", 0, 100); num("borderWidth", 1, 4); num("shadow", 0, 2); num("gradientAngle", 0, 360);
        for (const key of ["blur", "border", "strong"]) if (typeof g[key] === "boolean") out[key] = g[key];
        if (g.material === "metal" || g.material === "flat" || g.material === "glass") out.material = g.material;
        if (isColor(g.background) || g.background === "accent") out.background = g.background;
        if (isColor(g.control) || g.control === "accent") out.control = g.control;
        if (isColor(g.text) || g.text === "") out.text = g.text;
        if (isColor(g.borderColor) || g.borderColor === "") out.borderColor = g.borderColor;
        if (g.fill === "solid" || g.fill === "gradient") out.fill = g.fill;
        if (g.gradientType === "linear" || g.gradientType === "radial") out.gradientType = g.gradientType;
        // (a list that came through a model or the configuration is not always a JavaScript array)
        const stops = [];
        if (g.gradientStops && typeof g.gradientStops === "object") for (let i = 0; i < g.gradientStops.length; ++i) stops.push(g.gradientStops[i]);
        if ((stops.length === 2 || stops.length === 3) && stops.every(isColor)) out.gradientStops = stops;
        // a solid style whose colours were changed: the gradient it would start with follows them
        else if (presets[out.preset].gradientStops === undefined) out.gradientStops = stopsFor(out);
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
