# Dynamic Island — Plasma 6 plasmoid

A pill-shaped plasmoid that sits at the top centre of the screen and works
like the iOS Dynamic Island. It takes its colours from Plasma, or wears a look
of your own (Settings → Appearance): among others the original metallic glass
inspired by Oxygen (graphite gradient, silver rim, top highlight, inner and
outer shadow), with the background blurred by KWin.

Tested on: Kubuntu, Plasma 6.6.6, Qt 6.10.2, Wayland.

## States

| State | When | Appearance |
|---|---|---|
| Idle | Nothing is going on | Small pill (180×36): clock or status dot; a ⏸ mark when media is paused |
| Live activity (compact) | The highest-priority ongoing activity | Media: album art + track name + equalizer. Others: coloured icon on the left, time/value or progress ring on the right |
| Split island | Two ongoing activities at once | The first in the main pill, the second in a circle that splits off to its right like a droplet (minimal view) |
| Notification | A new notification arrives | App icon (phone badge for KDE Connect), app name, title, first line of the text. Left click runs the default action, middle click dismisses |
| Momentary event | Charging, Bluetooth, volume, Caps Lock… | Wide pill: icon, title, and a ring / battery / slider / button on the right. After 2–4 s the island returns to where it was |
| Suggestion | A moment a rule knows (see "Suggestions") | A sentence and its answers as buttons: Yes · Not now · Never suggest this; gone after 10 s |
| Expanded | Mouse hover or click | Pages (below) |
| Privacy dots | Microphone / camera in use | Orange (microphone) / green (camera) dot to the right of the island, visible in every state |
| Dot | Dot mode: a click on the island | A small circle (15 px, 10–28) in the pill's place; a click on it brings the closed pill back |

### Dot mode

A click turns the island into a small dot in the same place, for when it
should be out of the way; a click on the dot brings back the closed pill.
Everything else is as it was. Settings → General → Dot mode (on by default;
off, a click opens the island as before).

What shrinks it:

- a click on the small island (idle, a live activity, the main pill of the
  split island);
- a click that was on its way there when hovering opened the island: for
  0.7 s after it opened, while the pointer has not moved;
- a click on the open island where nothing else takes it (not a button, a
  list, a field or a card);
- the ⌄ button at the top right of the open island;
- right click → "Shrink to dot" (also "Back to pill" on the dot).

A notification or an event on the island keeps its own clicks (open,
dismiss, its buttons); the split island's circle still opens the island.

The dot glows and grows a little under the pointer and, unless the setting
says so, does not open. What it shows:

| Dot | Meaning |
|---|---|
| The island's body, nothing inside | Nothing going on |
| Orange / green / red centre | Microphone / camera / screen in use (always shown) |
| Red centre | A recording is running |
| Accent-coloured centre, pulsing | A live activity is running |
| Accent-coloured centre | Notifications are waiting |
| Yellow centre | A critical event is waiting (only when "always open for critical events" is off) |

"Events in dot mode": *only the dot shows them* (default) keeps
notifications, questions and critical events until the pill is back and
shows them then; passing events (volume, brightness…) are dropped as stale.
*Open for them, then back to the dot* shows each as usual and returns.
*Show nothing* keeps the dot plain (privacy colours stay) and still keeps
the notifications. An incoming call, an alarm or timer going off and low
battery open the island in every case unless that setting is off. The state
survives a restart ("Start as": as it was left / always the pill / always
the dot). While it is a dot the ambient glow and its audio analysis are
off and the hidden layers do not animate.

### Where the island takes clicks

The island's window is larger than the island (room for the shadow, the
spring's overshoot and the larger states). Only the drawn shape takes the
pointer (the pill, the card, the split circle, the dot with a 24 px target),
with its rounded corners; everything around it goes to the window
underneath. The native helper does this with `QWindow::setMask`, which is
the surface's input region on Wayland and the window shape on X11, and
follows the shape on every frame of a morph. To see the region, set the
hidden option `debugInputRegion=true` in the widget's `[Configuration][General]`
group, or start plasmashell with `DYNAMICISLAND_DEBUG_REGION=1`: a red
outline is drawn around it.

Expanded pages: **Activities** (all ongoing activities, actions and privacy
details), **Media**, **System** (information only: CPU, CPU temperature, GPU,
RAM, battery, network ↓/↑ and disk cards; Fixed or Dynamic view),
**Notifications** (last 3, arrival time; under the mouse quick reply and
dismiss; "clear all" with confirmation), **Controls** (up to six buttons of your choice, like a phone's
quick settings: Do Not Disturb, Night Light, power profile, Bluetooth,
Wi-Fi, updates, airplane mode, VPN, hotspot, screen recording, KDE Connect…;
hold one to change them; volume and screen brightness sliders below),
**Weather** (now and the next days), **Apps** (shortcuts to applications of
your choice), **Tools** (timer, stopwatch, Pomodoro with statistics, alarm), **Habits** (a daily
checklist, an evening review and a GitHub-style calendar of how the days went), **Calendar** (month view, the
events of the selected day and their details; calendars are connected right
on this page), **Notes** (quick notes and the notes of Joplin, Simplenote and
Memos), **Clipboard** (what was copied recently: texts, code, images, files),
**Devices** (Bluetooth devices and phones, with their batteries).

### Activity manager and priority

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
swipe. When the island opens, the Media page is shown if media is playing,
otherwise the System page. The System page only shows status; everything
adjustable (volume, brightness, buttons) is on the Controls page.

## Installation

```bash
./install.sh               # plasmoid + native modules + island-push
./install.sh --no-native   # plasmoid only (QML features)
./install.sh --remove      # removes everything
```

Build packages for the native modules:
`cmake extra-cmake-modules qt6-base-dev qt6-declarative-dev libkf6windowsystem-dev`.
`pw-dump` (pipewire-bin) is also needed at run time.

Features that depend on the native modules: shaped blur, screen recording,
microphone/camera indicators, unlock, KDE Connect calls, update count, the
D-Bus API, and calendar accounts (password storage in KDE Wallet, Google
sign-in) and the tokens of notes apps. Without the native module these features hide themselves and
everything else works. Likewise, a missing KDE module (e.g. KDE Connect,
bluez-qt, plasma-nm) only disables its own feature.

Then reload plasmashell:

```bash
systemctl --user restart plasma-plasmashell   # recommended
# or
plasmashell --replace & disown
```

## Placement

The island itself is a separate top-level window, so **it does not matter
where you add the plasmoid**. The island always appears at the top centre of
the screen it was added to.

- Add it **to the desktop** (right click → Add Widgets… → "Dynamic Island").
  Only a small handle icon is shown on the desktop. Right click it for the
  settings.
- **or to a panel**. It only takes a small icon there too. Clicking the icon
  opens/closes the island.
- If you have a panel at the top, the island sits right below it while
  **"Place below top panels"** is on. Turn it off and the island sits *on* the
  panel (like a notch); in that case adjust "Distance from top" to the panel.

## Settings

| Setting | Description |
|---|---|
| Appearance | Follow the system, or a custom look: see [Appearance](#appearance) |
| Clock | Clock when idle and in the expanded header |
| Distance from top / below panels | Position |
| Notifications, display time | Behaviour when a notification arrives |
| Hover delay / close on leave | Default 120 ms / 400 ms |
| Preferred player | E.g. `spotify`. This player is shown if it is playing (or nothing else is); if empty Plasma chooses. Matches the identity/desktop file name case-insensitively. A player that says "Playing" while its position stands still for ~9 s (Spotify after a Spotify Connect session was stopped on the phone) counts as not playing |
| Volume | The volume slider in Controls (Layout → Modules) |
| System view | Fixed (5 cards, 2 rows) / Dynamic (default: the cards that are active right now grow, no gaps; with few active cards the two busiest stay large). In both views the card under the mouse grows and shows its details. Clicking a card opens `btop` in the default terminal with only that metric's graph (needs the native module and btop ≥ 1.4; btop's own configuration file is not touched) |

**Layout** tab: the pages of the expanded island in one list. Drag a page by
its handle to move its tab (the row lifts while it is dragged, the others make
room); the switch next to it shows or hides it (these are the same settings
as before: showMediaModule, showTools…; Media also turns the media live
activity on or off, Calendar also the upcoming-event activity). Activities has
no switch: it appears while something is going on. "Restore default order"
goes back to Activities, Media, System, Weather, Notifications, Controls,
Apps, Tools, Habits, Calendar, Notes, Clipboard, Devices. The order is stored as `pageOrder`
(comma-separated page keys) and applies as soon as the settings are applied.
This order only places the tabs; which live activity the small island shows
first is the priority list of the Activities tab, so privacy indicators,
calls and screen recording still come first whatever the page order is.
**Controls** tab: the buttons of the Controls page, like a phone's quick
settings: at most six, in the order shown (drag by the handle), the others
listed below to add. Holding a button on the Controls page in the island
edits them there too: the buttons wiggle; drag one sideways to move it (the
others make room; holding and dragging works in one go), "−" takes one away,
the others are offered below as round icons to add (the name of the one
under the pointer is shown above them; the wheel scrolls them), "Done" ends
it. The island stays open while editing. Stored as `controlTiles`. Available:
Focus (Do Not Disturb), Night Light, power profile, Bluetooth, Wi-Fi,
updates, airplane mode (the same switch as Plasma's network applet), VPN
(connects the one used last, shows the active one's name), hotspot, record
screen and screenshot (Spectacle, a region), camera (opens Kamoso, Snapshot,
Cheese or guvcview; lit while the camera is in use), microphone and sound
(mute), KDE Connect (opens it; lit while a phone is connected), find phone
(rings it), dark mode, keep awake (the battery applet's manual sleep and
screen-lock block), lock, calculator, System Settings. A button whose part
is missing (no VPN set up, no camera app, no phone…) is dimmed. Dark mode
switches the colour scheme with `plasma-apply-colorscheme` and remembers the
one it left (`darkColorScheme` / `lightColorScheme`), so a custom scheme
comes back; without one it takes the Light/Dark counterpart by name, else
Breeze. NFC is not offered: Plasma has no NFC switch.
**Activities** tab: priority order (up/down), split island on/off, keep
playing media visible, watch the download folder, momentary event duration, a
separate switch for every system event and live activity type.
**Alerts** tab: low/critical battery threshold, Bluetooth device/phone battery
threshold, CPU/GPU temperature threshold.
**Calendar** tab: on/off, how many minutes before the start to pin (15), how
many minutes after the end to disappear (10), all-day events, update interval
(5 min) and the connected calendar links ("Connect a Calendar" wizard; see
below).
**Tools** tab: timer/alarm sound (a file can be chosen), Pomodoro durations
and number of rounds, the Pomodoro statistics and their reset.
**Layout** tab, two lists that are kept apart. *Tabs*: the pages along the top
of the expanded island; drag one by its handle to move its tab, switch it off
to take it out of the tab bar altogether. The last tab that is on cannot be
switched off ("At least one tab has to stay on"). *Modules*: the parts inside
a page that can be switched (the volume slider in Controls).
**Weather** tab: the place (search by name, or forget it), the units and the
alert; see "Weather" below.
**Suggestions** tab: on/off, the least pause between two suggestions (5
minutes), and every rule with its switch, its mode (asks / automatic), what
it has learned so far and "forget" for it; "Forget everything that was
learned" (asks first). A rule this system cannot make says so. What is
changed there holds at once; see "Suggestions" below.
**Notes** tab: the connected apps, where quick notes go, how often they are
fetched, and "Carry on in the note that was being edited" (on by default).
**AI** tab: the AI page's switch (off until switched on), what is connected
to answer with its model and "Disconnect", which source answers by default,
the longest answer and question, "Keep the chat in a file" and "Answer ready"
on the island; see "AI" below.
**Cloud** tab: the Cloud page's switch (off until switched on) and its
indicator, the clouds rclone knows (shown or hidden, a name of one's own, where
the sync state comes from), storage thresholds, alerts and their pause, the
question before an upload, the cache and "Clear cache", and how a cloud is
added; see "Cloud" below.
**Appearance** tab: besides the look itself, "Add New…" (a theme from a file
or from the store), "Export Theme…" and the gradient controls; see
"Appearance" below.
**Habits** tab: the permanent habits (rename, delete, drag into order), the
time of the evening review, its reminder on/off, the calendar's colours
(GitHub green / the system's accent colour, also in Appearance) and "Reset
all data" (asks first); see "Habits" below.
**Language** tab: Automatic (Turkish when the system is Turkish, English
otherwise), Türkçe or English. Applies at once, to the island and the
settings, without restarting Plasma; see "Translations" below.

The end times of the timer, stopwatch, Pomodoro and alarm are stored in the
settings; they carry on where they were even if plasmashell restarts.

### Appearance

Settings → Appearance has two modes.

**Follow the system** (default). Background, text, border and accent colour
come from Plasma and change with it at once, without restarting the shell.
"Colours from" chooses what "the system" is, because inside plasmashell there
are two:

- *The colour scheme*: what System Settings → Colours applies, with the
  accent colour, as applications show it. System Settings writes it to
  `kdeglobals` and announces the change on D-Bus
  (`org.kde.KGlobalSettings.notifyChange`, type 0); the island reads the file
  again on that signal (`backend/ColorSchemeBackend.qml`). Nothing is polled.
  This needs the native helper; without it the Plasma style is used.
- *The Plasma style*: what the panel and other widgets use. This is
  `Kirigami.Theme`, which inside plasmashell is libplasma's `PlasmaTheme` over
  `Plasma::Theme` and follows `Plasma::Theme::themeChanged` by itself. It is
  the colour scheme too, unless the Plasma style brings its own colours
  (Oxygen, Breeze Dark…).

(The Qt palette is neither: with a widget style like Kvantum it is that
style's.)

**Custom.** The island keeps the look you set, whatever the system does:

| | |
|---|---|
| Ready-made looks | Oxygen Metallic (the original), Breeze Dark, Breeze Light, Pure Glass (Minimal), High Contrast (text and status colours at 4.5:1 or more, controls and border at 3:1 or more, nothing translucent to read on), and four gradients: Aurora, Sunset, Ocean, Midnight Blue (every colour of them dark enough for the light text, 4.5:1 or more). Each card shows the look itself. Choosing one keeps where the island sits and how large it is. "Reset to the preset" undoes the fine tuning |
| Opacity | 0–100 %, as set (independent of blur) |
| Blur | On/off and a level. KWin blurs with one strength for the whole desktop (System Settings → Desktop Effects → Blur), so the level adds frosting over the blurred background |
| Distance from top | 0–40 px (while following the system: the one in General) |
| Horizontal position | −100…+100 px from the centre |
| Size | 80–120 %: the whole island is scaled, text stays sharp |
| Corner roundness | From sharp corners to a full capsule |
| Background | One colour (or the system's accent colour), or a gradient: two or three colours, linear at any angle (0–360°, as in CSS: 0° runs upwards, 90° to the right) or radial from the middle. Opacity and blur apply to it as to a solid colour |
| Colours | Buttons and controls (or the accent colour; kept visible on the background), text (automatic by contrast, or your own). On a gradient the automatic text colour is chosen against the gradient's average brightness, and everything that is kept readable is kept readable against that average; a gradient with both very light and very dark parts (under 3:1 somewhere for the text) gets a warning |
| Border | On/off, 1–4 px, the look's own colour or yours |
| Shadow | None / light / strong |

Every change shows on the island at once while the settings window is open;
Apply keeps it, Cancel returns to what was stored. A look can be saved under a
name ("Work", "Night") and chosen again later; the custom look also stays
while the island follows the system. Whoever used the earlier settings (style,
opacity, blur) finds them as the first custom look.

Everything goes through `Theme.qml`: a look is plain data (`Styles.qml`) and
every colour and size there is a binding of it. The ambient glow sits on top of
whatever look is chosen.

### Themes: files and the store

A custom look can leave the settings as a file and come back from one.

- **Export Theme…** (Settings → Appearance) writes the look being edited, under
  a name you give it, as one `*.islandtheme.json` file where you choose. It
  holds every Appearance setting of the custom look and nothing else: no code,
  no QML, no images. The format is `catalog/islandtheme.schema.json`.
- **Add New…** (top right of the looks) opens two tabs. *From a File*: choose
  a file or drop it on the area. *Browse the Store*: the themes of this
  repository's `catalog/` folder as cards (name, author, description, preview,
  Download). Either way the theme is checked, joins the list of looks under
  its own name with all of its settings, and is shown with a preview; it only
  becomes the island's look with **Apply** (or a click on its card). When a
  look of that name exists already you are asked: overwrite, or add it under
  another name.
- A theme you exported brings back everything, also where the island sits
  and how large it is. A theme that says nothing about those (`top`,
  `offsetX`, `scale`; the store's themes do not) leaves them as they are.
- Themes you added are kept as files in `~/.local/share/dynamicisland/themes/`
  and can be deleted from the list (the bin on their card, asks once more).
  The ready-made looks cannot.
- What is refused: a file over 64 kB, one that is not valid JSON, one whose
  known fields are not what the schema allows (unknown fields are ignored),
  and a download whose SHA-256 is not the one the catalog lists. The message
  says which it was. Reading a theme never runs anything.

**Where the store looks.** One constant, `CATALOG_URL` at the top of
`contents/ui/ThemeFile.js`, holds the published address of `catalog/`:

```js
const CATALOG_URL = "https://raw.githubusercontent.com/OWNER/REPOSITORY/BRANCH/catalog";
```

As it comes it is a placeholder (`OWNER/REPOSITORY/BRANCH`): the store then
says that it has no address yet and asks nothing. Replace the three words
with the repository's owner, its name and the branch the catalog is published
from (the result is the address under which
`…/catalog/index.json` opens in a browser), and install again.

**Privacy.** The store makes a request only when you open its tab (the list:
`index.json`) and when you press Download (that one theme file). They are
plain GETs to raw.githubusercontent.com: no account, no cookies, no
telemetry, no check in the background, nothing while the settings are closed.
Without a connection the tab says so and offers to try again.

Adding a theme to the catalog: [CONTRIBUTING.md](CONTRIBUTING.md)
(`tools/catalog-update` writes `index.json` with the checksums).

Theme files need the native module (it reads, writes and deletes them);
without it the two buttons are disabled.

### Ambient glow

Off by default; the wave button at the top right of the Media page switches
it (the choice is kept, `ambientGlow`). While it is on:

- The edge of the island glows in the colour of the album cover and the
  surface takes a faint tint of it (a bit more on the small pill, less on the
  expanded card). A new song crossfades to its colour in 0.7 s.
- The glow breathes with the loudness of the music; on a bass hit the drawn
  surface grows by 4 % for 90 ms and eases back in 220 ms, and the glow
  peaks. Only the drawing grows: the content and the input area keep their
  size. The glow is drawn below and beside the island, where the window has
  room (it hangs from the top of the screen).
- Paused, it stays as a dim, still light; without media it goes out.
  Switched off, everything fades out in 350 ms and nothing of it is left
  (the glow layer is not even created then).
- With a gradient look the layers stay as they are: the look's gradient is
  the base, the cover's colour is the changing light around and over it.

**Colour:** the cover is drawn at 16×16 into a canvas and its pixels are
sorted into 12 hue bins weighted by saturation × √brightness (grey and black
pixels do not count); the colour is the mean of the heaviest bin, moved in
HSL to saturation ≥ 0.5 and lightness 0.5–0.65. A grey, black or white cover
gives a soft silver. Each cover is analysed once (cached by its URL).

**Music:** `pw-record` captures the default output's monitor
(`stream.capture.sink`) as raw float, mono, 8 kHz (~32 KB/s through a pipe;
`AudioLevels` in the native core). Every 32 ms it computes the RMS (loudness)
and the RMS after two one-pole low-pass filters at 150 Hz (bass, 12 dB/oct:
kick drums and bass lines, no FFT needed), both with automatic gain so quiet
and loud tracks move alike. A bass hit is a jump to 1.45× the bass of the last
~0.6 s (at most one per 180 ms). The process only runs while the glow is on
and something plays. libpipewire's own API was not used because its
development headers are not needed anywhere else (the privacy watcher uses
`pw-dump` the same way). Without the native module the glow still shows the
cover's colour, without following the music.

### Translations

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
the rules written in JavaScript under node (habits, theme files, weather
data, suggestions) and the QML tests in `tests/` under `qmltestrunner`, off
screen: providers and pages with stand-ins for what they watch, the settings
pages as they are, the theme store and the weather against answers served on
127.0.0.1. No test reads or changes the system's clock: what depends on time
takes the day or the moment as an argument. Tests that need the native
module use the one in `native/build` and are skipped without it.

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
tools/weather-icons, tools/ai-cli-check
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

## Calendar

The calendar does not need Akonadi/KDE PIM. There are two ways to connect one,
both from the gear button on the island's Calendar page (pick Google or Apple,
then how):

**Connect the account** — every calendar of the account is shown and events
can be added and deleted from the island.

- *Apple iCloud:* enter your Apple ID and an **app-specific password**
  (account.apple.com → Sign-In and Security → App-Specific Passwords; Apple
  generates it, in the form `abcd-efgh-ijkl-mnop`). Your normal Apple password
  does not work. The password is stored in KDE Wallet, never in the
  configuration file. Calendars are read and written over CalDAV.
- *Google:* Google only allows this through OAuth, which needs a client
  registered in Google Cloud, once:
  1. Open a project in the [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
     and enable the **Google Calendar API**.
  2. Set up the OAuth consent screen (audience: **External**) and add your
     Google address under Audience → Test users.
  3. Clients → Create client → **Desktop app**.
  4. Paste the client ID and client secret into the island
     (gear → Google → Connect the account), then press **Sign in with Google**.
  5. The browser opens: choose the account and allow calendar access ("Google
     hasn't verified this app" → Advanced → continue is expected for your own
     test client). When the page says "Sent to the island", return to the
     island.

  Your Google password never reaches the island; the refresh token is stored
  in KDE Wallet. While the Cloud project is in "Testing", Google expires the
  access after about 7 days and you sign in again.

**View only** — no account details are entered. Each calendar is an iCalendar
(.ics) subscription link; the widget downloads it periodically and parses it
off the GUI thread.

- The wizard explains where to find the link (Google: "Secret address in iCal
  format"; Apple: make the calendar public and copy its share link), downloads
  it once to check that it really is a calendar (VCALENDAR) and suggests its
  name from the file's `X-WR-CALNAME` field. `webcal://` automatically becomes
  `https://`. The same link cannot be added twice.
- Links can also be managed in Settings → Calendar.
- Apple and Google update a published link with a delay of their own, so a new
  event can take a while to appear; an account does not have this delay.

Common to both:

- **Calendar page:** a month grid with a dot in the calendar's colour on every
  day that has events; clicking a day lists its events, clicking an event
  shows its details. A place opens in the maps site, links in the notes are
  clickable. "+" adds an event to the selected day (title, date, time or all
  day, place, target calendar); the bin in the details deletes one (a
  recurring event is deleted as a whole series).
- **Pinning:** 15 minutes before it starts an event is pinned to the island
  (title + countdown, its priority rising as the start approaches), a short
  "… started" event is shown at the start, the time left and progress while it
  runs, and it stays for 10 more minutes at a low priority after the end. One
  event is pinned at a time (the soonest to start). All-day events and
  reminders whose time has passed are not pinned.
- **Meeting link:** Google's conference field, or a Meet/Zoom/Teams/Webex/Jitsi
  address in the place or description. If there is one, a "Join" button and
  the "Open link" button in the details open it in the default browser.
- **Recurring events** (RRULE, EXDATE, single-occurrence changes) and time
  zones in .ics data are expanded with
  [ical.js](https://github.com/kewisch/ical.js) 1.5.0 (MPL-2.0; embedded in
  `backend/IcsWorker.js` with a few local changes marked "Local change", its
  licence in `backend/IcsWorker.LICENSE.ical.js`). 1.5.0 is used because 2.x
  does not run in Qt's JS engine; the `usedbeforedeclared` warnings logged
  while it loads are harmless.
- **Privacy:** links give access to the calendar. They are stored as plain
  text in the Plasma configuration file
  (`~/.config/plasma-org.kde.plasma.desktop-appletsrc`, mode 600) and are not
  logged. Account passwords and tokens are stored in KDE Wallet (folder
  "Dynamic Island").
- The Google and Apple logos are from Simple Icons (CC0) (`contents/icons/`);
  they are only used to label the respective option.

## Notes

A page for jotting something down quickly and for looking up what was noted.
It only appears in the expanded island (never as a live activity; reminders
set in BetterNotes are only a badge in the list). Open-source
notes apps are connected on the page itself; when nothing is connected the
page looks for them on the computer (their data folders, and whether Joplin's
local service answers) and offers the ones it finds first.

| App | How it connects |
|---|---|
| **Joplin** | The desktop app's local Web Clipper API (`http://localhost:41184`). In Joplin: Tools → Options → Web Clipper → "Enable Web Clipper Service", then copy the token under "Advanced options" and paste it into the island. Joplin has to be running. |
| **Simplenote** | Email and password of the account. The password is only used to sign in (through Simperium, the service behind Simplenote); the island keeps the access token it gets back. |
| **Memos** | Address of your own server and an access token (Memos → Settings → My Account → Access Tokens). |
| **BetterNotes** | Nothing to connect: an account-less notes app on this computer. If its `betternotes` command is found (on the PATH, in `~/.local/bin`, or through its menu entry) one click shows its notes; if not, the page shows the install command to copy (it never runs it). |

- All connected apps are shown in one list, newest first, each note with the
  logo of its app. Several apps can be connected at once.
- The field at the top adds a quick note to the **default** app on Enter; the
  magnifier turns it into a search over the text of all notes.
- Clicking a note opens it for editing; changes are written back to the app
  (saved shortly after you stop typing, on Ctrl+S and when you go back). For
  Joplin the first line is the note's title.
- BetterNotes: notes are listed with `betternotes list`, read with
  `betternotes show <id>`, created with `betternotes new <title> --id-only
  --no-open` and saved with `betternotes update <id> [--title …] [--body -]`
  (BetterNotes 0.1.13 or newer; the content goes on standard input, so line
  breaks stay as they are). The change date, lock state and next reminder (an
  orange badge) come from its SQLite database, which is opened read-only and
  never written; all writing is done by the `betternotes` command.
  - A quick note (the field at the top, Enter) is only a **title**: the note
    is created empty and appears in the list at once; click it to write in
    it later.
  - In the editor the title is a field above the plain-text content; both
    are saved 1.5 s after typing stops, when the field loses focus, or on
    Ctrl+S. Rich formatting is not rebuilt here: a note with rich text is
    only shown. A locked note is not shown at all (see "Locked notes" below).
  - "Edit in BetterNotes" there, and the window button beside the title of
    any other note, show the note as its sticky window on the desktop with
    `betternotes open <id>` (BetterNotes 0.1.14 or newer, started in the
    background if it is not running; a locked note asks for its password).
    With an older BetterNotes the button only starts the app.
  - If saving fails (an older BetterNotes is running, the note was deleted…)
    the reason is shown with "Try again"; the text stays in the editor and,
    until the shell restarts, also after leaving the note or closing the
    island ("Not saved" in the list).
  - The list follows changes at once (the data folder is watched). These
    notes stay on this computer and do not appear on other devices.
- **Carrying on where you left off:** the note that is open in the editor is
  remembered: its app and its id (`notesLastOpen` in the settings), never its
  text. When the Notes page is opened again, after another tab, after the
  island closed or after plasmashell restarted, it goes straight back into
  that note's editor, with the unsaved draft if there is one (the same
  protection as above). Going back to the list ends it. A note that was
  deleted meanwhile, or whose app is not running or no longer connected,
  leads to the list without a message.
- **Locked notes (BetterNotes)** ask for the master password right on the
  island, also when carrying on. BetterNotes encrypts a locked note's text
  (XChaCha20-Poly1305, the key derived from the password with Argon2id);
  from 0.1.15 its command takes the password on its standard input
  (`show <id> --password-stdin`, `update <id> --password-stdin …`), for that
  one command. The island hands it over that way (never as an argument),
  holds it only while that note is open on the page, to save what is typed,
  and forgets it when the note is left or the island closes: coming back
  asks again. A wrong password is said (exit status 3). What the note says
  is never put into the list, the search, a draft or the settings. With an
  older BetterNotes the page says so and offers "Open in BetterNotes".
- Tokens are stored in KDE Wallet (folder "Dynamic Island"), never in the
  configuration file, and are deleted when an app is disconnected.
- Settings → Notes: connected apps (disconnect), the default app for quick
  notes, how often notes are fetched (2 minutes by default), and whether the
  page carries on in the note that was being edited (on by default).

Not supported: **Standard Notes** (its notes are end-to-end encrypted; reading
them needs Argon2id and XChaCha20-Poly1305, i.e. libsodium, which the native
module does not link yet) and **Obsidian** (only through the community "Local
REST API" plugin; not done).

## Weather

A tab of its own (Layout switches and moves it like any other): the current
temperature, what it feels like, the condition, humidity and wind, and the
next seven days with high, low and the chance of precipitation. Its tab shows
the weather's picture and, where the tab bar has room, the temperature.

- **It starts empty.** The place is never detected: until one is chosen the
  page only shows "Choose a Location" and nothing is asked of any service.
  The button opens a search right in the island: type a city's name and the
  matches are listed as you type (name, region, country); a click chooses
  one, stores it and loads its weather. The place's name at the top right of
  the page opens the search again at any time; Settings → Weather can search
  and forget the place too.
- **Days and hours:** the day under the pointer lights up and lifts a little.
  A click slides that day's hours in from the side: on top its high and low,
  sunrise and sunset; below, hour by hour: time, picture, temperature, what
  it feels like, the chance of precipitation, its amount (when there is any),
  humidity, wind speed and direction. The list scrolls; for today it starts
  at the current hour, which is highlighted. The arrow goes back.
- **The wheel:** while a place is searched and while a day's hours are shown
  the wheel scrolls that list and does not turn the island's page, not at
  the list's end either (`keepsWheel` of the page, `tests/tst_wheel.qml`);
  the tabs still do.
- **Source:** [Open-Meteo](https://open-meteo.com) (`backend/WeatherBackend.qml`,
  `WeatherData.js`): its forecast service for the weather and its geocoding
  service for the search. Neither needs a key or an account. The data is
  under CC BY 4.0, which the search view credits ("Weather data by
  Open-Meteo.com"); the free service is for non-commercial use. The forecast
  is asked again every 30 minutes while the page is switched on, and when
  the page is opened after that long.
  The earlier source (BBC Weather through Plasma's weather engine) gave a
  forecast by the day only: no hours, no hourly humidity or chance of
  precipitation, no "feels like". A place chosen there has to be chosen once
  more (its name is offered in the search field).
- **What is sent:** to the geocoding service the text that is searched for
  (and the widget's language, for the names it answers in); to the forecast
  service the coordinates of the chosen place, rounded to four decimals.
  Nothing else: no place name with the coordinates, no identifier, and no
  request at all before a place is searched or chosen.
- **Units and language:** Settings → Weather switches between °C, km/h, mm
  and °F, mph, inches (the values are converted for showing; nothing is asked
  again). Day names, conditions and wind directions are in the widget's
  language.
- **Pictures:** an embedded set, not the system's icon theme: the SVG files
  in `contents/icons/weather/` are from [Lucide](https://lucide.dev) (ISC
  licence; the icons that come from Feather are MIT; the full text is the
  `LICENSE` beside them). Sun, moon, sun or moon behind a cloud, clouds, fog,
  drizzle, rain, showers by day and by night, snow, sleet and hail,
  thunderstorm, and the small ones for the place, sunrise and sunset. They
  are outlines in one colour and are drawn in the theme's text colour
  (`WeatherIcon.qml`; `tools/weather-icons` writes `WeatherIcons.js` from the
  SVG files, because Kirigami's icon item does not colour a file of the
  widget's own).
- **Alert:** rain (a chance of 40 % or more), snow or a storm in the forecast
  for today, tonight or tomorrow is shown once on the island for a few
  seconds ("Rain tonight · Reykjavik · 70 %"); a storm also shakes it. It is
  an event of its own and has nothing to do with the System page's cards.
  Settings → Weather switches it off.

## Apps

A grid of up to 12 shortcuts. A click starts the application and closes the
island; a right click selects one to rename (the label under the icon) or
remove; dragging moves it. A dot under an icon means the application has a
window open.

"Add" lists the installed applications with a search field. The list is the
one Plasma's own launchers use: the system's application database (KService /
KSycoca, built from the XDG `.desktop` files and the menu's rules), read
through plasma-workspace's "apps" data engine (`backend/AppsBackend.qml`);
entries the menu hides (`NoDisplay`, settings modules) are left out. Starting
goes through the same engine (`KIO::ApplicationLauncherJob`), the running dot
comes from the task manager's window list. A shortcut is kept as the
`.desktop` file's menu id with its name and icon (`appShortcuts`, JSON in the
widget's settings).

## Pomodoro statistics

Every focus round that runs to its end is counted for its day; breaks, and
rounds that were skipped or stopped, are not. Under the Pomodoro clock:
"Today: 3 · This week: 14 · Streak: 5 days" (the week is Monday to Sunday; the
streak is the days in a row with at least one round, and is not lost before
today's first round). A click on that line shows the last seven days as bars,
with the total and the longest streak; another click goes back.

The numbers are a small JSON text in the widget's own settings
(`pomodoroStats`: rounds per day for the last year, the total, the longest
streak) — no database, no file of its own. `PomodoroStats.js` does the
counting and takes the day as an argument, so it never reads the clock.
Settings → Tools resets them, after asking.

## Habits

The habits you want to build, a checklist for every day, an evening review
and a calendar that shades each day like GitHub's contribution graph.

- **First time:** the page asks for the habits (it comes with none and
  suggests none) and then for the time of the evening review (21:30 unless
  changed). Those are the *permanent* habits: on every day's list until
  deleted.
- **During the day** the page shows today's list: a click ticks or unticks an
  entry at any moment. Under the pointer an entry can be taken off today's
  list only (it is back tomorrow and does not count today) or the habit
  deleted for good (asks first); "+" adds a new permanent habit. The day
  stays editable after the evening review, until midnight and afterwards from
  the calendar; its box follows at once.
- **Evening review:** at the review time the island asks, as a momentary
  event: "How was today? 3/5 checked" with a *Review* button. It opens the
  Habits page on three steps: (1) the day's list, with what was ticked during
  the day; (2) for every one-time extra on that list, once: "Shall I add
  '…' for tomorrow as well?"; (3) "Is there an extra activity you want to
  add for tomorrow?", one or more, or *None*. Ignored, the question waits as
  a live activity of the lowest priority; closed (the cross, or "Not now"),
  only a dot stays on the Habits tab.
- **Nobody there at that time:** the review of a day is due from its time
  until the next day's, so one that was missed is asked later and written to
  the day it belongs to (Monday's, answered on Tuesday morning, is
  Monday's). The question is never shown into a locked screen; it comes at
  the unlock. After a start of the shell or a wake-up the same check runs.
  When several days were missed only the latest is asked; the earlier ones
  stay "not reviewed" and can be filled in from the calendar.
  The signals: the lock screen is `org.freedesktop.ScreenSaver`
  (`GetActive` at the start, then `ActiveChanged`; KWin provides it on
  Plasma), the wake-up is logind's `PrepareForSleep(false)` on the system
  bus, both through the native core (`NativeBridge.qml`: `screenLocked`,
  `screenUnlocked`, `resumed`). A shell that was not running needs no
  signal: at its start, and every half minute, the provider compares
  wall-clock times. Without the native core the lock is not known and the
  question is asked when its time has come.
- **Extras:** an extra added in the evening is on the next day's list only.
  That evening it is asked about once. *No:* it is let go and never asked
  again. *Yes:* it is added for the day after too, and being added two days
  in a row makes it a permanent habit ("'Go to the market' is a permanent habit
  now."). Typing the same extra again instead of answering does the same;
  names are compared without regard to case and spaces. Days that are not in
  a row start counting again.
- **Shades:** a day's share is done / listed (habits + that day's extras;
  what was taken off the day does not count). Level 0 is 0 %, 1 up to 25 %,
  2 up to 50 %, 3 up to 75 %, 4 above. A day that was neither reviewed nor
  touched is an empty outlined box, not level 0: "no data" is not "did
  nothing". GitHub's greens by default, the system's accent colour as an
  option.
- **Calendar:** columns are weeks (Monday at the top), today at the far
  right; as many of the last weeks as fit beside the list (about 3½ months).
  The day under the pointer is named below ("12 October · 3/5"; the island
  has no tooltips). A click opens the day: what was done and what was not,
  to be corrected; an earlier day that is corrected counts as reviewed. "All
  year" shows the last 53 weeks in a wider island.
- **A deleted habit** stays in the days already recorded (its name is kept
  for as long as one of them lists it): their lists and shades do not
  change, only today and the days to come.

**Storage:** like the Pomodoro statistics, one small JSON text in the
widget's own settings (`habitsData`), no database and no file of its own:
the habits (id, name), for every day the ids done and not done, its one-time
extras and whether it was reviewed, the extras planned for a day not yet
begun, and how many days in a row each extra was listed. A day costs about
45 bytes; the last year is kept (about 17 kB with five habits). A new day's
list is made at local midnight, or at the first start after it; days the
computer was off get theirs then, not reviewed.

`Habits.js` holds every rule and takes the day or the moment it is asked
about as an argument, so it never reads the clock; the provider's only
reading of it is one replaceable function. `tools/habits-test` checks the
rules with dates of its own (and, with `qmltestrunner`, the provider: the
evening question after a restart, a lock, a sleep) without touching the
system's time.

## Suggestions

At the right moment the island asks one short question and offers to do
something for you. It is rule based and entirely local: no network, no
model, nothing leaves the computer.

| Moment | Question | What "Yes" does |
|---|---|---|
| A calendar event is about to start (the pinned, upcoming one) | "“Stand-up” starts soon. Turn on Do Not Disturb until it ends?" | Do Not Disturb until the event's end (Plasma switches it off then) |
| Screen recording or screen sharing starts | "The screen is being recorded. Hide notifications while it lasts?" | Do Not Disturb while the recording lasts, off again when it stops |
| An application starts using the microphone while media plays | "The microphone is in use. Pause the media?" | Pauses the player |
| The battery reaches the low threshold (Alerts), not on the charger | "The battery is low (18 %). Switch to the power saving profile?" | The power saving profile (Undo: the one before) |
| A Pomodoro focus round starts | "A focus round has started. Turn on Do Not Disturb until the break?" | Do Not Disturb until the round ends |
| Headphones are connected (a Bluetooth headset, or the audio output becomes headphones) while the media is paused | "Headphones are connected. Carry on playing?" | Plays |

A rule whose part of the system is missing or switched off never comes up:
no Do Not Disturb, no power profiles, no native module (screen casts and the
microphone are seen through it), the Calendar, Tools or Media page switched
off… Nor does it when there is nothing to do: Do Not Disturb is on already,
nothing plays, the power saving profile is active.

**The question** is a momentary event: one sentence and three buttons, **Yes**,
**Not now**, **Never suggest this**. Without an answer it goes away after ten
seconds and counts as not answered (the cross and a middle click count as
"Not now"; the pointer on it keeps it there).

**What it remembers,** per rule: how often the answer was yes and how often
"not now" or none, how many of each in a row, when it was last suggested,
and whether it is asking, automatic or off.

- **Never suggest this:** the rule is off for good, until it is switched on
  in the settings.
- **"Not now" or no answer three times in a row:** the rule is suggested less
  often: it waits an hour before the next time, then two; one yes ends that.
  **Five in a row:** the rule is switched off and the island says so once:
  "I will not show this suggestion any more · You can switch it on again in
  Settings → Suggestions".
- **Yes three times in a row:** the island asks once: "Shall I do this
  automatically from now on?". With a yes the rule is automatic: it acts
  without asking and says so each time, "Do Not Disturb is on · Done
  automatically", with an **Undo** button. Undo takes the action back and
  puts the rule back to asking.
- At least five minutes (a setting) lie between two suggestions, of whatever
  rule. Nothing is suggested while Do Not Disturb is on or the screen is
  being recorded (the recording's own question comes at its start).

**Stored** as one small JSON file, `~/.local/share/dynamicisland/suggestions.json`
(`SuggestionStore.qml`; in the widget's settings instead when the native
module is missing): the counters above, nothing about what was on the screen
or in the calendar. It outlives a restart of the shell. `Suggestions.js`
holds the learning and takes the moment it is asked about as an argument, so
it never reads the clock; `tests/suggestions.test.js` and
`tests/tst_suggestions.qml` check it with times of their own.

## AI

A tab for quick questions: text in, text out. It is **off** until it is
switched on (Settings → Layout or AI), and while it is off none of it is
loaded. A question is typed (Enter sends, Shift+Enter is a new line), the
answer is shown while it is written, as Markdown, with code blocks in boxes of
their own and "Copy"; a follow-up goes into the same chat; the button stops an
answer; "New chat" starts over. It is a box for short questions, not for long
work, and **not an agent**: no source is ever given a tool, a file or anything
that was not typed. A question over the length limit is not sent (the Claude
app or a terminal is named instead); no file, picture or drop is taken, and
nothing of the clipboard, the screen, the notes or the calendar is added by
itself. The rule-based suggestions stay what they are: nothing here feeds them.

### What can answer

Sources are connected on the page itself. What is found on this computer is
offered first; a command that installs or starts something is only ever shown
to be copied, never run.

| Source | How it connects |
|---|---|
| **Claude Code** | The `claude` command of this computer (on the PATH or in `~/.local/bin`), already signed in: no key, and the island never sees an account. Found by itself. See below for what it is run with |
| **Ollama** | `http://localhost:11434/v1`, found by itself: answering, installed but not running ("Start it": `ollama serve` to copy), or not found (the install command to copy). No account, no key; nothing leaves the device |
| **Local model server** | Any server that speaks the OpenAI protocol at an address you give, e.g. LM Studio (`http://localhost:1234/v1`) or llama.cpp (`http://127.0.0.1:8080/v1`). An address that is not this computer is not called local: the form says where the text will go (and when the connection is not encrypted) and connects on the second press |
| **Anthropic API** | A key from `platform.claude.com/settings/keys`; `GET /v1/models`, `POST /v1/messages` as a stream |
| **OpenAI**, **OpenRouter**, **Groq**, **Google Gemini** | A key; each at its OpenAI-compatible address (`api.openai.com/v1`, `openrouter.ai/api/v1`, `api.groq.com/openai/v1`, `generativelanguage.googleapis.com/v1beta/openai`) |
| **Another service** | Any other OpenAI-compatible service: its address and its key |

- **Models** are never a list written down here. For a service it is its own
  list (`/models`), with a field to search it or to type a name; for Claude
  Code it is "its own choice", the names its `--help` gives as examples
  (`fable`, `opus`, `sonnet` today), or a name typed in Settings → AI.
- **Keys** live in KDE Wallet (folder "Dynamic Island", entry `ai:<id>`) and
  nowhere else: not in the settings, a log, a message, an address or a
  command line; in a request a key is a header. Connecting asks the service
  first, so a key it refuses is stored nowhere. A key is read from the wallet
  only when a question is asked, and deleted from it when its source is
  disconnected (on the page or in the settings). Without the native module it
  is kept only until the shell restarts.
- **Before the first question** to a source its notice is shown once: where
  the text goes (to Claude through Claude Code, to the named service, or
  nowhere beyond this device) and that it uses up that account's usage. The
  backend refuses to send before it was accepted.
- **The longest answer** (2048 tokens unless changed) is sent to every source
  as its limit; an answer cut off there says so.
- **The chat** is in memory only: it survives the island closing, not a
  restart of the shell. "Keep the chat in a file" (off) also writes it to
  `~/.local/share/dynamicisland/ai-chat.json`, readable by the owner only;
  switching it off deletes the file.
- **What an answer contains is never acted on.** A link is opened only after
  asking, and only a web address. A picture is not fetched: Qt's Markdown
  would fetch it by itself the moment the answer is shown, so it is turned
  into its link first. HTML is shown as text (`AiMarkdown.js`).

### Claude Code: a question box, not an agent

Three layers, the first two enforced, the third only asked. The options were
found by running `claude --help` and trying them (2.1.289); `ai/ClaudeCli.js`
holds them in one place.

| Option | What it is for, and what was seen |
|---|---|
| `-p --output-format stream-json --verbose --include-partial-messages` | One answer, then exit, written as lines of JSON while it is made |
| `--tools ""` | None of the built-in tools (files, commands, web, sub-agents, notebooks…) |
| `--strict-mcp-config` | No MCP servers. Without it a server of the user's account stayed connected with its 8 tools, `--tools ""` or not |
| `--setting-sources ""`, `--safe-mode`, `--restricted`, `--disable-slash-commands` | None of the user's or a project's settings, hooks, skills, plugins, commands, agents or `CLAUDE.md`. Without them a `CLAUDE.md` of the folder, of a folder above it and of the user each reached the answer; `--system-prompt` alone did not keep them out |
| `--permission-mode dontAsk`, `--permission-prompts none` | What would ask for a permission is refused, never allowed |
| `--max-turns 1` | The answer, then the end. Not in `--help`, but taken. **Not a guard by itself:** with a tool allowed on purpose, one call ran before the limit ended the run |
| `--no-session-persistence` | Nothing of the chat is written under `~/.claude` |
| `--system-prompt …` | The island's own instruction (text only, no tools, short) instead of the coding assistant's |

- The command's first line says what it runs with. A tool, an MCP server or
  another folder there ends it before a question is answered; a model that
  reaches for a tool all the same ends it at that moment. A Claude Code that
  does not know one of the options ends with an error and is **not** tried
  again with fewer.
- It always runs in `~/.local/share/dynamicisland/ai-sandbox`, an empty
  folder of the island's own (made for the owner only), never where the shell
  or a project is. The question goes to its standard input, not to an
  argument, so it is not in the list of processes.
- The island opens no file under `~/.claude`; the sign-in state is asked of
  the command (`claude auth status`), and only "signed in or not" is read.
- **A follow-up** carries the earlier messages along. Resuming a session
  (`--resume`) works too, but it writes the chat to `~/.claude/projects/`;
  telling it again keeps nothing on disk and is the same for every source.
  All of the chat goes with every question, so a long one says so and offers
  "New chat".
- `--bare` would also switch most of this off, but it does not use the
  subscription sign-in ("Not logged in").
- **Other commands:** Antigravity's `agy` has a print mode but no option that
  switches its tools off (only a terminal sandbox and a plan mode), so it is
  not offered. `gemini`, `codex` and `ollama` were not installed here.

`tools/ai-cli-check [--user-memory] [--trace]` asks the real Claude Code
through this provider and checks: an answer in pieces, from the island's
folder, the question in no argument; asked to list files, to make files and
run a command, or to search the web, nothing is listed, made, run or
searched; a `CLAUDE.md` of the user (made for the check, then removed) does
not reach the answer; the island's own process opens no file under
`~/.claude` (strace); the folder stays empty and no chat is kept.

### On the island

The page asks for a taller island while a conversation is shown. While an
answer is written the island stays open without the pointer; Escape lets it
go, and the answer goes on. Then, with the page not on screen: three dots as
a quiet live activity, below every other one, and when the answer is
complete the event "Answer ready" (a click opens the tab; it can be switched
off, the dot on the tab stays). Nothing of the tab runs while no answer is on
its way.

### Adding a source

A source is a file under `ai/` with `AiProvider` as its root (`detect`,
`verify`, `listModels`, `send` with the answer in pieces, `cancel`) and an
entry in `ai/AiCatalog.qml`. One that speaks the OpenAI protocol needs only
the entry. `AiBackend` talks to nothing else, and what went wrong is said in
the same words for every source (`ai/AiStream.js`).

## Cloud

A tab for the clouds of this computer, the counterpart of a menu bar's cloud
icon: folders and files **by name** (with size and date), how full each cloud
is, its sync state where something says it, alerts, a file dragged out to the
desktop, files dropped in to upload. It is **off** until switched on (Settings
→ Layout or Cloud); while it is off none of it is loaded.

The clouds are the remotes of the user's **rclone** (Google Drive, OneDrive,
Dropbox, Nextcloud/WebDAV, a server of one's own: whatever `rclone config`
set up). The island only runs the `rclone` command and reads what it prints;
rclone's configuration file, its tokens and passwords are never opened
(checked with strace: the island's process opens no `rclone.conf`). Without
rclone the page says so and shows the install command to be copied.

- **What it can do to a cloud:** list a folder (one level, `lsjson`), ask how
  full it is (`about`), measure a folder (`size`), copy from it and to it
  (`copyto`, `copy`). It cannot delete, move, rename or sync, and it shows no
  content: no preview, no thumbnail.
- **Commands** are lists of arguments, never a shell line. A remote is only
  one `rclone listremotes` named; it and the path go as one argument,
  `remote:path`, after `--`, so a name that begins with a dash or holds `$`,
  `;` or quotes is a name and nothing else (`cloud/Rclone.js`,
  `tests/rclone.test.js`, `tests/tst_cloud.qml`).
- **The folder:** one level at a time, kept for a minute (the refresh button
  asks again), at most 2000 rows of which only those on screen exist; a
  search over the open folder; ordered by name, date or size. A name is
  shown as plain text, without control characters, cut when very long.
- **Out:** a file has to be on this computer before it can be dragged, so it
  is fetched into `~/.cache/dynamicisland/cloud` first: a small one (25 MB
  unless changed) when the pointer rests on it, a larger one when asked;
  then its row says "drag". A click on a file also offers Download (to the
  Downloads folder, as "name (1)" rather than over a file that is there),
  Show in folder and Copy path. A folder is measured first, asked about when
  large and refused above 5 GB or 5000 files. **A whole folder:** a folder
  one has opened is fetched whole by itself when it is small (up to four
  times the single-file limit and 300 files; never the cloud's top), and
  then it ("Folder · drag" beside the search) and every row in it can be
  dragged out at once. A click on that chip ("Download all") downloads the
  open folder to the Downloads folder. A row pulled before it is here is
  fetched then, and can be pulled once it says "drag". The cache keeps to its limit
  (500 MB) by dropping the oldest files; Settings → Cloud clears it.
- **In:** files or folders dropped on the list (or chosen with "Upload…") are
  copied into the open folder after a question: how many, how much, where.
  A file that is there already is asked about: Keep both (a new name), Skip,
  Overwrite; never silently. The files on this computer are only read.
  Files dragged onto the small island open it on the tab. Copies show as the
  island's transfers, with "Sent", or "Failed" and "Try again".
- **How full:** `rclone about`, where the cloud answers it (not every kind
  does; then nothing is shown). Asked every ten minutes while the page is on
  screen, else every three hours and only if alerts are on.
- **Sync state** is never made up. rclone copies when asked and keeps none.
  A Dropbox remote takes it from the Dropbox client's own `dropbox status`;
  Syncthing, found through its local interface, has a card of its own and
  asks once for its API key (kept in KDE Wallet); every other cloud says
  "Sync state unknown" and why. Asked every ten seconds, only while the page
  or the indicator wants it and such a client exists.
- **Alerts:** storage nearly full (90 %) or full (98 %), a sign-in that ran
  out (with `rclone config reconnect NAME:` to be copied), a cloud that
  cannot be reached, a sync error. Each is an event that opens the tab, is
  said again only after its pause (6 hours), and ends with its cause.
- **On the island:** while something syncs, a cloud with its progress, below
  every other activity; "Synced" when done.

## Clipboard

A page with the history of Plasma's own clipboard (Klipper), so it shows the
same entries as the clipboard popup of the system tray: texts, code (in a
monospace font), images (as thumbnails) and copied files.

- Click an entry to copy it again. Clicking an image opens it large on the
  page itself (back, copy, remove); the island stays open.
- Search field, stars and the starred-only filter, clearing the history
  (asks once more).
- Under the mouse: star, show as a QR code, edit the text, run the actions
  configured in Klipper ("open with…"), remove the entry. While that actions
  menu is open the island stays open, even with the pointer away from it; it
  closes once something is chosen or the menu is dismissed (needs the native
  module).
- History size and what is kept are Klipper's own settings (System Tray →
  Clipboard → Configure Clipboard…).

The page can be turned off in Settings → Layout.

## D-Bus API

Any program can push its own live activity:

| | |
|---|---|
| Service | `org.phobby.DynamicIsland` (session bus) |
| Object | `/org/phobby/DynamicIsland` |
| Interface | `org.phobby.DynamicIsland` |
| `Push(s id, a{sv} props)` | Create/update an activity |
| `Update(s id, a{sv} props)` | Same as `Push` |
| `Finish(s id, s status)` | Finish; `success` (green), `error` (red), `cancel` or `""` (silent) |
| `Flash(a{sv} props)` | One-off momentary event |
| `List() → as` | Active ids pushed over D-Bus |
| signal `ActivityClicked(s id)` | The user clicked the activity or its finish event |

`props`: `title` s, `subtitle` s, `icon` s, `progress` i (0–100, −1 = none),
`color` s (`red|green|blue|orange|purple|gray` or `#rrggbb`), `trailing` s,
`priority` i, `category` s (`timer|transfer|recording|call|media`; default
`transfer`), `timeout` i (s, finish automatically), `duration` i (ms, Flash
only).

### island-push

```bash
island-push --id build --title "Build" --progress 40 --icon run-build
island-push --id build --progress 80 --subtitle "linking…"
island-push --id build --done --status success
island-push --flash --title "Backup done" --icon document-save --color green
island-push --list
```

### notify-done

```bash
source ~/dev/plasma-island/tools/notify-done.sh   # in ~/.bashrc or ~/.zshrc
notify-done make -j16        # in the island while it runs, then a green "Done" / red "Failed"
```

The exit code is preserved, so chains such as `notify-done make && ./run` keep
working.

### From another program (Go example)

```go
package main

import (
	"time"

	"github.com/godbus/dbus/v5"
)

func main() {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		panic(err)
	}
	island := conn.Object("org.phobby.DynamicIsland", "/org/phobby/DynamicIsland")
	const iface = "org.phobby.DynamicIsland."

	for p := 0; p <= 100; p += 20 {
		island.Call(iface+"Push", 0, "sync", map[string]dbus.Variant{
			"title":    dbus.MakeVariant("Synchronisation"),
			"subtitle": dbus.MakeVariant("Nextcloud"),
			"icon":     dbus.MakeVariant("folder-sync"),
			"color":    dbus.MakeVariant("blue"),
			"progress": dbus.MakeVariant(int32(p)),
		})
		time.Sleep(time.Second)
	}
	island.Call(iface+"Finish", 0, "sync", "success")

	// To listen for clicks:
	conn.AddMatchSignal(dbus.WithMatchInterface("org.phobby.DynamicIsland"), dbus.WithMatchMember("ActivityClicked"))
}
```

With `busctl`: `busctl --user call org.phobby.DynamicIsland /org/phobby/DynamicIsland
org.phobby.DynamicIsland Push 'sa{sv}' demo 2 title s "Hello" progress i 50`

## Using it alongside Plasma's OSD

When volume or brightness changes the island shows a thin slider; Plasma's own
OSD keeps appearing too. Pick one of them:

- **Turn off the indicator in the island:** Settings → Activities → "Volume,
  brightness and audio output".
- **Turn off Plasma's volume OSD:** System Settings → Sound → the menu at the
  top right (⋮) → on the configuration page, untick the
  volume/microphone/mute options under "Show OSD popups for changes to:".
  Plasma 6 has no setting to turn off the brightness OSD; nothing that could
  break the system was changed.

## Known limitations

- **Click region on X11:** written for both, but tried only on Wayland. On
  X11 `setMask` also clips what is drawn, so the shadow and the glow outside
  the shape may be cut there.
- **Dragging onto the island:** as before, only the visible island takes a
  drag (it opens and the page takes the drop); the region is not widened
  while something is dragged.

- **Double notifications:** Plasma's own notification popups cannot be turned
  off. The island shows notifications *in addition*. You can move the system
  popups to another corner in System Settings → Notifications → Position.
- **Blur** needs the native helper, the "Blur" effect enabled in KWin, and
  plasmashell seeing `QML_IMPORT_PATH`. `install.sh` sets this up through
  `~/.config/environment.d/` and `systemctl --user set-environment`;
  plasmashell has to be restarted. After Plasma updates (if the Qt/KF6 ABI
  changes) rebuild with `./install.sh`.
- **Wayland positioning** relies on the plasma-shell protocol, which is
  granted to plasmashell as a privilege. It may not be possible in another
  process; on this machine it was verified to work with `plasmawindowed` too.
- **Full-screen apps:** windows of the Notification type can stay above
  full-screen videos/games.
- **Sensors:** CPU temperature is read from `cpu/all/maximumTemperature`, GPU
  from `gpu/all/usage` and the first `gpu/gpuN/temperature` found (N=0–2). If
  the driver gives no value the card is hidden. The arc on the network card
  shows the current load relative to the recent peak speed.
- **Multiple monitors:** the island sits on the screen of the containment the
  widget was added to.
- The island's small window covers a little beyond the pill (room for the
  shadow). This transparent area of a few pixels catches clicks.
- If another "dynamic island" widget (e.g. `com.arvin.dynamicisland`) is
  active at the same time the two overlap.
- **Bluetooth headphone batteries:** BlueZ only gives a single battery value.
  For headphones such as AirPods the left/right/case batteries cannot be read
  separately; a single value is shown.
- **Hotspot:** NetworkManager does not report the number of clients connected
  to a hotspot. The island only shows the ongoing "Hotspot on" activity.
- **Stopping a screen recording:** there is no general API to stop another
  app's screen capture. The expanded view has a "switch to app" button.
- **KDE Connect calls:** KDE Connect does not emit a "call ended" signal. The
  call activity ends when KDE Connect closes its call notification (or on a
  safety timeout). The SMS/message quick reply only appears for notifications
  that support replies.
- **Calendar** works by polling: with a link, a newly added event shows up
  after one update interval at the latest (Google and Apple may also update
  the .ics file with a delay on their side). An existing event cannot be
  edited from the island, only added or deleted. Deleting an iCloud event
  relies on Apple's usual file naming (`<UID>.ics`). The phone's calendar does
  not come through KDE Connect (it has no calendar plugin); it comes from
  Google/iCloud if the phone syncs there. An event may be pinned up to 20 s
  late.
- **AI, Claude Code:** that it stays a question box rests on the command
  honouring its own options; the island checks what the command says about
  itself before every answer and stops it otherwise. Settings an
  administrator manages for Claude Code still apply (the command says so); an
  MCP server from there would make it refuse to answer here rather than run
  with it. `--max-turns` is not in the command's help. Claude Code keeps its
  own state (`~/.claude.json`), which is its business. Every question uses up
  the account's usage; the model is the command's own choice unless another
  is picked.
- **AI, services with a key:** only a refused key and the services' answers
  to it were tried against the real services; a chat with a real key was
  tried against a stand-in. A service that only knows the length limit as
  `max_completion_tokens` is asked again with that name when it says so.
  Gemini is reached through Google's OpenAI-compatible address. No server-side
  fallback, thinking or effort setting is sent to the Anthropic API.
- **AI, keyboard:** the island takes the keyboard when the field is clicked
  (as on the Notes page) and gives it back with Escape; while it has it, the
  island stays open.
- **Cloud:** dragging a file out of the island and dropping files onto it
  (the page and the small island) are written the way Qt offers them and
  tested inside one program; between the island and another program they
  could not be tried here. "Download", "Show in folder", "Copy path" and
  "Upload…" do the same without dragging. Sync state exists only where a
  client says it: there is none for Google Drive, OneDrive or a Nextcloud
  reached through rclone. Syncthing's and Dropbox's states were tried
  against stand-ins, not the real clients.
- **Updates** are read from the PackageKit cache (apt/dnf packages). Flatpak
  updates are not counted.
- **The D-Bus API** binds to only one island instance at a time (the first to
  register).
- **File jobs and notifications** are only shown while the widget runs inside
  plasmashell.

## File transfers: what can and cannot be tracked

All transfers are shown through the shared `TransferActivity`/`TransferHub`:
source name, percentage, time left (mm:ss) and "Completed"/"Sent" or a red
"Failed" at the end. The time left is only shown if the source reports it or
it can be computed from the speed; no estimated/fake time is shown.

| Source | Provider | Status |
|---|---|---|
| Dolphin copy/move/delete, Ark extraction, copying to remote locations (sftp/smb/MTP) | `JobsProvider` | Full support (KDE job system) |
| KDE Connect file receive/send | `KdeConnectTransferProvider` | Full support; "Pixel 7 → Computer: photo.jpg" |
| USB/external disk (`/media`, `/run/media`) | `RemovableTransferProvider` | Full support; "USB DISK → Documents: report.pdf" |
| Browser download + the Plasma Browser Integration extension | `BrowserDownloadProvider` | Full support (percentage, time) |
| Browser download, no extension / Flatpak-Snap browser (e.g. Zen) | `BrowserDownloadProvider` + native `DownloadWatcher` | `*.part`/`*.crdownload` in the download folder are watched: downloaded size and speed, **no percentage or time left** (the browser does not write the total size to disk) |
| Upload from a browser | — | **Cannot be tracked**: browser uploads never reach any system API as a job |

Why Zen downloads did not show up: Zen is a Flatpak app; from inside the
sandbox it cannot reach the Plasma Browser Integration host on the system, so
its downloads never reached the KDE job system. The folder watcher closes this
gap.
Note: the `kioclient` command-line tool does not use the KDE job tracker; use
Dolphin or `ark --batch` to test.
