.pragma library
// SPDX-License-Identifier: GPL-2.0-or-later
//
// rclone as the Cloud tab uses it: the arguments of every command, what its
// answers mean, and the names it returns made safe to show. No QML in here:
// tests/rclone.test.js runs it with node, tests/tst_cloud.qml with the real
// command.
//
// A command is always a list of arguments (no shell is involved anywhere).
// A remote is only ever one that `rclone listremotes` named; it and the path
// go as ONE argument, "remote:path", after a "--", so no file name can be
// taken for an option, however it begins. Only `copyto` and `copy` write,
// with --ignore-existing unless the user chose to overwrite; nothing here
// can delete, move or sync. rclone's configuration file is never read by the
// island: only the command is asked.

// Short waits: an island must not hang on a cloud. No prompt can ever appear. rclone's own low-level
// retries stay as they are (10): a cloud that says "too many requests" (Google Drive does, on the
// client id rclone shares among its users) is asked again by rclone itself, a little later each time.
const QUIET = ["--retries", "1", "--contimeout", "10s", "--timeout", "30s", "--ask-password=false"];
const MAX_ENTRIES = 2000;

function remotesArguments() { return ["listremotes", "--json"]; }
// [{ name, type }] of `rclone listremotes --json`.
function parseRemotes(text) {
    let list;
    try { list = JSON.parse(text); } catch (e) { return []; }
    if (!Array.isArray(list)) return [];
    return list.filter(r => r && typeof r.name === "string" && validName(r.name))
               .map(r => ({ name: r.name, type: String(r.type || "") }));
}
// A remote's name as rclone allows it; anything else is never put into a command.
function validName(name) {
    return typeof name === "string" && /^[A-Za-z0-9_][A-Za-z0-9_ .+@-]{0,99}$/.test(name);
}
function known(name, remotes) {
    return validName(name) && remotes.some(r => r.name === name);
}
// "a//b/../c/" → "a/c": inside the remote, never above it.
function cleanPath(path) {
    const out = [];
    for (const part of String(path || "").split("/")) {
        if (part === "" || part === ".") continue;
        if (part === "..") out.pop(); else out.push(part);
    }
    return out.join("/");
}
function join(path, name) { return cleanPath(path).length > 0 ? cleanPath(path) + "/" + name : name; }
function target(remote, path) { return remote + ":" + cleanPath(path); }

function listArguments(remote, path) { return ["lsjson", "--no-mimetype"].concat(QUIET, ["--", target(remote, path)]); }
function aboutArguments(remote) { return ["about", "--json"].concat(QUIET, ["--", remote + ":"]); }
function sizeArguments(remote, path) { return ["size", "--json"].concat(QUIET, ["--", target(remote, path)]); }
// Progress is asked for as a line of JSON twice a second.
const PROGRESS = ["--stats", "500ms", "--use-json-log", "--stats-log-level", "NOTICE", "--retries", "1", "--contimeout", "10s", "--ask-password=false"];
// To this computer: `local` is the full path of the file (or, for a folder, of the folder) to make.
function downloadArguments(remote, path, local, folder) {
    return [folder ? "copy" : "copyto", "--ignore-existing"].concat(PROGRESS, ["--", target(remote, path), local]);
}
// To the cloud. Never over a file that is there, unless the user said so.
function uploadArguments(local, remote, path, folder, overwrite) {
    return [folder ? "copy" : "copyto"].concat(overwrite ? [] : ["--ignore-existing"], PROGRESS, ["--", local, target(remote, path)]);
}
// Shown to be copied when a sign-in has run out; never run from here.
function reconnectCommand(remote) { return "rclone config reconnect " + remote + ":"; }

// A name is somebody else's text: shown as plain characters, without control
// characters, and not longer than a line can take.
function display(name) {
    const s = String(name === undefined || name === null ? "" : name).replace(/[\u0000-\u001f\u007f-\u009f\u2028\u2029\u202a-\u202e\u2066-\u2069]/g, "\ufffd");
    return s.length > 160 ? s.slice(0, 110) + "…" + s.slice(-40) : s;
}
// { entries: [{ name, shown, dir, size, modified (ms) }], more }: one level, at most MAX_ENTRIES.
function parseList(text) {
    let list;
    try { list = JSON.parse(text); } catch (e) { return null; }
    if (!Array.isArray(list)) return null;
    const entries = [];
    for (const item of list) {
        if (!item || typeof item.Name !== "string" || item.Name.length === 0 || item.Name.indexOf("/") >= 0) continue;
        if (entries.length >= MAX_ENTRIES) return { entries: entries, more: true };
        const dir = item.IsDir === true;
        entries.push({ name: item.Name, shown: display(item.Name), dir: dir, size: dir ? -1 : Number(item.Size),
                       modified: Date.parse(item.ModTime || "") || 0 });
    }
    return { entries: entries, more: false };
}
// "b2" before "b10", capitals beside their small letters (the island's own: not every engine's localeCompare counts).
function natural(a, b) {
    const parts = s => String(s).toLocaleLowerCase().match(/\d+|\D+/g) || [];
    const x = parts(a), y = parts(b);
    for (let i = 0; i < Math.min(x.length, y.length); ++i) {
        const n = /^\d/.test(x[i]) && /^\d/.test(y[i]);
        const d = n ? Number(x[i]) - Number(y[i]) : x[i].localeCompare(y[i]);
        if (d !== 0) return d;
    }
    return x.length - y.length;
}
// Folders first; by "name", "date" or "size".
function sorted(entries, key, descending) {
    const by = key === "date" ? (a, b) => a.modified - b.modified
             : key === "size" ? (a, b) => a.size - b.size
             : (a, b) => natural(a.name, b.name);
    return entries.slice().sort((a, b) => (a.dir === b.dir ? 0 : a.dir ? -1 : 1) || (descending ? -by(a, b) : by(a, b)) || a.name.localeCompare(b.name));
}
function filtered(entries, query) {
    const q = String(query || "").trim().toLocaleLowerCase();
    return q.length === 0 ? entries : entries.filter(e => e.name.toLocaleLowerCase().indexOf(q) >= 0);
}
// A theme icon by the name's ending: never by what is in the file.
function icon(entry) {
    if (entry.dir) return "folder";
    const ext = (/\.([A-Za-z0-9]{1,6})$/.exec(entry.name) || ["", ""])[1].toLowerCase();
    const kinds = { "image-x-generic": "png jpg jpeg gif webp svg heic bmp tiff", "video-x-generic": "mp4 mkv mov avi webm", "audio-x-generic": "mp3 flac ogg wav m4a opus",
                    "application-pdf": "pdf", "x-office-document": "doc docx odt rtf", "x-office-spreadsheet": "xls xlsx ods csv", "x-office-presentation": "ppt pptx odp",
                    "package-x-generic": "zip tar gz xz bz2 7z rar zst", "text-x-script": "sh py js ts c cpp h rs go java qml", "text-x-generic": "txt md json xml yaml yml log ini conf" };
    for (const name in kinds) if (kinds[name].split(" ").indexOf(ext) >= 0) return name;
    return "text-x-generic";
}

// { used, total, free } in bytes (each -1 when the cloud does not say); null when it says nothing at all.
function parseAbout(text) {
    let o;
    try { o = JSON.parse(text); } catch (e) { return null; }
    if (o === null || typeof o !== "object") return null;
    const n = v => typeof v === "number" && v >= 0 ? v : -1;
    const about = { used: n(o.used), total: n(o.total), free: n(o.free) };
    if (about.total < 0 && about.used >= 0 && about.free >= 0) about.total = about.used + about.free;
    if (about.used < 0 && about.total >= 0 && about.free >= 0) about.used = about.total - about.free;
    return about.used < 0 && about.total < 0 ? null : about;
}
// 0..100, or -1 when the cloud gives no total.
function fullness(about) { return about && about.total > 0 && about.used >= 0 ? Math.min(100, 100 * about.used / about.total) : -1; }
// "ok" | "warning" | "critical" | "unknown"
function storageLevel(about, warning, critical) {
    const p = fullness(about);
    return p < 0 ? "unknown" : p >= critical ? "critical" : p >= warning ? "warning" : "ok";
}
function parseSize(text) {
    let o;
    try { o = JSON.parse(text); } catch (e) { return null; }
    return o && typeof o.count === "number" && typeof o.bytes === "number" ? { count: o.count, bytes: o.bytes } : null;
}
// One line of a running copy → { bytes, total, speed, eta, percent } or null (another line).
function parseProgress(line) {
    let o;
    try { o = JSON.parse(line); } catch (e) { return null; }
    const s = o && o.stats;
    if (!s || typeof s.bytes !== "number") return null;
    const total = Number(s.totalBytes) || 0;
    return { bytes: s.bytes, total: total, speed: Number(s.speed) || 0, eta: typeof s.eta === "number" ? s.eta : -1,
             percent: total > 0 ? Math.min(100, 100 * s.bytes / total) : -1 };
}
// The message of a log line, JSON or plain ("2026/10/04 17:34:52 NOTICE: …").
function logMessage(line) {
    try { const o = JSON.parse(line); if (o && typeof o.msg === "string" && !o.stats) return o.level === "notice" || o.level === "error" || o.level === "critical" ? o.msg : ""; if (o && o.stats) return ""; } catch (e) {}
    return String(line).replace(/^\d{4}\/\d\d\/\d\d \d\d:\d\d:\d\d\s+(NOTICE|ERROR|CRITICAL|INFO|DEBUG)\s*:\s*/, "");
}

// What went wrong, from the exit code and what the command wrote:
//   missing  the command is not there        auth     the sign-in has run out or is refused
//   network  no connection / unreachable     notfound the folder or file is gone
//   denied   not allowed                      remote   rclone does not know this remote
//   timeout  no answer in time                full     the cloud has no room left
//   busy     the cloud is asked too often right now (a rate limit, not a full cloud)
//   unknown  anything else (detail: rclone's own last words, without addresses of this computer)
function problem(exitCode, errors) {
    const lines = String(errors || "").split("\n").map(logMessage).map(l => l.trim()).filter(l => l.length > 0);
    const last = lines.length > 0 ? lines[lines.length - 1] : "";
    const all = lines.join("\n");
    const is = re => re.test(all);
    let kind = "unknown";
    if (exitCode < 0 && last.length === 0) kind = "timeout";
    else if (is(/didn't find section in config file|is not a known remote/i)) kind = "remote";
    else if (is(/invalid_grant|token (has )?expired|expired token|couldn't fetch token|failed to (refresh|get) token|unauthori[sz]ed|\b401\b|re-?authori[sz]e|config reconnect|invalid_client|AuthenticationFailed|login failed/i)) kind = "auth";
    else if (is(/storageQuotaExceeded|storage (quota|limit)|insufficient storage|\b507\b|no space left|over quota/i)) kind = "full";
    else if (is(/rateLimitExceeded|RATE_LIMIT_EXCEEDED|quota exceeded for quota metric|too many requests|\b429\b|slow ?down/i)) kind = "busy";
    else if (is(/no such host|connection refused|network is unreachable|no route to host|dial tcp|i\/o timeout|context deadline exceeded|TLS handshake|connection reset|temporary failure in name resolution/i)) kind = "network";
    else if (exitCode === 3 || exitCode === 4 || is(/directory not found|object not found|file not found/i)) kind = "notfound";
    else if (is(/permission denied|\b403\b|forbidden|access denied|: permission\b/i)) kind = "denied";
    // rclone's own words are only shown for what has no sentence of its own, and never a path of this computer
    const detail = kind !== "unknown" ? "" : last.replace(/(^|[\s"'(=:])\/[^\s"':]+/g, "$1…").slice(0, 200);
    return { kind: kind, detail: detail };
}

// "report.pdf" among taken names → "report (1).pdf".
function uniqueName(name, taken) {
    const has = n => taken.indexOf(n) >= 0;
    if (!has(name)) return name;
    const dot = name.lastIndexOf(".");
    const stem = dot > 0 ? name.slice(0, dot) : name, ext = dot > 0 ? name.slice(dot) : "";
    for (let i = 1; i < 10000; ++i) if (!has(stem + " (" + i + ")" + ext)) return stem + " (" + i + ")" + ext;
    return stem + " (" + Date.now() + ")" + ext;
}
// The last part of a local path or file:// address; "" for what is no local file.
function localPath(url) {
    const s = String(url || "");
    if (s.indexOf("file://") === 0) { try { return decodeURIComponent(s.slice(7)); } catch (e) { return ""; } }
    return s.charAt(0) === "/" ? s : "";
}
function baseName(path) { return String(path || "").replace(/\/+$/, "").split("/").pop(); }
function fileUrl(path) { return "file://" + String(path).split("/").map(encodeURIComponent).join("/"); }

// An alert is said again only after its pause (hours), and never while it is the same and fresh.
function due(lastAt, now, pauseHours) { return !(lastAt > 0) || now - lastAt >= pauseHours * 3600000; }

// Sync states every status source is turned into.
const STATES = ["synced", "syncing", "paused", "error", "offline", "unknown"];
// Syncthing: /rest/db/completion → { completion, needBytes }, /rest/system/connections, folder errors.
function syncthingState(completion, paused, errors, reachable) {
    if (!reachable) return { state: "offline", progress: -1 };
    if (errors > 0) return { state: "error", progress: -1 };
    if (paused) return { state: "paused", progress: -1 };
    const c = Number(completion);
    if (!(c >= 0)) return { state: "unknown", progress: -1 };
    return c >= 100 ? { state: "synced", progress: 1 } : { state: "syncing", progress: c / 100 };
}
// `dropbox status` prints a few words.
function dropboxState(code, text) {
    const t = String(text || "").trim();
    if (/isn't running|not running/i.test(t)) return { state: "offline", progress: -1 };
    if (code !== 0 || t.length === 0) return { state: "unknown", progress: -1 };
    if (/up to date/i.test(t)) return { state: "synced", progress: 1 };
    if (/paused/i.test(t)) return { state: "paused", progress: -1 };
    if (/can't|cannot|error|couldn't|full|denied/i.test(t)) return { state: "error", progress: -1 };
    if (/connecting|starting/i.test(t)) return { state: "offline", progress: -1 };
    if (/sync|upload|download|index/i.test(t)) return { state: "syncing", progress: -1 };
    return { state: "unknown", progress: -1 };
}
// rclone mounts in /proc/mounts: [{ remote, path }] ("remote:path /mount/point fuse.rclone …").
function mounts(text) {
    const out = [];
    for (const line of String(text || "").split("\n")) {
        const m = /^(\S+?):(\S*) (\S+) fuse\.rclone /.exec(line);
        if (m) out.push({ remote: m[1], path: m[3].replace(/\\040/g, " ") });
    }
    return out;
}
