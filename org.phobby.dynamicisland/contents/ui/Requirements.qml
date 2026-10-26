/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Whether what a feature needs is there (RequirementCatalog.qml), looked for
    once and kept for a while: a missing command is not looked for again each
    time a page opens or a status is polled. `recheck()` forgets everything
    (the "Check again" buttons); after `keepFor` it is looked for again the
    next time it is asked. Nothing is polled.

    `find(local, id)` → { found, path, via, given, givenUsable, native }:
    `local` is the native module's LocalTools (root.core.local in the island,
    a LocalBridge of its own in the settings window); without it nothing can be
    looked for (native: false). Commands are looked for where the native
    module looks (the PATH, the user's own folders, AppImages, a path set by
    hand first: native/core/userpaths.h).

    In the island, main.qml sets `openSettings` (target: "<page>:<id>"): the
    cards' "Set the path by hand" opens the settings there.
*/
pragma Singleton
import QtQuick

QtObject {
    id: state

    property int keepFor: 5 * 60 * 1000
    // Raised by recheck(): bindings that call find() look again.
    property int generation: 0
    property var cache: ({})
    property var openSettings: null
    // Whether the native module is there (main.qml): a path given by hand needs it.
    property bool nativeAvailable: true

    function recheck(): void {
        cache = ({});
        ++generation;
    }
    function find(local: var, id: string): var {
        void generation;
        const item = RequirementCatalog.item(id);
        if (item === null) return { found: false, path: "", via: "", native: local !== null && local !== undefined };
        if (id === "native") return { found: local !== null && local !== undefined, path: "", via: "", native: local !== null && local !== undefined };
        if (local === null || local === undefined || typeof local.findExecutable !== "function")
            return { found: false, path: "", via: "", native: false };
        const now = Date.now(), kept = cache[id];
        if (kept && now - kept.at < keepFor) return kept;
        let out = { found: false, path: "", via: "", given: "", givenUsable: false, native: true, at: now };
        for (const command of item.commands || []) {
            // (a native module from before locate(): only where it is)
            const where = typeof local.locate === "function" ? local.locate(command, "", false)
                                                             : { path: local.findExecutable(command), via: "" };
            out.given = String(where.given || out.given);
            out.givenUsable = where.givenUsable === true || out.givenUsable;
            if (String(where.path || "").length > 0) { out.found = true; out.path = String(where.path); out.via = String(where.via || ""); break; }
        }
        // (kept without telling anyone: a binding that asked must not be asked again for it)
        cache[id] = out;
        return out;
    }
}
