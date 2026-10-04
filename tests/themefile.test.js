#!/usr/bin/env node
// Theme files (contents/ui/ThemeFile.js): what is accepted and refused, the
// checksum, and that catalog/ is what the island would accept. Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const ROOT = path.join(__dirname, "..");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const T = load(path.join(ROOT, "org.phobby.dynamicisland", "contents", "ui", "ThemeFile.js"));

let failed = 0, checked = 0;
function check(what, got, want) {
    ++checked;
    const g = JSON.stringify(got), w = JSON.stringify(want);
    if (g === w) return;
    ++failed;
    console.log("    FAILED: " + what + "\n      got  " + g + "\n      want " + w);
}
function test(name, body) {
    const before = failed;
    body();
    console.log((failed === before ? "  ok    " : "  FAIL  ") + name);
}

const STYLE = { preset: "oxygen", material: "metal", strong: false, opacity: 82, blur: true, blurLevel: 0, top: 6, offsetX: 0, scale: 100, radius: 100,
                fill: "gradient", background: "#1a1b1d", gradientType: "linear", gradientAngle: 135, gradientStops: ["#102030", "#405060"],
                control: "accent", text: "", border: true, borderWidth: 1, borderColor: "", shadow: 2 };
const file = changes => JSON.stringify(Object.assign({ schema: 1, name: "Mine", style: STYLE }, changes));
const styled = changes => file({ style: Object.assign({}, STYLE, changes) });

// The part of JSON Schema that catalog/islandtheme.schema.json uses.
const SCHEMA = JSON.parse(fs.readFileSync(path.join(ROOT, "catalog", "islandtheme.schema.json"), "utf8"));
function valid(value, schema) {
    if (schema.$ref) return valid(value, SCHEMA.$defs[schema.$ref.replace("#/$defs/", "")]);
    if (schema.anyOf) return schema.anyOf.some(s => valid(value, s));
    if (schema.const !== undefined) return value === schema.const;
    if (schema.enum) return schema.enum.indexOf(value) >= 0;
    const type = Array.isArray(value) ? "array" : value === null ? "null" : Number.isInteger(value) ? "integer" : typeof value;
    if (schema.type && !(schema.type === type || (schema.type === "number" && type === "integer"))) return false;
    if (type === "string") {
        if (schema.minLength !== undefined && value.length < schema.minLength) return false;
        if (schema.maxLength !== undefined && value.length > schema.maxLength) return false;
        if (schema.pattern && !new RegExp(schema.pattern, "u").test(value)) return false;
    }
    if (type === "integer" && ((schema.minimum !== undefined && value < schema.minimum) || (schema.maximum !== undefined && value > schema.maximum))) return false;
    if (type === "array") {
        if ((schema.minItems !== undefined && value.length < schema.minItems) || (schema.maxItems !== undefined && value.length > schema.maxItems)) return false;
        if (schema.items && !value.every(v => valid(v, schema.items))) return false;
    }
    if (type === "object") {
        for (const key of schema.required || []) if (value[key] === undefined) return false;
        for (const key in schema.properties || {}) if (value[key] !== undefined && !valid(value[key], schema.properties[key])) return false;
    }
    return true;
}

console.log("ThemeFile.js");

test("a whole theme is read with its name and settings", () => {
    const r = T.parse(file({ author: " Ada ", description: "Mine." }));
    check("ok", [r.ok, r.error], [true, ""]);
    check("name, author, description", [r.theme.name, r.theme.author, r.theme.description], ["Mine", "Ada", "Mine."]);
    check("every setting", r.theme.style, STYLE);
    check("written and read back", T.parse(T.stringify("Mine", "Ada", "Mine.", STYLE)).theme, r.theme);
    check("the written text names the schema first", JSON.parse(T.stringify("Mine", "", "", STYLE)).schema, 1);
    check("no empty author or description is written", Object.keys(JSON.parse(T.stringify("Mine", " ", "", STYLE))), ["schema", "name", "style"]);
});

test("unknown fields are left out, missing ones are allowed", () => {
    const r = T.parse(JSON.stringify({ schema: 1, name: "Small", extra: { run: "rm -rf" }, style: { opacity: 50, script: "x", qml: "import QtQuick", image: "data:…" } }));
    check("ok", r.ok, true);
    check("only what is known", r.theme.style, { opacity: 50 });
    check("no author", [r.theme.author, r.theme.description], ["", ""]);
});

test("what is not a theme is refused", () => {
    const refused = [
        ["broken JSON", '{"schema": 1, "name": "x", "style": {', "json", ""],
        ["not JSON at all", "import QtQuick\nItem {}", "json", ""],
        ["an array", "[1, 2]", "object", ""],
        ["a number", "7", "object", ""],
        ["no schema version", JSON.stringify({ name: "x", style: {} }), "schema", ""],
        ["a text as version", file({ schema: "1" }), "schema", ""],
        ["version 0", file({ schema: 0 }), "schema", ""],
        ["a newer version", file({ schema: 2 }), "newer", ""],
        ["no name", JSON.stringify({ schema: 1, style: {} }), "name", ""],
        ["an empty name", file({ name: "   " }), "name", ""],
        ["a name of 61 characters", file({ name: "x".repeat(61) }), "name", ""],
        ["a name with a line break", file({ name: "a\nb" }), "name", ""],
        ["a number as author", file({ author: 5 }), "field", "author"],
        ["a description of 301 characters", file({ description: "x".repeat(301) }), "field", "description"],
        ["no style", JSON.stringify({ schema: 1, name: "x" }), "field", "style"],
        ["a list as style", file({ style: [] }), "field", "style"],
        ["opacity 101", styled({ opacity: 101 }), "field", "style.opacity"],
        ["opacity as text", styled({ opacity: "82" }), "field", "style.opacity"],
        ["opacity 50.5", styled({ opacity: 50.5 }), "field", "style.opacity"],
        ["scale 300", styled({ scale: 300 }), "field", "style.scale"],
        ["blur as a number", styled({ blur: 1 }), "field", "style.blur"],
        ["an unknown material", styled({ material: "wood" }), "field", "style.material"],
        ["an unknown preset", styled({ preset: "neon" }), "field", "style.preset"],
        ["a colour name", styled({ background: "red" }), "field", "style.background"],
        ["a short colour", styled({ control: "#fff" }), "field", "style.control"],
        ["accent as text colour", styled({ text: "accent" }), "field", "style.text"],
        ["one gradient colour", styled({ gradientStops: ["#102030"] }), "field", "style.gradientStops"],
        ["four gradient colours", styled({ gradientStops: ["#102030", "#102030", "#102030", "#102030"] }), "field", "style.gradientStops"],
        ["a gradient colour that is none", styled({ gradientStops: ["#102030", "url(x)"] }), "field", "style.gradientStops"],
        ["a conic gradient", styled({ gradientType: "conic" }), "field", "style.gradientType"],
        ["angle 361", styled({ gradientAngle: 361 }), "field", "style.gradientAngle"]
    ];
    for (const [what, text, error, field] of refused) {
        const r = T.parse(text);
        check(what, [r.ok, r.error, r.field, r.theme], [false, error, field, null]);
    }
    check("too large", T.parse(file({ description: "x" }) + " ".repeat(T.MAX_BYTES)).error, "size");
    check("not a text", T.parse(undefined).error, "json");
});

test("the JSON Schema file says the same as the island's own check", () => {
    const samples = [file({}), file({ author: "A", description: "D" }), JSON.stringify({ schema: 1, name: "Small", style: {} }),
        file({ schema: 2 }), file({ schema: "1" }), file({ name: "" }), file({ name: "   " }), file({ name: "x".repeat(61) }), file({ author: 5 }),
        JSON.stringify({ schema: 1, name: "x" }), file({ style: [] }), styled({ opacity: 101 }), styled({ opacity: "82" }), styled({ opacity: 50.5 }),
        styled({ offsetX: -100 }), styled({ offsetX: -101 }), styled({ blur: 1 }), styled({ material: "wood" }), styled({ preset: "neon" }),
        styled({ background: "accent" }), styled({ background: "red" }), styled({ text: "" }), styled({ text: "accent" }), styled({ borderColor: "#ABCDEF" }),
        styled({ gradientStops: ["#102030"] }), styled({ gradientStops: ["#102030", "#405060", "#708090"] }), styled({ gradientStops: ["#102030", "x"] }),
        styled({ gradientType: "radial" }), styled({ gradientType: "conic" }), styled({ gradientAngle: 360 }), styled({ gradientAngle: 361 }),
        styled({ unknown: { anything: true } }), styled({ shadow: 3 }), styled({ borderWidth: 0 }), styled({ fill: "image" })];
    for (const text of samples) check(text.slice(0, 70), valid(JSON.parse(text), SCHEMA), T.parse(text).ok);
    check("the presets", SCHEMA.properties.style.properties.preset.enum, T.PRESETS);
    check("every field is in the schema", Object.keys(SCHEMA.properties.style.properties).sort(), T.FIELDS.slice().sort());
});

test("names: one theme, one file", () => {
    check("slug", [T.slug("Gün Batımı 2"), T.slug("  My  Theme!! "), T.slug("İÇ ÖĞÜŞ"), T.slug("../../etc/passwd"), T.slug("日本")],
          ["gun-batimi-2", "my-theme", "ic-ogus", "etc-passwd", "theme"]);
    check("slug is short", T.slug("x".repeat(200)).length, 48);
    check("the same name", [T.sameName(" Aurora", "aurora "), T.sameName("Aurora", "Aurora 2")], [true, false]);
});

test("SHA-256 and UTF-8", () => {
    const sha = bytes => crypto.createHash("sha256").update(Buffer.from(bytes)).digest("hex");
    check("empty", T.sha256([]), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    check("abc", T.sha256([0x61, 0x62, 0x63]), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    let seed = 7;
    for (const length of [1, 55, 56, 57, 63, 64, 65, 119, 120, 1000, 4097, 70000]) {
        const bytes = new Uint8Array(length);
        for (let i = 0; i < length; ++i) { seed = (seed * 1103515245 + 12345) & 0x7fffffff; bytes[i] = seed & 0xff; }
        check(length + " bytes", T.sha256(bytes), sha(bytes));
    }
    const text = "Gün Batımı — 日本 🌅 \u0000";
    check("encode", T.utf8Encode(text), Array.from(Buffer.from(text, "utf8")));
    check("decode", T.utf8Decode(Buffer.from(text, "utf8")), text);
    for (const bad of [[0xff], [0xc3], [0xc3, 0x28], [0xe2, 0x82], [0xc0, 0xaf], [0xed, 0xa0, 0x80], [0xf5, 0x80, 0x80, 0x80]])
        check("not UTF-8: " + bad.map(b => b.toString(16)).join(" "), T.utf8Decode(bad), null);
});

test("the catalog's list: only whole entries, paths stay inside themes/", () => {
    const sha = "a".repeat(64);
    const entry = changes => Object.assign({ id: "mine", name: "Mine", path: "themes/mine.islandtheme.json", sha256: sha }, changes);
    const index = themes => T.parseIndex(JSON.stringify({ schema: 1, themes: themes }));
    check("a whole entry", index([entry({ author: "A", description: "D", preview: { fill: "solid", background: "#102030", junk: 1 } })]).themes,
          [{ id: "mine", name: "Mine", author: "A", description: "D", path: "themes/mine.islandtheme.json", sha256: sha, preview: { fill: "solid", background: "#102030" } }]);
    const left = ["../secret.islandtheme.json", "themes/../../x.islandtheme.json", "/etc/passwd", "https://example.org/x.islandtheme.json",
                  "themes/a/b.islandtheme.json", "themes/x.json", "themes/.islandtheme.json", "themes\\x.islandtheme.json"];
    for (const p of left) check("path " + p, index([entry({ path: p })]).themes.length, 0);
    check("no checksum", index([entry({ sha256: "abc" })]).themes.length, 0);
    check("a bad id", index([entry({ id: "My Theme" })]).themes.length, 0);
    check("the same id twice", index([entry({}), entry({ name: "Other" })]).themes.length, 1);
    check("an upper-case checksum", index([entry({ sha256: "A".repeat(64) })]).themes[0].sha256, sha);
    check("a preview that is not a style is no preview", index([entry({ preview: { opacity: "x" } })]).themes[0].preview, {});
    check("not JSON", T.parseIndex("<html>").error, "json");
    check("no list", T.parseIndex("{}").error, "object");
    check("a newer list", T.parseIndex(JSON.stringify({ schema: 9, themes: [] })).error, "newer");
    check("too large", T.parseIndex(" ".repeat(T.MAX_INDEX_BYTES + 1)).error, "size");
});

test("the catalog address is a placeholder until it is set", () => {
    check("the placeholder", [T.CATALOG_URL, T.configured(T.CATALOG_URL)], ["https://raw.githubusercontent.com/OWNER/REPOSITORY/BRANCH/catalog", false]);
    check("an address", [T.configured("https://raw.githubusercontent.com/someone/plasma-island/main/catalog"), T.configured("http://127.0.0.1:8123"), T.configured(""), T.configured("ftp://x")],
          [true, true, false, false]);
});

test("catalog/ in this repository: every theme valid, every checksum right", () => {
    const dir = path.join(ROOT, "catalog");
    const list = T.parseIndex(fs.readFileSync(path.join(dir, "index.json"), "utf8"));
    check("the list", [list.ok, list.themes.length >= 4], [true, true]);
    check("nothing was left out", list.themes.length, JSON.parse(fs.readFileSync(path.join(dir, "index.json"), "utf8")).themes.length);
    check("every file is listed", list.themes.map(t => path.basename(t.path)).sort(), fs.readdirSync(path.join(dir, "themes")).sort());
    for (const entry of list.themes) {
        const bytes = fs.readFileSync(path.join(dir, entry.path));
        check(entry.id + ": checksum", T.sha256(bytes), entry.sha256);
        check(entry.id + ": size", bytes.length <= T.MAX_BYTES, true);
        const theme = T.parse(T.utf8Decode(bytes));
        check(entry.id + ": valid", [theme.ok, theme.error], [true, ""]);
        check(entry.id + ": the schema agrees", valid(JSON.parse(bytes.toString("utf8")), SCHEMA), true);
        check(entry.id + ": name", theme.theme.name, entry.name);
    }
    check("gradient themes are among them", list.themes.filter(t => t.preview.fill === "gradient").length >= 4, true);
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
