// SPDX-License-Identifier: GPL-2.0-or-later
// feedback-relay — what Cloudflare runs: the island's feedback (relay.mjs has the rules) passed
// on to the author's Telegram. Only the handler and the counter's class are exported here: the
// runtime takes every export of this module for one of those. Setup: README.md beside this file.
import { handle, take, count } from "./relay.mjs";

// How many messages were sent in the last hour, for one name ("sender:<address>" or "total"): a
// Durable Object, which Cloudflare runs one request at a time per name, so the count is exact
// (its rate limiting binding counts roughly, and per minute at most). It keeps only those times,
// and forgets them an hour after the last one.
export class FeedbackLimit {
    constructor(state) {
        this.state = state;
    }
    async fetch(request) {
        return count(this.state.storage, request.url, Date.now());
    }
    async alarm() {
        await this.state.storage.deleteAll();
    }
}

export default {
    async fetch(request, env) {
        return handle(request, env, { fetch: (u, o) => fetch(u, o), take: who => take(env, who) });
    }
};
