#!/usr/bin/env node
// Settings › Diagnostics › Feedback (contents/ui/Feedback.js): what is sent, only what the user
// wrote and chose; what an answer means; which addresses are sent to. Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const F = load(path.join(UI, "Feedback.js"));

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
const meta = { island: "0.2.2", language: "tr", session: "Wayland" };

test("what is sent: the text, a way to answer, the version", () => {
    const p = F.payload("  Lovely notch \r\n ", " @someone ", false, "the report", meta);
    check("ok", p.ok, true);
    check("body", p.body, { message: "Lovely notch", contact: "@someone", report: "", island: "0.2.2", language: "tr", session: "Wayland" });
});

test("the report only when it was ticked", () => {
    check("ticked", F.payload("hi", "", true, "Dynamic Island diagnostics", meta).body.report, "Dynamic Island diagnostics");
    check("not ticked", F.payload("hi", "", false, "Dynamic Island diagnostics", meta).body.report, "");
    check("cut at the limit", F.payload("hi", "", true, "r".repeat(F.MAX_REPORT + 50), meta).body.report.length, F.MAX_REPORT);
});

test("nothing to send, or too much", () => {
    check("empty", F.payload("   ", "x", false, "", meta), { ok: false, error: "empty", body: null });
    check("too long", F.payload("x".repeat(F.MAX_MESSAGE + 1), "", false, "", meta).error, "long");
    check("just at the limit", F.payload("x".repeat(F.MAX_MESSAGE), "", false, "", meta).ok, true);
    check("contact cut", F.payload("hi", "c".repeat(500), false, "", meta).body.contact.length, F.MAX_CONTACT);
    check("control characters", F.payload("a\u0000b\u001bc", "", false, "", meta).body.message, "abc");
});

test("the preview is the body that is sent", () => {
    const body = F.payload("hi", "", false, "", meta).body;
    check("same", JSON.parse(F.preview(body)), body);
    check("nothing", F.preview(null), "");
});

test("what an answer means", () => {
    check("200", F.outcome(200), "sent");
    check("429", F.outcome(429), "busy");
    check("400", F.outcome(400), "refused");
    check("413", F.outcome(413), "refused");
    check("0 (no connection)", F.outcome(0), "failed");
    check("502", F.outcome(502), "failed");
    check("500", F.outcome(500), "failed");
});

test("where it may be sent", () => {
    check("none", F.usable(""), false);
    check("https", F.usable("https://island-feedback.someone.workers.dev"), true);
    check("plain http elsewhere", F.usable("http://example.org/"), false);
    check("this computer", F.usable("http://127.0.0.1:47391/"), true);
    check("not an address", F.usable("javascript:alert(1)"), false);
});

if (failed > 0) { console.log(failed + " of " + checked + " checks failed"); process.exit(1); }
console.log(checked + " checks passed");
