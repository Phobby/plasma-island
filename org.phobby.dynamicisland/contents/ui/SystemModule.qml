/*
    SPDX-License-Identifier: GPL-2.0-or-later

    System status cards in two layouts (Settings → General → System view):

      fixed    CPU · RAM · Battery (GPU without battery) / Network · Disk,
               3 + 2 cards filling two rows.
      dynamic  a 2 × 4 grid; metrics that are active right now (CPU busy,
               network traffic, charging, …) get large 2-unit cards, calm ones
               small 1-unit cards. Leftover space is handed to the active cards,
               so the rows are always full. Hysteresis keeps it from flapping.
               When fewer than two are active, the busiest calm metrics are
               kept large so two cards always show their details.

    In both layouts the card under the pointer grows by one unit (and shows its
    details); its row neighbours make room. Cards never change rows or order
    on hover, so the hovered card always stays under the pointer.
    The network card grows further: beside the traffic it shows the connection
    the machine is online through (name, IPv4 address, MAC address).

    Sensor polling is gated by PlasmaBackend.systemActive, which the island
    sets only while this page is shown.
*/
import QtQuick

Item {
    id: sys

    required property Theme theme
    required property PlasmaBackend backend
    // backend/NetworkBackend.qml (null without plasma-nm): the connection details.
    property var network: null
    property string mode: "dynamic"

    readonly property real spacing: 6
    implicitHeight: 128

    // Network arc: usage relative to a slowly decaying recent peak.
    readonly property real netTotal: backend.netDownRate + backend.netUpRate
    property real netPeak: 256 * 1024
    onNetTotalChanged: netPeak = Math.max(256 * 1024, netTotal, netPeak * 0.9)

    function levelColor(v: real): color {
        return v > 0.9 ? theme.danger : v > 0.75 ? theme.warning : theme.text;
    }
    function tempColor(c: real): color {
        return c >= 85 ? theme.danger : c >= 72 ? theme.warning : theme.text;
    }

    // ---- activity with hysteresis --------------------------------------------------
    property var activeState: ({})
    function hysteresis(key: string, value: real, on: real, off: real): bool {
        const was = activeState[key] === true;
        const now = was ? value > off : value > on;
        activeState[key] = now;
        return now;
    }

    // Card under the pointer ("" = none).
    property string hoveredKey: ""
    // A card was clicked: key is cpu, temp, gpu, ram, battery, net or disk.
    signal metricClicked(string key)

    // Calm metrics kept large; sticky so two near-equal loads do not keep swapping.
    property var pinState: ({ keys: [] })
    function pinned(calm: var, count: int): var {
        const M = metrics, prev = pinState.keys;
        const rank = k => M[k].score + (prev.includes(k) ? 10 : 0);
        // CPU temperature repeats the CPU card and is always "high": never pinned.
        const keys = calm.filter(k => k !== "temp").sort((a, b) => rank(b) - rank(a)).slice(0, Math.max(0, count));
        pinState.keys = keys;
        return keys;
    }

    // ---- metrics ----------------------------------------------------------------------
    readonly property var metrics: {
        const b = backend, m = {}, link = network?.primary ?? null;
        m.cpu = {
            key: "cpu", caption: Lang.i18nc("@label short for processor", "CPU"),
            value: b.cpuUsage / 100, ringText: Lang.percent(Math.round(b.cpuUsage)), color: levelColor(b.cpuUsage / 100),
            detail: b.cpuTemp > 0 ? Lang.i18n("%1% · %2 °C", Math.round(b.cpuUsage), Math.round(b.cpuTemp)) : Lang.i18n("%1% in use", Math.round(b.cpuUsage)),
            detail2: "", active: hysteresis("cpu", b.cpuUsage, 50, 40), score: b.cpuUsage
        };
        m.temp = {
            key: "temp", caption: Lang.i18nc("@label processor temperature, short", "CPU °C"), available: b.cpuTemp > 0,
            value: b.cpuTemp / 100, ringText: Math.round(b.cpuTemp) + "°", color: tempColor(b.cpuTemp),
            detail: Lang.i18n("%1 °C", Math.round(b.cpuTemp)), detail2: "", active: hysteresis("temp", b.cpuTemp, 80, 74), score: b.cpuTemp
        };
        m.gpu = {
            key: "gpu", caption: Lang.i18nc("@label short for graphics card", "GPU"), available: b.hasGpu,
            value: b.gpuUsage / 100, ringText: Lang.percent(Math.round(b.gpuUsage)),
            color: b.gpuTemp >= 85 ? theme.danger : levelColor(b.gpuUsage / 100),
            detail: b.gpuTemp > 0 ? Lang.i18n("%1% · %2 °C", Math.round(b.gpuUsage), Math.round(b.gpuTemp)) : Lang.i18n("%1% in use", Math.round(b.gpuUsage)),
            detail2: "", active: hysteresis("gpu", b.gpuUsage, 50, 40), score: b.gpuUsage
        };
        m.ram = {
            key: "ram", caption: Lang.i18nc("@label short for memory", "RAM"),
            value: b.memUsage / 100, ringText: Lang.percent(Math.round(b.memUsage)), color: levelColor(b.memUsage / 100),
            detail: b.memTotalBytes > 0 ? b.formatBytes(b.memUsedBytes) + " / " + b.formatBytes(b.memTotalBytes) : Lang.i18n("%1% in use", Math.round(b.memUsage)),
            detail2: "", active: hysteresis("ram", b.memUsage, 80, 75), score: b.memUsage
        };
        m.battery = {
            key: "battery", caption: b.batteryCharging ? Lang.i18n("Charging") : Lang.i18n("Battery"), available: b.hasBattery,
            value: b.batteryPercent / 100, ringText: Lang.percent(b.batteryPercent),
            color: b.batteryCharging ? theme.live : b.batteryPercent <= 20 ? theme.danger : theme.text,
            detail: Lang.percent(b.batteryPercent), detail2: b.batteryCharging ? Lang.i18n("Charging") : b.batteryPluggedIn ? Lang.i18n("Plugged in") : Lang.i18n("On battery"),
            active: b.hasBattery && (b.batteryCharging || b.batteryPercent <= 20), score: b.batteryCharging ? 60 : 100 - b.batteryPercent
        };
        m.net = {
            key: "net", caption: Lang.i18nc("@label network", "Network"),
            value: netTotal / netPeak, ringText: "", color: theme.network,
            detail: "↓ " + b.formatBytes(b.netDownRate) + "/s", detail2: "↑ " + b.formatBytes(b.netUpRate) + "/s",
            smallText: "↓" + b.compactRate(b.netDownRate),
            // shown beside the traffic while the card is hovered
            extra: link ? [link.name, link.ipv4, link.mac].filter(s => s.length > 0) : [],
            active: hysteresis("net", netTotal, 100 * 1024, 40 * 1024), score: Math.min(100, netTotal / 10240)
        };
        m.disk = {
            key: "disk", caption: Lang.i18nc("@label storage", "Disk"),
            value: b.diskUsage / 100, ringText: Lang.percent(Math.round(b.diskUsage)), color: levelColor(b.diskUsage / 100),
            detail: Lang.i18n("%1 free", b.formatBytes(b.diskFreeBytes)),
            detail2: b.diskIoRate > 1024 * 1024 ? Lang.i18n("I/O %1/s", b.formatBytes(b.diskIoRate)) : "",
            active: b.diskUsage > 90 || hysteresis("disk", b.diskIoRate, 20 * 1048576, 8 * 1048576), score: Math.min(100, b.diskIoRate / 1048576)
        };
        // The network ring shows the rate instead of a percentage.
        m.net.ringText = m.net.smallText;
        return m;
    }

    // ---- layout: key → { x, y, w, h, large, shown } --------------------------------------
    readonly property var placement: {
        const W = width, H = height, gap = spacing, M = metrics;
        const out = {};
        for (const k in M) out[k] = { x: 0, y: 0, w: 0, h: 0, large: false, shown: false };
        const rowH = (H - gap) / 2;
        const unit = (W - 3 * gap) / 4;
        const place = (rows) => {
            rows.forEach((row, r) => {
                const units = row.reduce((a, it) => a + it.span, 0);
                // share of the row per unit when the row is not full of 4 units
                const u = (W - gap * (row.length - 1)) / Math.max(1, units);
                let x = 0;
                for (const it of row) {
                    const w = u * it.span;
                    out[it.key] = { x: x, y: r * (rowH + gap), w: w, h: rows.length === 1 ? H : rowH, large: it.large, shown: true };
                    x += w + gap;
                }
            });
        };

        // The hovered card takes one more unit of its own row; one with extra
        // lines (network) takes most of the row.
        const grow = (rows) => {
            for (const row of rows) {
                const it = row.find(it => it.key === hoveredKey);
                if (!it) continue;
                const wide = M[it.key].extra?.length > 0;
                // squeezed neighbours fall back to the small layout
                if (wide) row.forEach(other => other.large = false);
                it.span += wide ? 4 : 1;
                it.large = true;
            }
            return rows;
        };

        if (mode === "fixed") {
            const third = M.battery.available ? "battery" : "gpu";
            place(grow([[{ key: "cpu", span: 1, large: false }, { key: "ram", span: 1, large: false }, { key: third, span: 1, large: false }],
                        [{ key: "net", span: 1, large: true }, { key: "disk", span: 1, large: true }]]));
            return out;
        }

        // dynamic: active first (by score), then the calm ones in a fixed order
        const order = ["cpu", "gpu", "ram", "net", "disk", "battery", "temp"];
        const avail = order.filter(k => M[k].available !== false);
        const active = avail.filter(k => M[k].active).sort((a, b) => M[b].score - M[a].score);
        // At least two large cards, as long as every card still fits in 8 units.
        const pins = pinned(avail.filter(k => !M[k].active), Math.min(2 - active.length, 8 - avail.length - active.length));
        const calm = avail.filter(k => !M[k].active && !pins.includes(k));
        const items = active.concat(pins).map(k => ({ key: k, span: 2, large: true })).concat(calm.map(k => ({ key: k, span: 1, large: false })));
        const rows = [[], []], free = [4, 4];
        for (const it of items) {
            let r = free[0] >= it.span ? 0 : free[1] >= it.span ? 1 : -1;
            if (r < 0 && it.large && (free[0] >= 1 || free[1] >= 1)) {   // shrink to fit
                it.span = 1; it.large = false;
                r = free[0] >= 1 ? 0 : 1;
            }
            if (r < 0) continue;
            rows[r].push(it);
            free[r] -= it.span;
        }
        // Hand leftover units to active cards first (then to any card), so no gaps.
        for (let r = 0; r < 2; ++r) {
            const row = rows[r];
            if (row.length === 0) continue;
            let i = 0;
            while (free[r] > 0) {
                const target = row.find(it => it.large && it.span < 4) ?? row[i % row.length];
                target.span += 1;
                if (target.span >= 2) target.large = true;
                free[r] -= 1;
                ++i;
            }
        }
        place(grow(rows.filter(r => r.length > 0)));
        return out;
    }

    Repeater {
        // Stable keys: cards move/resize (animated) instead of being recreated.
        model: ["cpu", "temp", "gpu", "ram", "battery", "net", "disk"]
        delegate: SystemCard {
            required property string modelData
            readonly property var p: sys.placement[modelData]
            theme: sys.theme
            metric: sys.metrics[modelData]
            large: p.large
            visible: p.shown
            onClicked: sys.metricClicked(modelData)
            onHoveredChanged: {
                if (hovered) sys.hoveredKey = modelData;
                else if (sys.hoveredKey === modelData) sys.hoveredKey = "";
            }
            x: p.x
            y: p.y
            width: p.w
            height: p.h
            Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        }
    }
}
