# Dynamic Island — Plasma 6 plasmoid

A pill-shaped plasmoid that sits at the top centre of the screen and works
like the iOS Dynamic Island. Its look is a metallic glass inspired by Oxygen
(graphite gradient, silver rim, top highlight, inner and outer shadow), with
the background blurred by KWin.

Tested on: Kubuntu, Plasma 6.6.6, Qt 6.10.2, Wayland.

## States

| State | When | Appearance |
|---|---|---|
| Idle | Nothing is going on | Small pill (180×36): clock or status dot; a ⏸ mark when media is paused |
| Live activity (compact) | The highest-priority ongoing activity | Media: album art + track name + equalizer. Others: coloured icon on the left, time/value or progress ring on the right |
| Split island | Two ongoing activities at once | The first in the main pill, the second in a circle that splits off to its right like a droplet (minimal view) |
| Notification | A new notification arrives | App icon (phone badge for KDE Connect), app name, title, first line of the text. Left click runs the default action, middle click dismisses |
| Momentary event | Charging, Bluetooth, volume, Caps Lock… | Wide pill: icon, title, and a ring / battery / slider / button on the right. After 2–4 s the island returns to where it was |
| Expanded | Mouse hover or click | Pages (below) |
| Privacy dots | Microphone / camera in use | Orange (microphone) / green (camera) dot to the right of the island, visible in every state |

Expanded pages: **Activities** (all ongoing activities, actions and privacy
details), **Media**, **System** (information only: CPU, CPU temperature, GPU,
RAM, battery, network ↓/↑ and disk cards; Fixed or Dynamic view),
**Notifications** (last 3, arrival time, quick reply, "clear all" with
confirmation), **Controls** (Do Not Disturb, Night Light, power profile,
Bluetooth, Wi-Fi, updates; volume and screen brightness sliders below),
**Tools** (timer, stopwatch, Pomodoro, alarm), **Calendar** (month view, the
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
as on iOS. Pages are switched with the tabs, the mouse wheel or a touchpad
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
| Style | Follow the colour scheme / Always dark (graphite, default) / Always light (aluminium) |
| Transparency | Surface opacity (30–100 %). At least 90 % is applied without blur |
| Blur | Blur the content behind (needs the native helper) |
| Clock | Clock when idle and in the expanded header |
| Distance from top / below panels | Position |
| Notifications, display time | Behaviour when a notification arrives |
| Hover delay / close on leave | Default 120 ms / 400 ms |
| Preferred player | E.g. `spotify`. This player is shown if it is playing (or nothing else is); if empty Plasma chooses. Matches the identity/desktop file name case-insensitively |
| Modules | Media (also enables the live activity), System, Volume, Recent notifications |
| System view | Fixed (5 cards, 2 rows) / Dynamic (default: the cards that are active right now grow, no gaps; with few active cards the two busiest stay large). In both views the card under the mouse grows and shows its details. Clicking a card opens `btop` in the default terminal with only that metric's graph (needs the native module and btop ≥ 1.4; btop's own configuration file is not touched) |

**Activities** tab: priority order (up/down), split island on/off, keep
playing media visible, watch the download folder, momentary event duration, a
separate switch for every system event and live activity type, expanded pages.
**Alerts** tab: low/critical battery threshold, Bluetooth device/phone battery
threshold, CPU/GPU temperature threshold.
**Calendar** tab: on/off, how many minutes before the start to pin (15), how
many minutes after the end to disappear (10), all-day events, update interval
(5 min) and the connected calendar links ("Connect a Calendar" wizard; see
below).
**Tools** tab: timer/alarm sound (a file can be chosen), Pomodoro durations
and number of rounds.

The end times of the timer, stopwatch, Pomodoro and alarm are stored in the
settings; they carry on where they were even if plasmashell restarts.

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
    │                          Stopwatch, Pomodoro, Alarm, Calendar, KdeConnect,
    │                          Thermal, Updates, Dbus, Unlock; for transfers
    │                          KdeConnectTransfer, RemovableTransfer, BrowserDownload
    ├── TransferActivity.qml, TransferHub.qml, TransfersCard.qml   shared transfer activity
    ├── Theme.qml, IslandShape.qml, ActivityCompact/Minimal/Card.qml, EventBanner.qml,
    │   BatteryGlyph.qml, MiniRing.qml, …        shared visual language
    ├── *Module.qml, *Page.qml                    expanded pages
    ├── Calendar*.qml                             calendar page, connect wizard, accounts, new event
    ├── NotesPage.qml                             notes list, quick note, editor, connecting apps
    ├── ClipboardPage.qml                         clipboard history: copy again, search, star, edit, QR
    ├── NativeBridge.qml, BlurBridge.qml          import the native modules
    └── config*.qml                                settings pages
native/
├── windowblur.*               org.phobby.dynamicisland.effects (shaped KWin blur)
└── core/                      org.phobby.dynamicisland.core:
                               PipeWireWatcher, DBusSignalWatcher, Launcher,
                               UpdatesChecker, DownloadWatcher, SecretStore,
                               LoopbackServer, LocalTools, IslandService (D-Bus API)
tools/island-push, tools/notify-done.sh
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
  `betternotes show <id>` and quick notes are added with `betternotes new`.
  The change date, lock state and next reminder (an orange badge) come from
  its SQLite database, which is opened read-only and never written. Notes are
  shown read-only; "Edit in BetterNotes" starts the app, which has its own
  rich editor. The list follows changes at once (the data folder is watched).
  These notes stay on this computer and do not appear on other devices.
- Tokens are stored in KDE Wallet (folder "Dynamic Island"), never in the
  configuration file, and are deleted when an app is disconnected.
- Settings → Notes: connected apps (disconnect), the default app for quick
  notes, how often notes are fetched (2 minutes by default).

Not supported: **Standard Notes** (its notes are end-to-end encrypted; reading
them needs Argon2id and XChaCha20-Poly1305, i.e. libsodium, which the native
module does not link yet) and **Obsidian** (only through the community "Local
REST API" plugin; not done).

## Clipboard

A page with the history of Plasma's own clipboard (Klipper), so it shows the
same entries as the clipboard popup of the system tray: texts, code (in a
monospace font), images (as thumbnails) and copied files.

- Click an entry to copy it again.
- Search field, stars and the starred-only filter, clearing the history
  (asks once more).
- Under the mouse: star, show as a QR code, edit the text, run the actions
  configured in Klipper, remove the entry.
- History size and what is kept are Klipper's own settings (System Tray →
  Clipboard → Configure Clipboard…).

The page can be turned off in Settings → Activities.

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
