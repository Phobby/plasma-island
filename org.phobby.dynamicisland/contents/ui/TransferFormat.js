// SPDX-License-Identifier: GPL-2.0-or-later
// Helpers shared by the transfer providers: which provider owns a KDE job,
// and human names for its endpoints.
.pragma library

const BROWSERS = ["firefox", "zen", "chromium", "chrome", "google-chrome", "brave", "vivaldi",
                  "opera", "microsoft-edge", "librewolf", "floorp", "waterfox", "falkon", "epiphany"];

function lower(s) { return String(s || "").toLowerCase(); }

// "/media/user/USB DISK/x", "file:///run/media/user/LABEL/x" → "USB DISK"
function removableLabel(pathOrUrl) {
    const s = decodeURIComponent(String(pathOrUrl || "").replace(/^file:\/\//, ""));
    const m = s.match(/^\/(?:run\/)?media\/[^\/]+\/([^\/]+)/);
    return m ? m[1] : "";
}

function isBrowser(info) {
    const a = lower(info.app), d = lower(info.desktopEntry);
    return BROWSERS.some(b => a.indexOf(b) >= 0 || d.indexOf(b) >= 0);
}
function isKdeConnect(info) {
    return lower(info.app) === "kde connect" || lower(info.desktopEntry).indexOf("kdeconnect") >= 0;
}

// Exactly one provider claims each job, in this order.
function classify(info) {
    if (isKdeConnect(info)) return "kdeconnect";
    if (removableLabel(info.value1) || removableLabel(info.value2) || removableLabel(info.destUrl)) return "removable";
    if (isBrowser(info)) return "browser";
    return "kio";
}

// Last path component of a path / URL ("…/film.mkv" → "film.mkv").
function baseName(pathOrUrl) {
    const s = decodeURIComponent(String(pathOrUrl || "").replace(/\/+$/, ""));
    const i = s.lastIndexOf("/");
    return i >= 0 ? s.slice(i + 1) : s;
}
function folderName(pathOrUrl) {
    const s = decodeURIComponent(String(pathOrUrl || "").replace(/^file:\/\//, "").replace(/\/+$/, ""));
    const parts = s.split("/");
    return parts.length > 1 ? parts[parts.length - 2] || "/" : s;
}

// Source / destination field of a KDE job (labels are translated, so match loosely).
function field(info, kind) {
    const src = /source|from|kaynak|origin|url/i, dst = /destination|to$|to:|hedef|target|folder/i;
    const re = kind === "source" ? src : dst;
    if (re.test(info.label1)) return info.value1;
    if (re.test(info.label2)) return info.value2;
    return kind === "source" ? info.value1 : info.value2;
}

// 95 → "1:35"
function eta(seconds) {
    if (!(seconds > 0) || !isFinite(seconds)) return "";
    const s = Math.ceil(seconds), m = Math.floor(s / 60), ss = s % 60;
    return m + ":" + (ss < 10 ? "0" : "") + ss;
}

// 432013312 → "412 MB"; 1932735283 → "1.8 GB", or "1,8 GB" with `comma` (Turkish).
function bytes(b, comma) {
    const units = ["B", "KB", "MB", "GB", "TB"];
    let v = Math.max(0, b), i = 0;
    while (v >= 1024 && i < units.length - 1) { v /= 1024; ++i; }
    const number = i === 0 ? String(Math.round(v)) : v.toFixed(v >= 10 ? 0 : 1);
    return (comma ? number.replace(".", ",") : number) + " " + units[i];
}

// 8 → "0:08", 95 → "1:35", 3725 → "1:02:05"
function duration(seconds) {
    if (!(seconds >= 0) || !isFinite(seconds)) return "";
    const s = Math.round(seconds), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), ss = s % 60;
    const two = n => (n < 10 ? "0" : "") + n;
    return h > 0 ? h + ":" + two(m) + ":" + two(ss) : m + ":" + two(ss);
}

// An exponential moving average: the speed shown does not jump with every sample.
function smooth(previous, sample, weight) {
    const w = weight > 0 && weight <= 1 ? weight : 0.3;
    return previous > 0 ? previous * (1 - w) + sample * w : sample;
}

// The commands looked for by default: name → what it is. `actions`: only these sub-commands
// are downloads ("apt list" is not); none: every run.
const COMMANDS = [
    { name: "apt", kind: "packages", actions: ["update", "upgrade", "full-upgrade", "dist-upgrade", "install", "reinstall", "download", "source", "build-dep"] },
    { name: "apt-get", kind: "packages", actions: ["update", "upgrade", "dist-upgrade", "install", "reinstall", "download", "source", "build-dep"] },
    { name: "aptitude", kind: "packages", actions: ["update", "upgrade", "safe-upgrade", "full-upgrade", "install", "reinstall", "download"] },
    { name: "unattended-upgr", kind: "packages", actions: [] },
    { name: "git", kind: "clone", actions: ["clone"] },
    { name: "wget", kind: "download", actions: [] },
    { name: "curl", kind: "download", actions: [] },
    { name: "aria2c", kind: "download", actions: [] },
    { name: "yt-dlp", kind: "download", actions: [] },
    { name: "pip", kind: "download", actions: ["install", "download", "wheel"] },
    { name: "pip3", kind: "download", actions: ["install", "download", "wheel"] },
    { name: "npm", kind: "download", actions: ["install", "i", "ci", "update", "add"] },
    { name: "cargo", kind: "download", actions: ["install", "build", "fetch", "update", "run"] },
    { name: "docker", kind: "download", actions: ["pull"] },
    { name: "flatpak", kind: "download", actions: ["install", "update"] },
    { name: "snap", kind: "download", actions: ["install", "refresh"] }
];

// The table the watcher is given: the defaults of the kinds that are switched on, without the
// names in `removed`, with the user's own (`added`: "name" per line; they count as downloads).
function commandTable(packages, clone, tools, added, removed) {
    const names = text => String(text || "").split(/[\n,]/).map(s => s.trim()).filter(s => /^[A-Za-z0-9._+-]{1,40}$/.test(s));
    const out = [], gone = names(removed);
    for (const c of COMMANDS) {
        if (gone.indexOf(c.name) >= 0) continue;
        if (c.kind === "packages" ? packages : c.kind === "clone" ? clone : tools) out.push(c);
    }
    if (tools) for (const n of names(added)) if (!out.some(c => c.name === n) && !COMMANDS.some(c => c.name === n)) out.push({ name: n, kind: "download", actions: [] });
    return out;
}
