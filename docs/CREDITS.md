# Credits and licences

The island itself is licensed under the GNU General Public License, version 2
or (at your option) any later version (`GPL-2.0-or-later`); every source file
says so in its first lines, and the licence's text is in
[`LICENSE`](../LICENSE). What it ships of others, and what it talks to:

## Shipped in this repository

| What | Where | From | Licence |
|---|---|---|---|
| ical.js 1.5.0 with three changes, each marked "Local change" in the file: reads calendar files | `contents/ui/backend/IcsWorker.js` (above the marked banner; the island's own glue is below it) | [kewisch/ical.js](https://github.com/kewisch/ical.js), © Philipp Kewisch and contributors | MPL-2.0 (`contents/ui/backend/IcsWorker.LICENSE.ical.js`) |
| Weather pictures | `contents/icons/weather/*.svg`, drawn through `contents/ui/WeatherIcons.js` | [Lucide](https://lucide.dev); some of them come from [Feather](https://feathericons.com) | ISC (Lucide), MIT (the Feather ones); both texts in `contents/icons/weather/LICENSE` |
| The AI tab's "sparkles" | `contents/icons/ai/sparkles*.svg` | Lucide | ISC (`contents/icons/ai/LICENSE`) |
| The marks of Apple, Google, Joplin and Simplenote | `contents/icons/{apple,google,joplin,simplenote}.svg` | [Simple Icons](https://simpleicons.org) 16.33.0 | CC0-1.0. The marks are trademarks of their owners; they only label the calendar options and the note sources of those names. The island is not affiliated with or endorsed by any of them. |
| The BetterNotes icon | `contents/icons/betternotes.svg` | [BetterNotes](https://github.com/thebanri/BetterNotes) | MIT; it only labels that note source |
| The calculator icon | `contents/icons/calculator-symbolic.svg` | drawn for this widget | GPL-2.0-or-later |

The six themes in `catalog/themes/` are the project's own (their `author`
says "Dynamic Island"); a theme is data: colours and numbers.

## Used at run time, not shipped

| What | For | Licence / terms |
|---|---|---|
| KDE Plasma, KDE Frameworks, Qt | The desktop the island is a widget of | LGPL / GPL (their own) |
| [Open-Meteo](https://open-meteo.com) | Weather data and place search, once a place is chosen | Data under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): "Weather data by Open-Meteo.com". Free for non-commercial use, without a key. |
| rclone, BetterNotes, Joplin, Simplenote, Memos, KDE Connect, Claude Code, Antigravity, Ollama and the other model servers, btop | Optional: each is used only if you installed and connected it | Their own |

## The clips in the README

- The **music** and the **covers** in them were made for this project by
  `tools/demo/make-media`: sums of sine waves with a drum on the beat, and
  gradients with a few shapes. The track, artist and album names are made up.
  Nobody else's work is in them; they are released under CC0-1.0.
- The **wallpaper** is one plain colour.
- Notifications, calendar events, notes, files, a cloud's folders and the AI's
  answers in the clips are made up by the scripts in `tools/demo/`. The AI
  answers come from a local stand-in server with canned answers, not from a
  real model.
- The weather shown is Open-Meteo's for a large city chosen for the demo, not
  the author's place.
