# Changelog

## Unreleased
<!-- TODO(owner): the version number and date of this release. -->

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

### Changed
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
- `README.tr.md`, `docs/REFERENCE.md`, `docs/ARCHITECTURE.md`,
  `docs/PERFORMANCE.md`, `docs/CREDITS.md`, `SECURITY.md`.

Earlier changes are in the git history.
