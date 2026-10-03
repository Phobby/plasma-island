/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The colour of an album cover, for the ambient glow. The cover is drawn
    at 16×16 into a canvas (and dropped right after) and its 256 pixels are sorted into 12 hue bins weighted by saturation ×
    brightness, so grey and dark pixels count little; the colour is the mean
    of the heaviest bin. A plain average was tried first: it turns most
    covers into a muddy brown-grey. Grey covers fall back to the average.
    The result is moved into a usable range in HSL (saturation at least 0.5,
    lightness 0.5–0.65; grey covers become a soft silver), so the glow is
    neither invisible on black nor glaring on white.
    Each cover is analysed once; the result is cached by its URL.
*/
import QtQuick

Item {
    id: album

    property url source
    // The usable glow colour of `source`; `fallback` until it is known.
    property color fallback: "#c8ccd4"
    readonly property color color: known ? found : fallback
    property color found: fallback
    property bool known: false

    property var cache: ({})
    width: 16
    height: 16
    opacity: 0              // only painted to read the pixels

    onSourceChanged: {
        const key = String(source);
        if (key.length === 0) { known = false; return; }
        if (cache[key] !== undefined) { found = cache[key]; known = true; return; }
        known = false;
        if (loading.length > 0) canvas.unloadImage(loading);
        loading = key;
        if (canvas.isImageLoaded(key)) canvas.requestPaint(); else canvas.loadImage(key);
    }

    // The canvas loads the cover itself (drawing an Image item into it gives
    // nothing), draws it at 16×16, reads the pixels and drops the image again.
    property string loading: ""
    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        onImageLoaded: requestPaint()
        onPaint: {
            const url = album.loading;
            if (url.length === 0 || !isImageLoaded(url)) return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, 16, 16);
            ctx.drawImage(url, 0, 0, 16, 16);
            const c = album.analyse(ctx.getImageData(0, 0, 16, 16).data);
            unloadImage(url);
            album.loading = "";
            album.cache[url] = c;
            if (url === String(album.source)) { album.found = c; album.known = true; }
        }
    }

    function analyse(px: var): color {
        const bins = [];
        for (let i = 0; i < 12; ++i) bins.push({ w: 0, r: 0, g: 0, b: 0 });
        let n = 0, ar = 0, ag = 0, ab = 0;
        for (let i = 0; i < px.length; i += 4) {
            if (px[i + 3] < 128) continue;
            const r = px[i] / 255, g = px[i + 1] / 255, b = px[i + 2] / 255;
            ar += r; ag += g; ab += b; ++n;
            const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
            const sat = max > 0 ? d / max : 0;
            if (max < 0.05 || sat < 0.2) continue;            // grey or black
            let h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
            h = (h * 60 + 360) % 360;
            // saturation × √value: dark but clearly coloured covers still count
            const w = sat * Math.sqrt(max);
            const bin = bins[Math.floor(h / 30) % 12];
            bin.w += w; bin.r += r * w; bin.g += g * w; bin.b += b * w;
        }
        if (n === 0) return fallback;
        const best = bins.reduce((a, b) => b.w > a.w ? b : a);
        const colourful = best.w > n * 0.02;
        const base = colourful ? Qt.rgba(best.r / best.w, best.g / best.w, best.b / best.w, 1) : Qt.rgba(ar / n, ag / n, ab / n, 1);
        // into a usable range
        if (!colourful || base.hslSaturation < 0.12) return Qt.hsla(0, 0, 0.78, 1);
        return Qt.hsla(Math.max(0, base.hslHue), Math.max(0.5, base.hslSaturation), Math.min(0.65, Math.max(0.5, base.hslLightness)), 1);
    }
}
