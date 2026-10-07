# Architecture, tests and translations

How the island is put together and how it is checked. What it does, feature by feature, is in
[REFERENCE.md](REFERENCE.md).

## Activities, priority, pages and the wheel

Every feature is an independent *provider* (`contents/ui/providers/`).
Providers send the `ActivityManager` an **ongoing activity** (`Activity`, in
the island for as long as it lasts) or a **momentary event** (`flash()`, a few
seconds). Default priority (can be changed in Settings → Activities):

`privacy > call > screen recording > momentary events > timer/Pomodoro/calendar > file jobs/custom activities > media > idle`

An activity whose category is not in this list ranks below all of them: the
habits' waiting evening review does, so it only shows when nothing else does
(or as the second, split-off activity).

- Momentary events temporarily cover an ongoing activity of lower priority.
  While a higher one is shown (e.g. screen recording) they wait in a queue;
  waiting events older than 30 s are dropped. An incoming call overrides this
  rule.
- Several momentary events are queued; events of the same kind (e.g. volume)
  are merged into one.
- Events wait while the island is expanded. Instant feedback such as
  volume/brightness does not wait; it is skipped.
- The split island shows the two highest-priority ongoing activities. If
  playing media does not make the top two (e.g. with two timers running) the
  album art takes the circle on the right; this can be turned off with "Keep
  playing media visible".

**Why a paged layout?** Stacking four modules turns the island into a panel
about 360 px tall that covers the top of the screen. With pages the island
always keeps the same compact size (~430×207) and feels like a single "card",
as on iOS (one page asks for more room: the year of the Habits calendar widens
it to ~650 px for as long as it is shown). Pages are switched with the tabs, the mouse wheel or a touchpad
swipe (see "The wheel" below). When the island opens, the Media page is shown if media is playing,
otherwise the System page. The System page only shows status; everything
adjustable (volume, brightness, buttons) is on the Controls page.

**The wheel.** A scroll belongs to what it began over, from its first step to
its last:

- Over a list (a conversation, a text, a grid) that has more than fits, it
  scrolls that list and nothing else: at the list's end too, and however
  often one scrolls on from there, the page is not turned. A list inside
  another keeps its scroll from the outer one in the same way.
- Over anything else it turns the page: the tabs and the header (always),
  empty room, a page's buttons, a list short enough to fit. So no page can
  hold one: the tabs are always there. One scroll turns one page, however
  far the wheel is spun or the fingers go, and what is left of it does not
  scroll the page arrived at; less than a notch of a wheel, or ~40 px of a
  touchpad, turns nothing.
- A list takes the scroll of its own direction: a sideways swipe over a list
  that goes up and down turns the page. A row that only goes sideways (the
  clouds, the path of a folder) takes the wheel too and is moved by it: a
  mouse has no other way to scroll it.
- A slider takes the wheel over it (a notch is 5 %) and gives none away; a
  list's scroll that passes under the pointer does not move it.

"One scroll" is steps with no more than 350 ms between them: a wheel says
nothing of where a scroll begins or ends. The rules and their numbers are in
one place, `ScrollGesture.qml`; every list is an `IslandFlickable`,
`IslandListView` or `IslandGridView` (an `IslandScroll` inside it asks
`ScrollGesture` whose scroll it is), which `tools/scroll-check` verifies and
`tests/tst_scroll.qml` tests, with a mouse's wheel and with a touchpad's
steps. To watch who gets each step:

```bash
QT_LOGGING_RULES="island.wheel.debug=true" plasmashell --replace   # or: journalctl --user -f | grep island.wheel
```

## Architecture

```
org.phobby.dynamicisland/
├── metadata.json
├── contents/config/{main.xml, config.qml}
└── contents/ui/
    ├── main.qml               PlasmoidItem, the always-on-top Dialog, backend Loaders, providers
    ├── ActivityManager.qml    ongoing activities + priority + momentary event queue
    ├── Activity.qml           one live activity (minimal / compact / expanded)
    ├── Island.qml             state machine, morph, split island, privacy dots
    ├── ExpandedContent.qml    tabs + pages
    ├── PlasmaBackend.qml      ┐ private Plasma/KDE APIs ONLY in
    ├── backend/*.qml          ┘ these two places (each optional through a Loader)
    ├── providers/*.qml        every feature: Media, Notification, Power, Bluetooth, Osd,
    │                          Keyboard, Network, Dnd, Recording, Privacy, Jobs, Timer,
    │                          Stopwatch, Pomodoro, Alarm, Habits, Suggestion, Calendar, KdeConnect,
    │                          Thermal, Updates, Dbus, Unlock; for transfers
    │                          KdeConnectTransfer, RemovableTransfer, BrowserDownload
    ├── TransferActivity.qml, TransferHub.qml, TransfersCard.qml   shared transfer activity
    ├── Styles.qml                 the looks: presets and a custom style as data (singleton)
    ├── ThemeFile.js, ThemeLibrary.qml, ThemeStore.qml, Theme*Dialog.qml, ThemePreview.qml
    │                              theme files: format and checks, the user's themes, the store
    ├── Theme.qml, IslandShape.qml, ActivityCompact/Minimal/Card.qml, EventBanner.qml,
    │   BatteryGlyph.qml, MiniRing.qml, …        shared visual language
    ├── *Module.qml, *Page.qml                    expanded pages
    ├── Calendar*.qml                             calendar page, connect wizard, accounts, new event
    ├── NotesPage.qml                             notes list, quick note, editor, connecting apps
    ├── ClipboardPage.qml                         clipboard history: copy again, search, star, edit, QR
    ├── HabitsPage.qml, Habits.js                 habits: checklist, calendar, review; the record's rules
    ├── Suggestions.js, Suggestion*.qml           suggestions: what is learned, the question's banner, the rules' names, the file
    ├── AiPage.qml, AiMarkdown.js, AiDots.qml     the AI tab: conversation, connecting; an answer made ready to be shown
    ├── CloudPage.qml, cloud/Rclone.js            the Cloud tab: folders by name, drag out, drop in; rclone's commands and answers
    ├── cloud/CloudProvider.qml, cloud/RcloneProvider.qml, cloud/*Status.qml
    │                                             what a cloud is, rclone as one, sync state from Syncthing and Dropbox
    ├── ai/AiProvider.qml, ai/AiCatalog.qml       what every source of answers is, and the kinds there are
    ├── ai/ClaudeCli*.{js,qml}, ai/HttpProvider.qml, ai/OpenAiProvider.qml, ai/AnthropicProvider.qml, ai/AiStream.js
    │                                             the sources: Claude Code, OpenAI-compatible servers, the Anthropic API
    ├── NativeBridge.qml, BlurBridge.qml          import the native modules
    ├── Lang.qml, translations/tr.js, qmldir      the widget's own translations (singleton)
    ├── PageCatalog.qml                           the expanded pages and their default order
    ├── ControlCatalog.qml                        the buttons the Controls page can show (at most 6)
    ├── AmbientGlow.qml, AlbumColor.qml           the glow: cover colour, music, bass pops
    └── config*.qml                                settings pages (configLayout: page order)
native/
├── windowblur.*               org.phobby.dynamicisland.effects (shaped KWin blur)
└── core/                      org.phobby.dynamicisland.core:
                               PipeWireWatcher, DBusSignalWatcher, Launcher,
                               UpdatesChecker, DownloadWatcher, SecretStore,
                               LoopbackServer, LocalTools (commands, SQLite, small files), PopupWatcher,
                               AudioLevels, StreamProcess (a command read while it runs),
                               IslandService (D-Bus API)
catalog/                       the theme store: index.json, themes/*.islandtheme.json, the JSON Schema
tools/island-push, tools/notify-done.sh, tools/i18n-check, tools/habits-test, tools/catalog-update,
tools/weather-icons, tools/ai-cli-check, tools/scroll-check
tools/cat-poses, tools/cat-measure   the cat: its pose gallery as pictures; what it costs in the running shell
tools/run-tests                every check that needs no running island: the texts, the rules (node), tests/
tests/tst_*.qml                QML tests under qmltestrunner, off screen (habits provider, appearance…)
```

**Adding a new feature:** write a file under `providers/`. Define an
`Activity { … Component.onCompleted: manager.register(this) }` in it and/or
call `manager.flash({ icon, color, title, subtitle, trailing })`. Then add the
provider to the `providers` block in `main.qml`. If you do not want the
default compact/minimal/expanded views, give the `compact`, `minimal` and
`expanded` properties your own `Component`.

**Privacy and screen recording detection:** the native `PipeWireWatcher`
listens to the output of `pw-dump --monitor`, event-driven (no polling).
Microphone: a running capture stream linked to a real `Audio/Source` (level
meters and apps capturing desktop audio do not count). Camera: a stream
consuming a v4l2/libcamera device node. Screen: a stream consuming a video
source that is not a device (KWin/portal screen cast). plasmashell's own
window previews do not count.

**Window strategy (b: a single frameless Dialog):** desktop widgets stay
below windows. With a panel plus a separate popup (a), the small pill and the
large card are two different windows and the morph animation breaks at the
window switch. So the island is drawn in a single `PlasmaCore.Dialog`:
`type: Notification` + `WindowDoesNotAcceptFocus` (always on top, never steals
focus), `NoBackground` (we draw the surface ourselves). The position is set
with `x/y`. On Wayland plasmashell's plasma-shell protocol does this; Plasma's
own notification popups use the same method. The window only has two sizes
(small pill / large card). The morph animation plays *inside* the window; the
window is not resized on every frame. Once the shrink animation ends the
window shrinks.

**Blur:** KWin only blurs the region a window asks for. `PlasmaQuick::Dialog`
computes this region from the SVG mask of the theme frame and it cannot be
changed from QML (verified in `libPlasmaQuick`). For a pill-shaped region the
small module under `native/` calls
`KWindowEffects::enableBlurBehind(window, true, roundedRegion)` and updates the
region along with the animation. If the module is not installed
`BlurBridge.qml` fails to load and the surface falls back to semi-opaque metal.

**Performance:** the only thing running when idle is the clock timer, which
wakes once a minute. Sensors (`Sensor.enabled`) are only active while the
System page is visible, the player position query only while the Media page is
visible and playing. Equalizer animations stop when not visible. Pages that
are not visible are not loaded; the notification list is only bound to the
model while visible.

**Private APIs:** `org.kde.plasma.private.mpris`,
`org.kde.plasma.private.volume`, `org.kde.plasma.private.battery`,
`org.kde.notificationmanager` and `org.kde.ksysguard.sensors` are used only in
`PlasmaBackend.qml`; `org.kde.plasma.private.batterymonitor`,
`org.kde.bluezqt`, `org.kde.plasma.private.brightnesscontrolplugin`,
`org.kde.plasma.private.keyboardindicator`,
`org.kde.plasma.workspace.keyboardlayout`, `org.kde.plasma.networkmanagement`,
`org.kde.taskmanager`, `org.kde.plasma.workspace.calendar`,
`org.kde.plasma.private.clipboard` and
`org.kde.kdeconnect` only under `backend/`. Providers and views only see the
normalised properties of these files. If a Plasma update changes an API, this
is the place to fix.

## Testing and debugging

```bash
# Standalone preview (plasma-sdk package):
sudo apt install plasma-sdk
plasmoidviewer -a org.phobby.dynamicisland

# Without plasma-sdk, using the tool that ships with plasma-workspace:
plasmawindowed org.phobby.dynamicisland

# Trying the native helper from the build directory without installing it:
QML_IMPORT_PATH=$PWD/native/build/qml plasmawindowed org.phobby.dynamicisland

# Logs inside plasmashell:
journalctl --user -f | grep -iE "dynamicisland|qml"
```

Note: `plasmawindowed`/`plasmoidviewer` run in a separate process. The
notification and job services belong to plasmashell, so notifications and file
jobs are **not shown** in this mode (the message `Failed to register
Notification service on DBus` is normal). Try those in the real environment
(with the widget added in plasmashell).

`tools/run-tests` runs every check that needs no running island: the texts
(`tools/i18n-check --strict`), the theme catalog and the weather pictures,
what scrolls (`tools/scroll-check`),
the rules written in JavaScript under node (habits, theme files, weather
data, suggestions) and the QML tests in `tests/` under `qmltestrunner`, off
screen: providers and pages with stand-ins for what they watch, the settings
pages as they are, the theme store and the weather against answers served on
127.0.0.1. No test reads or changes the system's clock: what depends on time
takes the day or the moment as an argument. Tests that need the native
module use the one in `native/build` and are skipped without it. The steps
of a touchpad's scroll (pixels, the phases of a scroll) cannot be made by
QtTest: `tests/helper` sends them, a small module `tools/run-tests` builds
into `tests/.run`.

The AI tab is tested the same way, without asking anybody: `tests/ai-server.py`
stands in for the services (an OpenAI-compatible one and the Anthropic API:
streams, a wrong key, limits, a cut connection, no answer at all) and
`tests/fake-claude` for the `claude` command. `tools/ai-cli-check` is not part
of `tools/run-tests`: it asks the real Claude Code through the tab's own
provider (see "AI" below) and spends a little of the account's usage.

### Testing module by module

| Module | How to trigger it |
|---|---|
| Notification | `notify-send "Test" "Hello"` · several: `for i in 1 2 3; do notify-send "Test $i"; done` |
| Do Not Disturb | The moon button on the Controls page, or notifications → Do Not Disturb in the system tray; while on, `notify-send` is not shown, and the missed count appears when it is turned off |
| Media | Play something in Spotify/Elisa/a browser; `playerctl play-pause` |
| Volume / output device | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+` · `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle` · change the output device |
| Brightness | The slider on the Controls page; brightness keys (laptop) or a monitor with DDC support |
| Charging / battery | Plug and unplug the charger on a laptop (the module is hidden on a desktop) |
| Power profile | `powerprofilesctl set performance` → `powerprofilesctl set balanced` |
| Bluetooth | `bluetoothctl connect <MAC>` / `bluetoothctl disconnect <MAC>` |
| Keyboard | Caps Lock / Num Lock keys; layout change: `qdbus6 org.kde.keyboard /Layouts org.kde.KeyboardLayouts.switchToNextLayout` |
| Wi-Fi / VPN | `nmcli radio wifi off/on` · `nmcli connection up <vpn>` / `down` · hotspot: `nmcli device wifi hotspot` |
| Screen recording | Screen recording with Spectacle, OBS, screen sharing in a browser |
| Microphone | `pw-record /tmp/test.wav` (stop with Ctrl+C) |
| Camera | A camera app (e.g. Kamoso) or a camera test in a browser |
| Unlock | `loginctl lock-session`, then unlock |
| File job | Copy a large file with Dolphin or extract an archive with `ark --batch` (`kioclient` does not use the job tracker and is not shown) |
| Download | Download a large file in a browser (Flatpak/Snap browsers only show size and speed) |
| Timer etc. | Expanded → Tools page (a 1-minute timer is the quickest test) |
| Weather | Expanded → Weather page: "Choose a Location", type a city, pick it; hover a day, click it for its hours, the arrow goes back. Settings → Weather: units |
| Notes, carrying on | Open a note on the Notes page, move the pointer away so the island closes, open it again: the same note's editor. Lock a note in BetterNotes (0.1.15+): the page asks for the master password, then shows the note |
| Themes | Settings → Appearance → Custom: a gradient under Fine tuning; "Export Theme…", then "Add New…" → From a File with that file. The store needs its address first (see "Themes: files and the store") |
| AI | Settings → Layout: switch "AI" on. Expanded → AI page: "Claude Code" (found by itself when installed and signed in), ask something; move the pointer away while it answers, press Escape and leave: three dots, then "Answer ready". `tools/ai-cli-check --user-memory --trace` for the checks with the real command |
| Cloud | Needs `rclone` with at least one remote (`rclone config`). Settings → Layout: switch "Cloud" on. Expanded → Cloud page: go into a folder, rest the pointer on a small file and drag it to the desktop, drop a file on the list. Without rclone the page shows how to install it |
| Suggestions | Start a screen recording (Spectacle, OBS): the question with its three answers. Settings → Suggestions shows what each rule learned |
| Habits | Expanded → Habits page: add habits, tick some; set the review time in Settings → Habits to a minute from now for the evening question. Its rules are checked without the clock: `tools/habits-test` |
| Clipboard | Copy a text, a piece of code and an image (e.g. a Spectacle screenshot); they appear on the Clipboard page, a click copies one again |
| Notes | Start Joplin, enable its Web Clipper service, paste the token on the island's Notes page; add a quick note and check that it appears in Joplin |
| Calendar | Connect a calendar on the island's Calendar page (gear button), create an event 20 minutes from now; it is pinned to the island 15 minutes before |
| KDE Connect | `kdeconnect-cli --list-devices` · `kdeconnect-cli -d <id> --ping` · send a file from the phone / call the phone |
| Updates | Controls page; compare with `pkcon get-updates` |
| Temperature | Lower the threshold in Settings → Alerts (e.g. 50 °C) |
| Custom activity | `island-push --id demo --title "Demo" --progress 30` → `island-push --id demo --done --status success` |

## Translations

Every visible text is an English source string passed to `Lang.i18n()`,
`Lang.i18nc()` or `Lang.i18np()` (same arguments as KDE's i18n functions) and
looked up in `contents/ui/translations/<language>.js`, a key-value table
(`tr.js`: Turkish). `Lang.qml` is a QML singleton; the language is the
widget's `language` setting, and bindings that call `Lang` are re-evaluated
when it changes. Month and day names, date/time formats and percentages
(`Lang.locale`, `Lang.percent()`) follow it too.

KDE's own i18n (gettext `.po`/`.mo`) or Qt's `qsTr()` with `.ts`/`.qm` files
were not used: both choose the language for the whole plasmashell process,
so this widget could not have a language of its own nor switch it without a
restart, and a `QTranslator` installed in plasmashell would also translate
other widgets' strings that happen to be the same.

`tools/i18n-check` lists texts missing from a table, entries no longer used,
and multi-word string literals outside `Lang` calls (possibly forgotten
text); `--strict` makes it fail when something is missing. To add a
language, copy `tr.js`, translate the values and add it to `tables` in
`Lang.qml`.
