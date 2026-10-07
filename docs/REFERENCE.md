# Reference: every feature in detail

The long form of what [README.md](../README.md) says in short: every state, page, setting and rule of the
island, with what was tried and what was not. How it is built and tested is in
[ARCHITECTURE.md](ARCHITECTURE.md); what it costs to run in [PERFORMANCE.md](PERFORMANCE.md).

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
- the ⌄ button at the top right of the open island;
- right click → "Shrink to dot" (also "Back to pill" on the dot).

A click on the empty room of the open island does nothing: it shrinks from
its small form, not in the middle of a page that is being filled in.
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
follows the shape on every frame of a morph. The cat beside the island (see
"Cat") adds its body to that region, as two ellipses (head and body; one
while it is curled up): not the air around it, not its tail, not its
bubble, and nothing while it is hidden. To see the region, start plasmashell
with `DYNAMICISLAND_DEBUG_REGION=1` in its environment: a red outline is
drawn around it.

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
Memos), **Clipboard** (what was copied recently: texts, code, images, files).


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
Apps, Tools, Habits, Calendar, Notes, Clipboard. The order is stored as `pageOrder`
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
it. The island stays open while editing. Stored as `controlTiles`. Holding
**Bluetooth**, **Wi-Fi** or **VPN** opens its panel instead: the paired
devices (with their battery) / the networks in range / the VPN connections;
a click connects or lets go, a new Wi-Fi network asks for its password
there. "Scan" looks for Bluetooth devices nearby (a click on a found one
pairs it) or for networks again; "Add new" opens Plasma's pairing wizard or
its connection editor. Available:
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
playing media visible, momentary event duration, a
separate switch for every system event and live activity type.
**Download tracking** tab: the main switch; the sources (browser downloads,
packages, git clone, command-line downloaders); background jobs too (off by
default); how long something must have lasted and how large a command-line
download must be to be shown; whether the end is said; the watched folders
and how long a finished file is waited for; the watched commands (the
defaults can be switched off one by one, own names added).
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
**Suggestions** tab: on/off (off until you switch them on: nothing is
suggested and nothing learned before), the least pause between two
suggestions (5 minutes), and every rule with its switch, its mode (asks / automatic), what
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
**Cat** tab: the cat beside the island: on/off, side, size, coat, what it
reacts to, what may be done to it, sleep, the dot, reduced motion, and a
preview that is the cat itself; see "Cat" below.
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
off the GUI thread. A link may send up to 10 MB and take up to 30 seconds
(`backend/IcsDownload.qml`): one that says it is larger is not downloaded,
one that grows past that or is not there in time is cut off and dropped
whole. The settings page then says which link and why, and the calendar
keeps the link's last good copy.

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
- **The wheel:** the places a search found and a day's hours are lists that
  keep their scroll (see "The wheel" above, `tests/tst_wheel.qml`): at their
  end the page is not turned, which would close the search or the day.
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

Few, and only where they have proved welcome. At a rule's moment the island
may ask one short question, do the thing by itself (saying so, with an Undo),
keep the suggestion quietly for when the island is opened, or say nothing: it
decides from what it has learned about that rule in that context. Rules and
counting only, on this computer: no network, no model.

| Rule | Moment | What it does | Taken back |
|---|---|---|---|
| Do Not Disturb before an event | The pinned calendar event is about to start | Do Not Disturb until the event ends | Plasma ends it at the event's end |
| Pause media before a video meeting | …and it has a video link while something plays | Pauses the media | no |
| Hide notifications while the screen is recorded | Screen recording or sharing starts | Do Not Disturb | when the recording stops |
| Pause media when the microphone is used | An application takes the microphone while something plays | Pauses the media | plays again when the microphone is free |
| Do Not Disturb in a focus round | A Pomodoro focus round starts | Do Not Disturb | at the break |
| Save power when the battery is low | The battery reaches the low threshold of Alerts | Power saving profile | the profile it had, on the charger |
| Pause media when the headphones go away | The audio output stops being headphones while something plays | Pauses the media | no |
| Carry on playing with headphones (experimental, off) | Headphones are connected while the media is paused | Plays | no |

A rule whose part of the system is missing or switched off never comes up
(no battery: no battery rule). "Carry on playing" is marked experimental and
off until it is switched on: headphones are told from a device's name and
port, which can be wrong, and starting to play is the one thing here that
makes noise.

**What it learns from.** The unit is (rule, context). A context is a few
coarse buckets: weekday or weekend; morning, midday, evening or night; for an
event the calendar's name, whether it is short, up to 90 minutes or long, and
whether it has a video link; for the microphone rule whether the output is
headphones or speakers. Never a window title, an application, an event's
title, a text or a key press. Signals and their weights
(`Suggestions.TUNING`, the one place every number is):

| Signal | Weight |
|---|---|
| Yes | +1 |
| Always (automatic there at once) | +3 |
| Done by hand within two minutes of the rule's moment | +0.7 |
| No | −1.5 |
| Not now, the card closed | −0.4 |
| No answer in time | −0.15 |
| Undo of an automatic action, or switching it back by hand | −3 |

Confidence is a = 1 + the positive weights, b = 1 + the negative ones,
a / (a + b); each weight halves every 30 days. With less than about three
answers' worth known about a context, its estimate is mixed with the rule's
estimate over all contexts. Below 0.25 the rule stays silent there; from 0.8
with at least four welcome signals on two different days, or after it was
done by hand four times, the island asks once "shall I do this by myself?";
accepted, it is automatic in that context.

**How it comes.**

- *A card* only for what is over within minutes, at most six a day, not
  within a rule's wait (20 minutes after a card, doubled with every answer in
  a row that was not a yes) nor within the pause between two cards. Yes ·
  Always · No, and behind "⋯" Not now · Turn this rule off; under the question
  a "Why?" line ("You said yes to 4 of the last 5 here."). Several things for
  one moment are one card with a tick each, learned separately.
- *A mark* on the pill's corner (in dot mode the dot pulses): the suggestion
  waits as one line in the open island, at most three.
- *Quietly*, the same without the mark: while Do Not Disturb is on, an
  application is full screen, the screen is recorded or the microphone is in
  use (the recording's and the microphone's own questions excepted).

A suggestion whose moment has passed goes away by itself, and that and a
suggestion nobody saw teach nothing. No answer is not a no.

**Automatic, safely.** Only things that are local, small and can be taken
back are ever done: Do Not Disturb, the power profile, pausing and resuming
media. What a rule switched on is remembered as its own and taken back when
its cause ends, and only that: Do Not Disturb the user had on already, or
changed in between, is left alone. Each automatic action is said, with "Undo";
an undo (or switching it back by hand) puts that context back to asking, and
a second one closes the rule there, which is said once.

**Settings → Suggestions:** how much it may interrupt (Quiet: silent below
0.35, two cards a day, double waits · Balanced · Active: silent below 0.15,
twelve cards, half waits), the cards a day, the waits and the half-life; each
rule's mode (learns by itself, always asks, automatic, off); "What I learned":
per rule and context what it does now and how sure it is, with "forget this
context" and "reset this rule", and the last seven days in numbers; "Done
automatically", the last 50; export and reset.

**Kept** as one small JSON (`~/.local/share/dynamicisland/suggestions.json`,
schema 2): per signal the rule, the context, the kind of signal and the
moment, the last 200; older ones are folded into decayed sums. The first
version's counters are carried over as what is known about a rule in general.
Nothing polls: everything happens on a change of something.

`tests/suggestions.test.js` simulates weeks of answers with dates handed in;
`tests/tst_suggestions.qml` runs the provider on stand-ins with a clock of
its own; `tests/tst_suggestions_island.qml` what the island shows.

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

**Its picture** is a generic "sparkles" sign: Lucide's `sparkles` (ISC licence,
`contents/icons/ai/`, the same set as the weather pictures), embedded and drawn
in the theme's colour on the tab, on the island's AI activity and, in a copy
for a dark and one for a light window, on the settings page. It is not the logo
of any company, and none is used.

### What can answer

Sources are connected on the page itself. What is found on this computer is
offered first; a command that installs or starts something is only ever shown
to be copied, never run.

| Source | How it connects |
|---|---|
| **Claude Code** | The `claude` command of this computer (on the PATH or in `~/.local/bin`), already signed in: no key, and the island never sees an account. Found by itself. See below for what it is run with |
| **Antigravity** | The `agy` command of this computer, already signed in: no key. Offered only when it is found. It cannot be started without its tools; see below for what is done about that |
| **Ollama** | `http://localhost:11434/v1`, found by itself: answering, installed but not running ("Start it": `ollama serve` to copy), or not found (the install command to copy). No account, no key; nothing leaves the device |
| **LM Studio**, **llama.cpp**, **Jan**, **KoboldCpp** | Looked for at the address each listens on unless told otherwise (`localhost:1234`, `127.0.0.1:8080`, `localhost:1337`, `localhost:5001`, each `/v1`); offered only while one answers there with a list of models. No account, no key |
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
- **Antigravity (`agy`)** is offered since it was asked for, with less than
  the above: its print mode has no option that switches its tools off (its
  first line lists some sixty: files, commands, a browser, the web), none
  for an instruction of its own and none for keeping nothing. What is done
  instead (`ai/AntigravityProvider.qml`, `ai/Antigravity.js`): it is started
  in the island's empty folder with `--sandbox --disable-slash-commands`,
  never with `--dangerously-skip-permissions`; started this way it refuses
  by itself whatever needs a permission (seen with 1.2.17: reading
  `/etc/hostname` was refused); its first line must say that it asks
  (`request-review`) and that it is in the island's folder, else it is
  stopped before an answer; and the first step that is not text stops it at
  once. A tool that needs no permission, or one allowed in Antigravity's own
  settings, may have run by the time it is stopped. The instruction goes in
  front of the question, and Antigravity keeps every question in its own
  history (`~/.gemini/antigravity-cli`). The notice before the first
  question says so. `gemini`, `codex` and `ollama` were not installed here.

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

## Cat

A cat lives beside the island (Settings → Cat; on by default, off with one
click or from its own right-click menu). It is there to be looked at: it
never covers anything of the island, never opens or closes it, keeps
nothing (what it feels lasts until the shell stops, and is forgotten
whenever it is hidden) and asks nothing of the network. There is no sound.

**What it does**

| What happens | The cat |
|---|---|
| Nothing but the clock for 20 s (a setting) | yawns, curls up, sleeps: zzz |
| Something comes up: a notification, an event, another activity | wakes with a stretch, pricks its ears, looks |
| Music plays | headphones on, and it nods: to the music's own beat while the ambient glow listens anyway (the cat never starts the listening), else at a calm 80 to the minute |
| The music stops | headphones off |
| The AI writes an answer | three dots beside its head, the head to the side |
| The answer is ready | "!" for a moment |
| A question waits for you: a suggestion's card, the habits' evening question (its event, its waiting activity, the review itself), a confirmation on the open page ("Delete?", "Clear all?", "Upload here?") | "?", the head to the side, until it is answered or its time runs out |
| A timer or a Pomodoro round ran out, a transfer is done | a short happy hop, the tail waves |
| The battery is low | a tired yawn |
| The pointer rests on it | it looks at the pointer |
| The pointer goes back and forth over it | stroked: eyes shut, a purr one can see, hearts; asleep it purrs without waking |
| A click | startled, curious |
| The second click in a row | annoyed: ears back |
| The third (within 3 s), or one click while it sleeps | angry: fur on end, ears flat, a hiss; then it turns its back and sulks for 10 s (a setting), deaf to clicks; the pointer gets a flick of the tail |
| A long, unbroken stroke while it sulks | it makes up, before its time |

Several of these can be true at once, which is why the cat is three
layers and not one state: a **body** (sleep, doze, wake, sit, listen,
curious, perk, cheer, tired, annoyed, pet, purr, angry, sulk), an
**accessory** (headphones) and a **bubble** (dots, ?, !, ♪, hearts, a red
"!!", zzz). Music and a thinking AI give a nodding cat with headphones and
dots. Where they clash, this wins, from the top: what you do to it
(stroking, anger, sulking, a startled look), then what calls for a moment's
attention (an event), then what is going on (music, the AI, a question),
then sleep. So an angry cat does not nod to the music (the headphones stay
on; the nodding is back once it has calmed down), and no event moves a
sulking one. Each reaction can be switched off by itself, so can stroking
and clicks, and "Never angry" makes every click a curious one.

**Stroking** is told from a pointer passing by its turns: a turn is counted
when the pointer has come back a quarter of the cat's width from where it
last turned; three turns within 1.2 s are a stroke (no button is held), and
it lasts until 1.5 s after the last turn. Resting on the cat, crossing it
once, trembling on the spot or wandering slowly are not strokes. These
numbers, the clicks' and every duration are in one file,
`companion/CompanionTuning.js`: change them there to tune the feel.

**Where it sits.** Outside the pill, beside it, on its level and a little
lower; the island hangs at the top of the screen, so there is no room above
the cat, and its bubble goes beside its head, on the far side. It follows
the pill's edge as the island changes shape: beside the open island it
stands at the top corner, outside, and covers nothing. By itself it sits on
the **left**, because the island puts what it has beside itself (the split
island's bubble, the privacy dots) on the right; set to the right it keeps
clear of both, moving over when they appear instead of jumping. Where a
side has no room on the screen (the island moved far to one side on a
narrow screen) it takes the other. A change of sides is a walk across.
While the island is a dot the cat is hidden (the dot is for being out of
the way), or sleeps beside the dot (a setting); it is back with the pill.
The window keeps room for the cat on both sides, so the island stays in the
middle. Size: 100–180 % of the pill's height (130 % by default), scaled
with the island's size setting like everything else.

The pointer on the cat is the cat's own: it neither opens the island nor
keeps it open, and going from the pill to the cat and back does not make
the island flutter (`tests/tst_companion.qml`). Its right button opens its
own small menu (hide it, its settings), not the island's.

**The drawing** is the island's own and made in code: a round, front-facing
cat of ellipses, two ears, a tail of one thick curve and a face of a few
strokes (`companion/CatPoses.js` has the numbers, `CatCharacter.qml` draws
them as vector shapes). No picture files, no sprites, no third-party
assets, so nothing to license; sharp at any size. Five coats (grey, orange,
black, white, black and white) and a colour of your own; the outline, the
eyes and the face's strokes are chosen from the coat's brightness, so a
black cat has a light outline and bright eyes with pupils, a white one a
dark outline and dark eyes. Every frame is a function of the pose it comes
from, the pose it goes to and how far it is between them, the gesture that
plays, the motion that repeats and its phase. To look at all of it:

- Settings → Cat → **Show all poses**: the gallery in the preview's place;
- `DYNAMICISLAND_CAT_GALLERY=1` in plasmashell's environment: the same
  gallery in a window of its own, in your coat
  (`systemctl --user set-environment DYNAMICISLAND_CAT_GALLERY=1`, restart
  plasmashell, and `unset-environment` afterwards);
- `tools/cat-poses [folder] [coat]`: the sheets as PNG files, drawn off
  screen (bodies, coats, layers, bubbles, every gesture in five frames,
  every repeating motion in four, the changes between poses).

**What it costs.** An animation that simply runs keeps the whole window
drawing at the screen's rate (180 times a second on a 180 Hz screen), so
nothing of the cat does:

- one timer in the character steps what is in motion and stops when
  nothing is; a change of pose and a nod get 30 frames a second, a flick of
  the tail 15, a blink is two frames;
- what goes on for long goes in few steps and moves whole parts (a squash,
  a lift, a turn) instead of reshaping outlines: a sleeping cat breathes in
  2 steps a second and its zzz in 1; nodding is 20 steps a second;
- the mind (`CompanionController`) has one timer, armed for the next moment
  something is due and not at all while the cat sleeps;
- hidden (switched off, or beside a dot when set so) nothing of it runs or
  is drawn, and the window's input region does not grow;
- with "Reduce motion", or with the desktop's own animations switched off
  (System Settings → Animation speed: instant, which Plasma's units report),
  it stands in still poses: no nodding, no fidgets, no floating hearts.

Frames drawn by the island's window (counted in the test, off screen):
sitting still 0; asleep 3 a second; asleep with reduced motion 0; nodding
20–24 a second; a sitting cat's fidgets 3 to 4 a second on average;
hidden 0. plasmashell's CPU with the screen locked (so timers only, nothing
drawn; 40 s each, `ps`-style from /proc): 0.68 % without the cat, 0.75 %
with it asleep, 0.63 % asleep with reduced motion: no difference outside
the noise. Memory: a thousand changes of everything leave the same number
of items and the memory within 2 MB; it settles (after thirty thousand:
+9 MB in the first twenty thousand, then flat). `tools/cat-measure` repeats
the CPU measurement in your shell, cat off / on / off.

**Settings → Cat:** show it; side (by itself, left, right); size; coat;
reactions (music, the AI and questions, events); stroking, clicks, never
angry, how long it sulks; after how long it falls asleep; hidden or asleep
beside the dot; reduce motion; "Show all poses". The preview above them is
the cat itself with what is set before it is applied: it can be stroked and
clicked, and buttons let happen what the island would tell it.

**How it is made** (`contents/ui/companion/`):

```
CompanionTuning.js       every number: strokes, clicks, durations, fidgets
Companion.js             the rules, as functions of a state and a moment (no timers, no drawing)
CompanionController.qml  runs them: facts in, layers out (body, accessory, bubble, tilt, gesture())
CompanionFeed.qml        reads the ActivityManager, the island and the AI backend; writes nothing back
CatPoses.js              the cat's poses, gestures and motions as numbers
CatCharacter.qml         draws them; drawing only
CompanionBubble.qml      the bubble; belongs to no character
Companion.qml            on the island: placement, the pointer, the input shapes
CatGallery.qml           every pose and frame, to look at
```

The mind knows no cat and the cat no mind: another character is another
file like `CatCharacter.qml` with the same properties (`body`, `accessory`,
`tilt`, `look`, `gesture()`, `beat()`, `still`, `running`, `mirrored`,
`touch`, `bubbleAt`). The cat only watches: so that it need not guess from
icons, an event may say what it is like (`feel`: done, low, ask), an
activity that it asks (`asks`), and a page that a question of its own waits
(`asking`, handed on like `interacting`); the island does nothing with any
of them. Tests: `tests/companion.test.js` (the rules, with the clock and
chance handed in), `tests/tst_companion.qml` (the real island with the cat
beside it), `tests/still/` (the desktop's animations off), the Cat page in
`tests/tst_settings.qml`.

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

- **Cat:** drawn and tested off screen and with the GPU renderer in a
  hidden window (the pictures match); its rules, placement, input shapes and
  pointer handling are tested on the real Island component with synthetic
  pointer events. Not yet looked at on the real screen (the session was
  locked while it was built): the look beside the real pill over a
  wallpaper, a click passing through beside the cat to a window underneath
  (the region itself is the tested shapes, handed to the same
  `QWindow::setMask` as the island's), stroking with a real mouse or
  touchpad (the thresholds are a first guess: `CompanionTuning.js`), and
  CPU with the screen on (`tools/cat-measure`). Not tried at all: several
  monitors and a screen so narrow that the cat must change sides (the rule
  is tested with made-up room), X11.
- **Download tracking:** tried with the real programs: Zen (Flatpak) with a
  5 MB and a 1.1 GB file, two at once and a second file of the same name;
  `git clone` (done, a repository that does not exist, interrupted); `wget`,
  `curl`, `pip download`, `apt download`; a PackageKit download. Not tried:
  `sudo apt update/install` (needs a password; its stages, bytes and results
  are only played with a made-up `/proc` and `/var` in the tests), a Chromium
  browser and Firefox as a Snap (their sequences are replayed, not run),
  pausing or cancelling inside the browser, a long PackageKit transaction's
  percentage, Plasma Browser Integration (its extension is not installed in
  either browser here). `user.xdg.origin.url` is read for the host where a
  browser writes it; Zen does not.

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
- **AI, Antigravity:** not as tight as Claude Code (see "Claude Code: a
  question box, not an agent"): its tools exist and are only refused or
  stopped, and its history keeps the questions. Tried with the real command
  (1.2.17): connecting, two questions, a refused file read.
- **AI, model servers found by themselves:** LM Studio, llama.cpp, Jan and
  KoboldCpp were not installed here; only that nothing is offered when
  nothing answers was seen.
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
source name, the stage, "412 MB / 1.8 GB" ("412 MB / unknown" where the size
is not known), percentage, smoothed speed, time left (m:ss) and time so far.
The percentage and the time left are only shown where the size is known or
the source reports them; nothing is estimated from a made-up total. At the
end: "Downloaded"/"Completed"/"Sent" with the name, the size and the time it
took; a red "Failed" only where something says it failed; a plain
"Cancelled"; and a plain "Finished" where nothing tells how it ended.

| Source | Provider | Status |
|---|---|---|
| Dolphin copy/move/delete, Ark extraction, copying to remote locations (sftp/smb/MTP) | `JobsProvider` | Full support (KDE job system) |
| KDE Connect file receive/send | `KdeConnectTransferProvider` | Full support; "Pixel 7 → Computer: photo.jpg" |
| USB/external disk (`/media`, `/run/media`) | `RemovableTransferProvider` | Full support; "USB DISK → Documents: report.pdf" |
| Browser download + the Plasma Browser Integration extension | `BrowserDownloadProvider` | Full support (percentage, time) |
| Browser download, no extension / Flatpak-Snap browser (e.g. Zen) | `BrowserDownloadProvider` + native `DownloadWatcher` | `*.part`/`*.crdownload`/`*.opdownload` in the download folder are watched: downloaded size and speed, **no percentage or time left** (the browser does not write the total size to disk). Ends as "Downloaded" or "Cancelled" |
| `apt`, `apt-get`, `aptitude`, also under `sudo` | `CommandTransferProvider` + native `CommandWatcher` | The stage (package lists / downloading / installing), the size of the packages that have arrived, **no percentage, no byte-exact speed** (root's process and apt's `partial` folders cannot be read). The result from apt's own records, else "Finished" |
| Discover / PackageKit | `CommandTransferProvider` + native `PackageKitWatcher` | Full support: the daemon's own percentage, speed and remaining time |
| `git clone` | `CommandWatcher` | Size of the pack being received and speed, **no percentage**. "Downloaded" with `.git/HEAD` there, "Failed" when git removed the folder (also after Ctrl+C) |
| `wget`, `curl`, `aria2c`, `yt-dlp`, `pip`, `npm`, `cargo`, `docker pull`, `flatpak`, `snap` of the same user | `CommandWatcher` | The bytes the process has written and their speed (for pip/npm this includes what they unpack), **no percentage**; ends as "Finished": an exit code cannot be seen from outside. `flatpak`/`snap`/`docker` download in a system service, so they show without bytes |
| Upload from a browser | — | **Cannot be tracked**: browser uploads never reach any system API as a job |

Why Zen downloads did not show up: Zen is a Flatpak app; from inside the
sandbox it cannot reach the Plasma Browser Integration host on the system, so
its downloads never reached the KDE job system. The folder watcher closes this
gap.
Note: the `kioclient` command-line tool does not use the KDE job tracker; use
Dolphin or `ark --batch` to test.

**The "Failed" after a download that went well.** Zen and Firefox rename the
partial file while they write it: recorded from Zen 1.22, a download of
`name.bin` starts as an empty `name.bin` and `J-w3DTrx.bin.part`, which
becomes `name.p6NHCVxw.bin.part` 80 ms later and `name.bin` at the end.
Chromium starts as `Unconfirmed 123456.crdownload`. The watcher used to guess
the final name by cutting off the suffix and took every rename for the end:
no file of the guessed name, so "Failed", twice for one download. It now
follows the file itself (its inode): renamed to another partial name it goes
on, renamed to anything else it is done under that name. A partial file that
is gone without one is waited for (3 s, Settings → Download tracking) under a
matching name (`name.bin`, `name(1).bin`, `name (1).bin`, at least as large);
none, and it was cancelled. `tests/tst_downloads.qml` replays the recorded
sequences in a folder.

**Commands, seen from outside** (`native/core/commandwatcher.h`): nothing is
installed or wrapped and no shell file is touched. `/proc` is read every 3 s
for the watched commands (2.8 ms per look with 360 processes here: about
0.1 % of one core) and every second while one runs; a command shorter than
that may be missed. A process without a terminal (unattended-upgrades, a
cron job) is left out unless asked for. What cannot be had: a total size
(so no percentage and no remaining time), an exit code, and for root's apt
its bytes as they arrive. apt's result is taken from
`/var/lib/apt/periodic/update-success-stamp` (update) and the new entry in
`/var/log/apt/history.log` (an `Error:` line = failed); no record, no claim.
A command line may hold a token or a password: it is read for the
sub-command, the host and a repository's name and dropped; no signal, text
or log holds an argument as it was (`tests/tst_commands.qml` looks for a
planted secret in everything that comes out). The watchers run inside the
island's native module, not in a helper process: they are a timer and a few
small files per look, add about 0.5 MB, and a second process would need its
own start, stop and channel for no gain.
