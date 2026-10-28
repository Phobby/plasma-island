# Feedback relay

Where Settings → Diagnostics → **Feedback** is sent. A [Cloudflare Worker](https://developers.cloudflare.com/workers/)
(`worker.mjs`, its rules in `relay.mjs`) takes what a user wrote and passes it on to your Telegram chat through a bot of
your own. The bot's token and your chat's id are the Worker's secrets: they are never in the
island, whose code anybody can read.

What it takes is one `POST /` with a JSON body `{ message, contact, report, island, language,
session }`, made by `contents/ui/Feedback.js` (at most 2000 characters of text, 120 of contact,
12000 of report). It sends the text as plain text, and the diagnostics report, when the user
ticked it, as a file `diagnostics.txt` in reply to it. About one message a minute from one address
(Cloudflare's limiter counts roughly: a few quick ones can pass before it closes; the island
itself sends at most one a minute);
nothing is kept or logged. Its tests: `tests/feedbackrelay.test.js`, and `tests/tst_feedback.qml`
runs the island's form against it (with a stand-in Telegram).

## Setting it up

You need a Telegram account, a free Cloudflare account and Node.js (for `npx wrangler`).

1. **The bot.** In Telegram, open **@BotFather**, send `/newbot`, give it a name and a user name
   ending in `bot`. BotFather answers with a **token** like `123456789:AA…`. Keep it to
   yourself.
2. **Your chat's id.** Open your new bot in Telegram and send it any message (`/start`). Then:

   ```bash
   curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates"
   ```

   The number at `"chat":{"id": …}` is your chat's id. (A group works too: add the bot to it,
   write there, and take that chat's id, which starts with `-`.)
3. **The Worker.** In this folder:

   ```bash
   cd tools/feedback-relay
   npx wrangler login                 # once, in the browser
   npx wrangler deploy                # prints its address: https://island-feedback.<you>.workers.dev
   npx wrangler secret put BOT_TOKEN  # paste the token
   npx wrangler secret put CHAT_ID    # paste the chat's id
   ```

   Until both secrets are there it answers 500 and sends nothing.
4. **Try it:**

   ```bash
   curl -s -X POST https://island-feedback.<you>.workers.dev/ \
        -H 'Content-Type: application/json' -d '{"message":"Hello from curl"}'
   ```

   It answers `{"ok":true}` and the message is in your chat. A few more within a minute
   answers 429.
5. **The island.** Put the address into `FEEDBACK_URL` in
   `org.phobby.dynamicisland/contents/ui/Project.js`, then run `tools/run-tests`, commit and push.
   Islands installed from then on (and updated to the next version) have the Feedback form;
   until then the page offers GitHub's issues instead.

## If something goes wrong

- **The token got out, or the bot is flooded:** in @BotFather, `/mybots` → the bot → *API
  Token* → *Revoke current token*, then `npx wrangler secret put BOT_TOKEN` with the new one.
  Islands need no change: they never had the token.
- **Too many messages:** the limit is in `wrangler.toml` (`[[ratelimits]]`, about one a minute from
  one address). Anybody can still write to the address; a new Worker name (a new address in
  `FEEDBACK_URL`) shuts out what keeps coming to the old one.
- **Nothing arrives:** `npx wrangler tail` shows each request's answer while you try again
  (502: Telegram did not take it, usually a wrong token or chat id; 500: a secret is missing).
