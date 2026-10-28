# The clips: how each one is shot

Every clip in the README is recorded in `tools/nested-session`: an isolated
Plasma session (Breeze Dark, a desktop of one colour, 1920x1080 at scale 1)
with an opaque 32 px top panel, the island as it comes (the Symbiot Black
notch) and made-up data (`tools/demo/make-data`), the demo player
(`tools/demo/player`) and a local server (`tools/demo/serve`). Nothing of the
author's desktop, files, accounts or place can be in a clip: the session has
another home and no way to the real ones.

Clips are 800 px wide, cut to the top middle of the screen (`560,0,800,110`
for the notch with the cat, a notification and the glow; the open island
needs more height, see below), at 15 pictures a second (what Spectacle gives
over D-Bus), with up to 256 colours, 8–13 s, looping. The clips of the old
rounded pill were taken out when the notch became the island's shape.

## Recorded by script, headless

`tools/demo/scenes --headless` records these without anybody at the screen
(`tools/demo/scenes --list` says what each shows):

| Clip | What it shows |
|---|---|
| `notch-states.gif` | the notch with the clock and the cat; a notification; an activity with its progress, "Done" |
| `notifications-arrival.gif` | two notifications from two apps arrive on the notch |
| `media-controls.gif` | a track on the notch, the next one, paused and playing again |
| `media-glow.gif` | the album glow switched on and off while music plays |
| `media-cat.gif` | the cat puts on headphones and nods when music starts |
| `notch-colours.gif` | the notch black, then its own gradient; Aurora, Ocean, Sunset, back to Symbiot Black |
| `cat-sleep.gif` | the cat falls asleep, a notification wakes it |
| `recording-indicator.gif` | a screen recording starts: the blinking red dot and its time; it ends |
| `language-switch.gif` | the language switched to Turkish and back while the recording shows |
| `call-incoming.gif` | the cat asleep; a call comes in, the cat wakes |
| `suggestions-card.gif` | suggestions switched on; a recording starts and the notch asks |
| `island-push.gif` | an activity pushed with `island-push` |
| `downloads-tracking.gif` | a download from the local test server, "Finished" |
| `calendar-pinned.gif` | an event pinned before it starts, then started |
| `window-dodge.gif` | *Slides up*; a `kcalc` window moved up under the notch (a KWin script, `tools/avoid/move.qml`): the notch slides up; the pointer at the top edge: the light, then open; the pointer goes: back up; the window moved down: the notch back (crop `560,0,800,300`) |
| `dot-mode.gif` | a click on the notch: the dot; a click on the dot: the notch |

The pointer of `window-dodge` and `dot-mode` is `tools/eipointer`: KWin's
emulated input inside the headless session (never the real pointer). The
pictures do not show a pointer, said in their captions; a click is made and
the pointer moved away at once, since one resting on the notch opens it.

Two of them use stand-ins inside the session, said in their captions: a
screen recording is a GStreamer source of black pictures that a made-up
"Recorder" reads through PipeWire (the island sees it as any screen
recording), and a call is the D-Bus signal KDE Connect sends, sent with a
made-up caller.

## Need a pointer: to be recorded in a windowed session

These need a pointer that can be seen, typing or a drag between programs, so
they are shot by hand (or `tools/eipointer` for a first try headless; it
draws no pointer). They are shot in a **windowed** session
(`tools/nested-session start --windowed --audio`), with the pointer moved
either by `tools/demo/pointer` (it moves the real pointer of the desktop: the
desktop cannot be used meanwhile) or by hand, while
`tools/nested-session run tools/demo/record --pointer --colors 256 --fps 15 --seconds N --crop … --out docs/media/NAME.gif`
takes the pictures. Before each: `tools/demo/scenes --prepare` (data, server,
player, and a fresh island with the top panel), then the settings named in the
row (`tools/nested-session set KEY VALUE`).

Crop: `560,0,800,110` for clips on the small notch; for the open island
`460,0,1000,420` (look at the first picture: the open island and its page must
fit, the panel's clock at the right must not be in it).

| Clip | Set-up | What to do while it records (about 8–12 s) |
|---|---|---|
| `notch-hover.gif` | none | rest on the notch: it opens; leave: it closes; push the pointer against the top edge above the notch: it opens; leave |
| `tabs-tour.gif` | the player playing; `weatherLocation` and `calendarSources` from `settings.tsv` | hover; Media, System, Weather, Calendar tabs, a second on each; leave |
| `activities-page.gif` | a timer running, a download running (`curl` from the local server) | hover; Activities tab; hover a card; leave |
| `media-page.gif` | the player playing | hover; Media tab; next; drag the position; the wave button (glow on) |
| `system-cards.gif` | none | hover; System tab; rest on CPU, then memory, then network |
| `weather-location.gif` | `weatherLocation` empty | hover; Weather tab; "Choose a Location"; type `Reyk`; pick it; click a day; the arrow back |
| `notifications-page.gif` | send three notifications first | hover; Notifications tab; rest on one; "Clear all"; confirm |
| `controls-tiles.gif` | none (the session has no Wi-Fi or Bluetooth: those buttons are dimmed) | hover; Controls tab; Do Not Disturb; dark mode; drag the volume; hold a button until they wiggle; "Done" |
| `apps-grid.gif` | `appShortcuts` with three apps | hover; Apps tab; "Add"; type `calc`; pick it; drag one icon over another |
| `tools-timer.gif` | none | hover; Tools tab; start a one-minute timer; leave (the notch counts down); hover again; the stopwatch, a lap; Pomodoro statistics |
| `habits-checklist.gif` | `habitsData` from `settings.tsv` | hover; Habits tab; tick two entries; the calendar; the year |
| `calendar-connect.gif` | `calendarSources` empty; the server running | hover; Calendar tab; the gear; Google; paste `http://127.0.0.1:8377/calendar/work.ics`; the month fills |
| `notes-quick.gif` | BetterNotes in the session (its own, empty data) and the notes of `notes.tsv` | hover; Notes tab; type a title, Enter; open it; type two lines; back |
| `notes-locked.gif` | a note locked in BetterNotes (its own window, a master password made up for the clip) | open the locked note on the island; type the password; the text shows |
| `ai-question.gif` | `showAi`, `aiSources`, `aiDefault` from `settings.tsv` (the demo provider) | hover; AI tab; type "How long should tea brew?"; Enter; the dots; the answer |
| `cloud-browse.gif` | `showCloud`; an rclone remote "Demo Drive" of type alias on the session's `demo/cloud` | hover; Cloud tab; open "Photos"; drag a file to the desktop; drop a file from the desktop on the tab; confirm |
| `clipboard-history.gif` | copy three made-up texts in the session first (`wl-copy` or a text editor there) | hover; Clipboard tab; click one; type in the search |
| `cat-petting.gif` | `catSleepSeconds` 600 | move the pointer over the cat from side to side five times |
| `cat-annoyed.gif` | `catSleepSeconds` 5, wait until it sleeps | click the cat twice; leave; it sulks |
| `appearance-themes.gif` | the settings window open on Appearance, beside the notch | a ready-made look; the gradient's angle; "Export Theme…"; "Add New…" → From a File |
| `layout-reorder.gif` | the settings window open on Layout, the island open beside it | drag "Weather" above "Media"; switch "Clipboard" off; Apply |

The alternative text and the caption of every clip are in the README, in the
`<!-- GIF: file | alternative text | caption -->` line where the clip goes;
`tools/demo/place-clips` turns such a line into the picture once its file
exists (in both READMEs).

## After recording: look at every clip

Pictures of each clip are taken out (`ffmpeg -i NAME.gif -vf fps=1,tile=1x16 NAME-sheet.png`)
and looked at: nothing at the edge that is not the demo (another window, a
notification of the real desktop, a path, a user name), the text readable, the
notch not cut, the moment the clip is about in it, no banding. `tesseract`
reads the pictures as well, and its text is searched for the user's name, the
host's name, an e-mail address and `/home/`. A clip should stay under about
3 MB, all of `docs/media` under about 40 MB.
