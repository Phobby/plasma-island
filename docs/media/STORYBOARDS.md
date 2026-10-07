# The clips: how each one is shot

Every clip in the README is recorded in `tools/nested-session`: an isolated
Plasma session with an empty desktop of one colour, 1920x1080 at scale 1, the
island with made-up data (`tools/demo/make-data`), the demo player
(`tools/demo/player`) and a local server (`tools/demo/serve`). Nothing of the
author's desktop, files, accounts or place can be in a clip: the session has
another home and no way to the real ones.

Clips are 800 px wide, about 12 pictures a second, cut to the top middle of
the screen (`560,0,800,150` for the pill, `460,0,1000,330` for the open
island), 128 colours.

## Recorded by script, headless

`tools/demo/scenes --headless` records these without anybody at the screen:

| Clip | What it shows |
|---|---|
| `island-states.gif` | the clock, a notification, an activity with its progress |
| `media-controls.gif` | a track on the pill, the next one, paused and playing again |
| `media-glow.gif` | the glow switched on and off while music plays |
| `media-cat.gif` | the cat puts on headphones when music starts |
| `cat-sleep.gif` | the cat falls asleep, a notification wakes it |
| `island-push.gif` | an activity pushed with `island-push` |
| `downloads-tracking.gif` | a download from the local test server |
| `appearance-looks.gif` | the same island in several looks |
| `calendar-pinned.gif` | an event pinned before it starts, then started |

## Need a pointer: to be recorded in a windowed session

A headless session has no pointer, and KWin takes input only from programs it
knows. These clips are shot in a **windowed** session
(`tools/nested-session start --windowed --audio`), with the pointer moved
either by `tools/demo/pointer` (it moves the real pointer of the desktop: the
desktop cannot be used meanwhile) or by hand, while
`tools/nested-session run tools/demo/record --pointer --seconds N --crop … --out docs/media/NAME.gif`
takes the pictures. Before each: `tools/demo/scenes --prepare`, then the
settings named in the row (`tools/nested-session set KEY VALUE`).

| Clip | Set-up | What to do while it records (about 8–12 s) |
|---|---|---|
| `dot-mode.gif` | a window (any, e.g. `kcalc`) beside the island | click the pill → dot; click a button of the window right beside the dot; click the dot → pill |
| `activities-page.gif` | a timer running, a download running (`curl` from the local server) | hover the pill; the Activities tab; hover a card; leave |
| `media-page.gif` | the player playing | hover; Media tab; next; drag the position; the wave button (glow on) |
| `system-cards.gif` | none | hover; System tab; rest on CPU, then memory, then network |
| `weather-location.gif` | `weatherLocation` empty | hover; Weather tab; "Choose a Location"; type `Reyk`; pick it; click a day; the arrow back |
| `notifications-page.gif` | send five notifications first | hover; Notifications tab; rest on one; "Clear all"; confirm |
| `controls-tiles.gif` | none (the session has no Wi-Fi or Bluetooth: those buttons are dimmed) | hover; Controls tab; Do Not Disturb; dark mode; drag the volume; hold a button until they wiggle; "Done" |
| `apps-grid.gif` | `appShortcuts` with three apps | hover; Apps tab; "Add"; type `calc`; pick it; drag one icon over another |
| `tools-timer.gif` | none | hover; Tools tab; start a one-minute timer; leave (the pill counts down); hover again; the stopwatch, a lap; Pomodoro statistics |
| `habits-checklist.gif` | `habitsData` from `settings.tsv` | hover; Habits tab; tick two entries; the calendar; the year |
| `calendar-connect.gif` | `calendarSources` empty; the server running | hover; Calendar tab; the gear; Google; paste `http://127.0.0.1:8377/calendar/work.ics`; the month fills |
| `notes-quick.gif` | BetterNotes in the session (its own, empty data) and the notes of `notes.tsv` | hover; Notes tab; type a title, Enter; open it; type two lines; back |
| `notes-locked.gif` | a note locked in BetterNotes (its own window, a master password made up for the clip) | open the locked note on the island; type the password; the text shows |
| `ai-question.gif` | `showAi`, `aiSources`, `aiDefault` from `settings.tsv` (the demo provider) | hover; AI tab; type "How long should tea brew?"; Enter; the dots; the answer |
| `cloud-browse.gif` | `showCloud`; an rclone remote "Demo Drive" of type alias on the session's `demo/cloud` | hover; Cloud tab; open "Photos"; drag a file to the desktop; drop a file from the desktop on the page; confirm |
| `clipboard-history.gif` | copy three made-up texts in the session first (`wl-copy` or a text editor there) | hover; Clipboard tab; click one; type in the search |
| `suggestions-card.gif` | `suggestionsEnabled` and `showRecording` on; start a screen recording in the session (Spectacle there) | the island asks; "Yes"; then Settings → Suggestions |
| `cat-petting.gif` | `catSleepSeconds` 600 | move the pointer over the cat from side to side five times |
| `cat-annoyed.gif` | `catSleepSeconds` 5, wait until it sleeps | click the cat twice; leave; it sulks |
| `appearance-themes.gif` | the settings window open on Appearance | Custom; a ready-made look; the gradient's angle; "Export Theme…"; "Add New…" → From a File |
| `layout-reorder.gif` | the settings window open on Layout | drag "Weather" above "Media"; switch "Clipboard" off; Apply |
| `language-switch.gif` | the settings window open on Language, the island open beside it | Türkçe; Apply; the tabs' names change |

The alternative text and the caption of every clip are in the README, in the
`<!-- GIF: file | alternative text | caption -->` line where the clip goes;
`tools/demo/place-clips` turns such a line into the picture once its file
exists.

## After recording: look at every clip

Pictures of each clip are taken out (`ffmpeg -i NAME.gif -vf fps=1 /tmp/NAME-%02d.png`)
and looked at: nothing at the edge that is not the demo (another window, a
notification of the real desktop, a path, a user name), the text readable, the
island not cut, the moment the clip is about in it, no banding. `tesseract`
reads the pictures as well, and its text is searched for the user's name, the
host's name and `/home/`.
