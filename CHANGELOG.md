# Changelog

## 0.1.0 (2026-10-08)

The first numbered release.

### Fixed
- **A title or a name could make the shell fetch an address.** A notification's
  title (also a track's, a file's, a network's name) that said
  `<img src="http://…">` was read as rich text, and plasmashell fetched it.
  Every text the island shows is now plain text unless the island wrote its
  markup itself; `tools/text-check` keeps it so.
- **BetterNotes was listed again and again, for ever.** With BetterNotes
  connected `betternotes list` ran every 0.8 s as long as the shell ran: every
  listing changed the watched folder (SQLite's `-wal` file), which called for
  the next one. The notes are now listed again only when the database itself
  changed.
- **Without PipeWire, `pw-dump` was started every three seconds** (and
  `pw-record` every two, with the glow on). The pause now grows up to five
  minutes.
- KDE Connect: a warning at every start of the shell (a binding on a device's
  icon) is gone.
- `install.sh --remove` also removes the empty folders of the native module.
- **A calendar link could send any amount, for any time.** A link now may
  send up to 10 MB and take up to 30 seconds; a larger or slower one is not
  read, the settings page says which link and why, and the calendar keeps its
  last good copy. The check when a link is connected holds the same limits.

### Changed
- **Suggestions are off until you switch them on** (Settings → Suggestions);
  they were on by default. Nothing is suggested and nothing learned before.
- **The theme store has its address**: the `catalog/` folder of this
  repository's `main` branch. It was a placeholder, with which the store
  asked nothing.
- The outline of where the island takes clicks is switched on only by
  `DYNAMICISLAND_DEBUG_REGION=1` in the shell's environment; the hidden
  setting `debugInputRegion` is gone.
- Removed: `RingGauge.qml` and the old PIM calendar backend (nothing loaded
  them), the setting `weatherPlace` (nothing read it).

### Added
- `tools/nested-session`: an isolated Plasma session to try, measure and
  record the island in. `tools/bench`: what the island costs, as CSV, tables
  and pictures (`docs/PERFORMANCE.md`). `tools/demo`: made-up data, music and
  a small MPRIS player for the clips.
- `LICENSE`: the text of the GNU General Public License, version 2 (the
  sources say `GPL-2.0-or-later`).
- `tools/bench/chain`: every measurement in one go, in the background, going
  on where it was cut off.
- `README.tr.md`, `docs/REFERENCE.md`, `docs/ARCHITECTURE.md`,
  `docs/PERFORMANCE.md`, `docs/CREDITS.md`, `SECURITY.md`.
- `tools/link-check` (part of `tools/run-tests`): every link and picture of
  the documents leads to a file and a heading that are there.

Earlier changes are in the git history.
