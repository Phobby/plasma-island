#!/usr/bin/env node
// An answer of the AI tab made ready to be shown (contents/ui/AiMarkdown.js):
// cut into text and code blocks, pictures and HTML taken out.
// Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const M = load(path.join(UI, "AiMarkdown.js"));

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

test("an answer cut into text and code", () => {
    check("plain", M.segments("Hello\nworld"), [{ code: false, text: "Hello\nworld" }]);
    check("empty", M.segments(""), []);
    check("text, code, text", M.segments("Run this:\n\n```bash\nls -la\necho hi\n```\n\nDone."),
          [{ code: false, text: "Run this:" }, { code: true, text: "ls -la\necho hi", lang: "bash", open: false }, { code: false, text: "Done." }]);
    check("still being written", M.segments("```python\nprint(1)\npri"), [{ code: true, text: "print(1)\npri", lang: "python", open: true }]);
    check("only the fence so far", M.segments("See:\n```"), [{ code: false, text: "See:" }, { code: true, text: "", lang: "", open: true }]);
    check("tildes, a longer closing fence", M.segments("~~~\na\n~~~~"), [{ code: true, text: "a", lang: "", open: false }]);
    check("a shorter fence inside stays", M.segments("````md\n```js\nx\n```\n````"), [{ code: true, text: "```js\nx\n```", lang: "md", open: false }]);
    check("two blocks", M.segments("```\na\n```\n```\nb\n```").map(s => s.text), ["a", "b"]);
    check("inline code is no fence", M.segments("```not a fence``` here"), [{ code: false, text: "```not a fence``` here" }]);
    check("the language is one plain word", M.segments("```c++ {.numberLines}\nx\n```")[0].lang, "c++");
    check("Windows line ends", M.segments("a\r\n```\r\nb\r\n```\r\n").map(s => s.text), ["a", "b"]);
});

test("an answer made harmless", () => {
    check("a picture becomes a link", M.safe("Look ![cat](http://example.org/cat.png)!"), "Look [cat](http://example.org/cat.png)!");
    check("a picture by reference", M.safe("![cat][1]\n\n[1]: http://example.org/c.png"), "[cat][1]\n\n[1]: http://example.org/c.png");
    check("HTML is shown, not made", M.safe("<img src=\"http://example.org/x.png\"> <b>bold</b> a < b"), "&lt;img src=\"http://example.org/x.png\"> &lt;b>bold&lt;/b> a &lt; b");
    check("inline code as it is", M.safe("Use `a<b` and ``x ` ![y](z) <i>`` now <i>"), "Use `a<b` and ``x ` ![y](z) <i>`` now &lt;i>");
    check("a backtick alone", M.safe("5` < 6 ![a](b)"), "5` &lt; 6 [a](b)");
    check("nothing to change", M.safe("**bold** and [a link](https://example.org)"), "**bold** and [a link](https://example.org)");
    check("web links only", ["https://example.org/a?b=1", "http://example.org", "file:///etc/passwd", "javascript:alert(1)", "mailto:a@b.c", "https://exa mple.org", ""].map(M.webLink),
          ["https://example.org/a?b=1", "http://example.org", "", "", "", "", ""]);
    check("first line", M.firstLine("\n## The **answer** is `42`\nmore", 40), "The answer is 42");
    check("first line: a list, a link", M.firstLine("- see [the docs](https://x.org) now", 40), "see the docs now");
    check("first line: code only", M.firstLine("```\ncode\n```", 40), "code");
    check("first line: cut", M.firstLine("abcdefghijklmnopqrstuvwxyz", 10), "abcdefghi…");
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
