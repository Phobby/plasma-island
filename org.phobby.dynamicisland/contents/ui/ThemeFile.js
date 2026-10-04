/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Theme files: a look of the island as one small JSON file
    (*.islandtheme.json) that can be saved, handed on and added again, and the
    list of such files in a catalog (catalog/index.json of the repository).

      { "schema": 1, "name": "…", "author": "…", "description": "…",
        "style": { …the Appearance settings, see Styles.qml… } }

    A theme is data only: no code, no QML, no images. Reading one never runs
    anything; what is not a known field of the right type and range makes the
    file invalid, what is unknown is left out. The same rules are written down
    as a JSON Schema in catalog/islandtheme.schema.json.

    Nothing here touches files or the network (ThemeLibrary.qml and
    ThemeStore.qml do), so it runs under node as well: tests/themefile.test.js.
*/
.pragma library

// Where the catalog is published: the address of the repository's catalog/
// folder as raw.githubusercontent.com serves it,
//   https://raw.githubusercontent.com/<owner>/<repository>/<branch>/catalog
// A placeholder until the repository is published: while OWNER/REPOSITORY/BRANCH
// stand here the store says that it has no address yet and asks nothing.
const CATALOG_URL = "https://raw.githubusercontent.com/OWNER/REPOSITORY/BRANCH/catalog";

const SCHEMA = 1;
const SUFFIX = ".islandtheme.json";
// A theme is a few hundred bytes; nothing larger is read or downloaded.
const MAX_BYTES = 64 * 1024;
const MAX_INDEX_BYTES = 256 * 1024;

const PRESETS = ["oxygen", "breezeDark", "breezeLight", "glass", "contrast", "aurora", "sunset", "ocean", "midnight"];
// field: [lowest, highest], whole numbers
const NUMBERS = { opacity: [0, 100], blurLevel: [0, 2], top: [0, 40], offsetX: [-100, 100], scale: [80, 120], radius: [0, 100],
                  borderWidth: [1, 4], shadow: [0, 2], gradientAngle: [0, 360] };
const BOOLEANS = ["blur", "border", "strong"];
const CHOICES = { preset: PRESETS, material: ["metal", "flat", "glass"], fill: ["solid", "gradient"], gradientType: ["linear", "radial"] };
// field: what it may be besides "#rrggbb"
const COLORS = { background: ["accent"], control: ["accent"], text: [""], borderColor: [""] };
// The order the fields are written in.
const FIELDS = ["preset", "material", "strong", "opacity", "blur", "blurLevel", "top", "offsetX", "scale", "radius", "fill", "background",
                "gradientType", "gradientAngle", "gradientStops", "control", "text", "border", "borderWidth", "borderColor", "shadow"];

function isColor(text) { return typeof text === "string" && /^#[0-9a-fA-F]{6}$/.test(text); }
function isText(value, longest) { return typeof value === "string" && value.length <= longest && !/[\u0000-\u001f\u007f]/.test(value); }

// The known fields of `given`, or the name of the first one that is not what it has to be.
function checkStyle(given) {
    const style = {};
    if (!given || typeof given !== "object" || Array.isArray(given)) return { field: "style" };
    for (const key of FIELDS) {
        const v = given[key];
        if (v === undefined) continue;
        let good;
        if (NUMBERS[key] !== undefined) good = typeof v === "number" && Math.floor(v) === v && v >= NUMBERS[key][0] && v <= NUMBERS[key][1];
        else if (BOOLEANS.indexOf(key) >= 0) good = typeof v === "boolean";
        else if (CHOICES[key] !== undefined) good = typeof v === "string" && CHOICES[key].indexOf(v) >= 0;
        else if (COLORS[key] !== undefined) good = isColor(v) || COLORS[key].indexOf(v) >= 0;
        else good = Array.isArray(v) && (v.length === 2 || v.length === 3) && v.every(isColor);      // gradientStops
        if (!good) return { field: "style." + key };
        style[key] = Array.isArray(v) ? v.slice() : v;
    }
    return { style: style };
}

// A theme from the text of a file: { ok, theme: { name, author, description, style }, error, field }.
// error: "size" (too large), "json" (not JSON), "object", "schema" (no or a wrong version), "newer"
// (a version this island does not know yet), "name", "field" (`field` says which).
// The style holds the known fields only; Styles.normalize() makes it whole.
function parse(text) {
    const fail = (error, field) => ({ ok: false, theme: null, error: error, field: field || "" });
    if (typeof text !== "string") return fail("json");
    if (text.length > MAX_BYTES) return fail("size");
    let given;
    try { given = JSON.parse(text.replace(/^﻿/, "")); } catch (e) { return fail("json"); }
    if (!given || typeof given !== "object" || Array.isArray(given)) return fail("object");
    if (typeof given.schema !== "number" || Math.floor(given.schema) !== given.schema || given.schema < 1) return fail("schema");
    if (given.schema > SCHEMA) return fail("newer");
    if (!isText(given.name, 60) || given.name.trim().length === 0) return fail("name");
    for (const [key, longest] of [["author", 80], ["description", 300]])
        if (given[key] !== undefined && !isText(given[key], longest)) return fail("field", key);
    const checked = checkStyle(given.style);
    if (checked.field !== undefined) return fail("field", checked.field);
    return { ok: true, error: "", field: "",
             theme: { name: given.name.trim(), author: (given.author || "").trim(), description: (given.description || "").trim(), style: checked.style } };
}

// The text of a theme file: `style` is a whole style (Styles.normalize).
function stringify(name, author, description, style) {
    const out = { schema: SCHEMA, name: String(name).trim() };
    if (String(author || "").trim().length > 0) out.author = String(author).trim();
    if (String(description || "").trim().length > 0) out.description = String(description).trim();
    out.style = {};
    for (const key of FIELDS) if (style[key] !== undefined) out.style[key] = style[key];
    return JSON.stringify(out, null, 2) + "\n";
}

// "Gün Batımı 2" → "gun-batimi-2": the file a theme is kept in.
function slug(name) {
    const plain = String(name).toLowerCase().replace(/ı/g, "i").replace(/ğ/g, "g").replace(/ü/g, "u").replace(/ş/g, "s").replace(/ö/g, "o").replace(/ç/g, "c")
                              .replace(/i̇/g, "i").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 48);
    return plain.length > 0 ? plain : "theme";
}
// Two themes are the same one when their names are, whatever the case and the spaces around.
function sameName(a, b) { return String(a).trim().toLowerCase() === String(b).trim().toLowerCase(); }

// ---- the catalog -------------------------------------------------------------------
function configured(url) {
    return /^https?:\/\/[^\s]+$/.test(String(url)) && !/\/OWNER\/REPOSITORY\/BRANCH(\/|$)/.test(String(url));
}
// The catalog's list: { ok, themes: [{ id, name, author, description, path, sha256, preview }], error }.
// An entry that is not complete is left out; a path never leaves the catalog's themes/ folder.
function parseIndex(text) {
    if (typeof text !== "string" || text.length > MAX_INDEX_BYTES) return { ok: false, themes: [], error: "size" };
    let given;
    try { given = JSON.parse(text.replace(/^﻿/, "")); } catch (e) { return { ok: false, themes: [], error: "json" }; }
    if (!given || typeof given !== "object" || !Array.isArray(given.themes)) return { ok: false, themes: [], error: "object" };
    if (typeof given.schema !== "number" || given.schema < 1) return { ok: false, themes: [], error: "schema" };
    if (given.schema > SCHEMA) return { ok: false, themes: [], error: "newer" };
    const themes = [], seen = {};
    for (const e of given.themes) {
        if (!e || typeof e !== "object") continue;
        if (typeof e.id !== "string" || !/^[a-z0-9][a-z0-9-]{0,47}$/.test(e.id) || seen[e.id]) continue;
        if (!isText(e.name, 60) || e.name.trim().length === 0) continue;
        if (typeof e.path !== "string" || !/^themes\/[A-Za-z0-9][A-Za-z0-9._-]{0,79}\.islandtheme\.json$/.test(e.path) || e.path.indexOf("..") >= 0) continue;
        if (typeof e.sha256 !== "string" || !/^[0-9a-fA-F]{64}$/.test(e.sha256)) continue;
        seen[e.id] = true;
        const preview = checkStyle(e.preview || {});
        themes.push({ id: e.id, name: e.name.trim(), author: isText(e.author, 80) ? e.author.trim() : "",
                      description: isText(e.description, 300) ? e.description.trim() : "", path: e.path, sha256: e.sha256.toLowerCase(),
                      preview: preview.style || {} });
    }
    return { ok: true, themes: themes, error: "" };
}

// ---- bytes -----------------------------------------------------------------------
// The text of UTF-8 bytes (an array or a typed array); null when they are not UTF-8.
function utf8Decode(bytes) {
    let out = "", i = 0;
    const n = bytes.length, need = k => { if (i + k > n) return false; for (let j = 1; j < k; ++j) if ((bytes[i + j] & 0xc0) !== 0x80) return false; return true; };
    while (i < n) {
        const b = bytes[i];
        let code, size;
        if (b < 0x80) { code = b; size = 1; }
        else if (b >= 0xc2 && b < 0xe0) { if (!need(2)) return null; code = ((b & 0x1f) << 6) | (bytes[i + 1] & 0x3f); size = 2; }
        else if (b >= 0xe0 && b < 0xf0) {
            if (!need(3)) return null;
            code = ((b & 0x0f) << 12) | ((bytes[i + 1] & 0x3f) << 6) | (bytes[i + 2] & 0x3f); size = 3;
            if (code < 0x800 || (code >= 0xd800 && code <= 0xdfff)) return null;
        } else if (b >= 0xf0 && b < 0xf5) {
            if (!need(4)) return null;
            code = ((b & 0x07) << 18) | ((bytes[i + 1] & 0x3f) << 12) | ((bytes[i + 2] & 0x3f) << 6) | (bytes[i + 3] & 0x3f); size = 4;
            if (code < 0x10000 || code > 0x10ffff) return null;
        } else return null;
        if (code >= 0x10000) { code -= 0x10000; out += String.fromCharCode(0xd800 + (code >> 10), 0xdc00 + (code & 0x3ff)); }
        else out += String.fromCharCode(code);
        i += size;
    }
    return out;
}
function utf8Encode(text) {
    const out = [];
    for (let i = 0; i < text.length; ++i) {
        let c = text.charCodeAt(i);
        if (c >= 0xd800 && c < 0xdc00 && i + 1 < text.length) {
            const low = text.charCodeAt(i + 1);
            if (low >= 0xdc00 && low < 0xe000) { c = 0x10000 + ((c - 0xd800) << 10) + (low - 0xdc00); ++i; }
        }
        if (c < 0x80) out.push(c);
        else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
        else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
        else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 0x3f), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
    }
    return out;
}

// SHA-256 of bytes (an array or a typed array), as 64 hexadecimal digits.
function sha256(bytes) {
    const K = [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
               0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
               0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
               0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
               0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
               0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2];
    const h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    const length = bytes.length, total = ((length + 9 + 63) >> 6) << 6, data = new Array(total).fill(0);
    for (let i = 0; i < length; ++i) data[i] = bytes[i] & 0xff;
    data[length] = 0x80;
    const bits = length * 8;
    data[total - 5] = Math.floor(bits / 0x100000000) & 0xff;
    data[total - 4] = (bits >>> 24) & 0xff; data[total - 3] = (bits >>> 16) & 0xff; data[total - 2] = (bits >>> 8) & 0xff; data[total - 1] = bits & 0xff;
    const w = new Array(64), rot = (x, n) => (x >>> n) | (x << (32 - n));
    for (let at = 0; at < total; at += 64) {
        for (let i = 0; i < 16; ++i) w[i] = ((data[at + 4 * i] << 24) | (data[at + 4 * i + 1] << 16) | (data[at + 4 * i + 2] << 8) | data[at + 4 * i + 3]) | 0;
        for (let i = 16; i < 64; ++i) {
            const s0 = rot(w[i - 15], 7) ^ rot(w[i - 15], 18) ^ (w[i - 15] >>> 3), s1 = rot(w[i - 2], 17) ^ rot(w[i - 2], 19) ^ (w[i - 2] >>> 10);
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
        }
        let a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
        for (let i = 0; i < 64; ++i) {
            const t1 = (hh + (rot(e, 6) ^ rot(e, 11) ^ rot(e, 25)) + ((e & f) ^ (~e & g)) + K[i] + w[i]) | 0;
            const t2 = ((rot(a, 2) ^ rot(a, 13) ^ rot(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
            hh = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
        }
        h[0] = (h[0] + a) | 0; h[1] = (h[1] + b) | 0; h[2] = (h[2] + c) | 0; h[3] = (h[3] + d) | 0;
        h[4] = (h[4] + e) | 0; h[5] = (h[5] + f) | 0; h[6] = (h[6] + g) | 0; h[7] = (h[7] + hh) | 0;
    }
    return h.map(x => ("00000000" + (x >>> 0).toString(16)).slice(-8)).join("");
}
