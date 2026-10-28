// SPDX-License-Identifier: GPL-2.0-or-later
// feedback-relay — what Cloudflare runs: the island's feedback (relay.mjs has the rules) passed
// on to the author's Telegram. Only the default export here: the runtime takes every export of
// this module for a handler. Setup: README.md beside this file.
import { handle } from "./relay.mjs";

// About one message a minute from one address (Cloudflare's limiter counts roughly: tried on
// 2026-10-28, four quick ones passed and the fifth was refused): the rate limiting binding (LIMITER in
// wrangler.toml) where it is there, else Cloudflare's cache of this data centre (which does
// nothing on a *.workers.dev address: there the binding is what limits).
async function limited(env, key) {
    if (env.LIMITER && typeof env.LIMITER.limit === "function") {
        const { success } = await env.LIMITER.limit({ key });
        return !success;
    }
    if (typeof caches === "undefined") return false;
    const mark = new Request("https://feedback-relay.invalid/limit/" + encodeURIComponent(key));
    if (await caches.default.match(mark)) return true;
    await caches.default.put(mark, new Response("1", { headers: { "Cache-Control": "max-age=60" } }));
    return false;
}

export default {
    async fetch(request, env) {
        return handle(request, env, { fetch: (u, o) => fetch(u, o), limited: key => limited(env, key) });
    }
};
