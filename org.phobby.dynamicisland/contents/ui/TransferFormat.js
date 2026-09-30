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

function bytes(b) {
    const units = ["B", "KB", "MB", "GB", "TB"];
    let v = Math.max(0, b), i = 0;
    while (v >= 1024 && i < units.length - 1) { v /= 1024; ++i; }
    return (i === 0 ? Math.round(v) : v.toFixed(v >= 10 ? 0 : 1)) + " " + units[i];
}
