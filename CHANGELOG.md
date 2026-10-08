# Changelog

## 0.2.2 (2026-10-08)

### Added
- **The settings outlive the widget.** Plasma deletes a widget's settings
  when it is taken off the desktop: put back, the island came as new. The
  settings are now also kept in `~/.local/share/dynamicisland/settings.json`
  (for the owner only), and a widget that is new reads them from there once.
  Delete the file to start from nothing. Needs the native module.
- **Following the system, the fine tuning works.** With *Follow the system*
  every control under it was greyed out. The colours stay Plasma's; opacity,
  blur and its level, place, size, corner roundness, border and shadow are
  now set in that look too, apart from the custom style's.
- `island-update.sh --check` says which version is installed and which is
  the newest. Both READMEs give the commands to check and to update by hand.

## 0.2.1 (2026-10-08)

### Fixed
- **Claude Code and Antigravity were "not found" although installed and
  signed in.** The AI tab looked for `claude` and `agy` on the desktop
  shell's PATH and in `~/.local/bin` only. A shell adds folders to its PATH
  in its own start-up files, which plasmashell never reads: a `claude`
  installed with npm under nvm or fnm, with a prefix of npm's own, with bun,
  Volta, pnpm or Homebrew was there in every terminal and unknown to the
  island, which then only had sources that ask for a key. Those folders are
  looked into now (native/core/userpaths.h; no shell is started to ask), and
  a command found there is started with its own folder first on the PATH, so
  that a script finds the `node` it was installed with. The same search finds
  `rclone`, `ollama` and `betternotes`. Needs the new native module.

## 0.2.0 (2026-10-08)

### Added
- **The island updates itself.** Once a day it reads the newest version number
  from its repository; when there is a newer one it asks on the island.
  *Update* fetches that version from GitHub, builds and installs it and
  restarts the desktop shell, and the island shows how far it is meanwhile.
  Settings and data are kept. Settings → General → *New versions of the
  island*: *Never look*, *Ask me* (as it comes), *Install by itself*. The same
  by hand, without the cloned folder:
  `contents/scripts/island-update.sh latest --restart`. From 0.1.0, update
  once more with `git pull` and `./install.sh`: it has no updater.

### Changed
- **With the settings as they come the island now makes one network request
  a day** (the version number, from `raw.githubusercontent.com`). 0.1.0 made
  none. *Never look* switches it off.

### Fixed
- **Added twice, the island stood there twice.** The widget added a second
  time to one screen (twice to the desktop, to a panel and to the desktop)
  put a second island exactly over the first. They looked like one until one
  of them opened: then the other still stood there as a pill, with a second
  cat. On one screen only the island that came first shows now; the other
  widget's tooltip says why it is hidden. One island per screen stays possible.
- **Following the system, the island could not be moved.** With *Follow the
  system* chosen, *Distance from top* and *Horizontal position* in Settings →
  Appearance were greyed out, and the horizontal position could not be set
  anywhere. Both are set there in both looks now; following the system has a
  place of its own, a custom style keeps its.
- **BetterNotes installed as a Flatpak was not found.** Its menu entry is now
  looked for in Flatpak's folders too; it is started with `flatpak run` and
  its notes are read from the sandbox's folder. (Written from BetterNotes'
  documentation and tried with a stand-in; not tried with the real Flatpak.)
- **"BetterNotes was not found" without the native module.** The island looks
  for BetterNotes through its native module. Where that is not installed the
  Notes page said BetterNotes was missing and showed how to install it; it
  now says that the native module is missing, and how to get it.

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
- **No examples in the fields for a place and for a habit.** The Weather
  page's search says "City", the Habits page's fields "New habit, every day…"
  and "Extra activity…": the island comes with no place and no habit, and
  suggests none.
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
