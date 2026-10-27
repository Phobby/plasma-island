# UI audit (before the simplification)

What the island and its settings looked like on branch `feature/ui-simplify`
after the full-screen and requirement fixes (commits `4ae49fb` to `8938aec`)
and before the settings were simplified: every screen, what is crowded or
unclear, and what to do about it. Pictures: `docs/ui-audit/` (the settings
pages with a new island's defaults, made with `tools/settings-shots`, light
Breeze, 820 px wide; the island in `tools/nested-session`, 1920×1080).

## 1. Inventory

### The island

| Screen | Picture | Note |
|---|---|---|
| Idle (notch, oval) | [states](ui-audit/island/states.png) row 1 left, row 4 right | The clock and nothing else; the cat beside it. Clear. |
| Live activity, split | [states](ui-audit/island/states.png) row 1 right, row 2 left | Icon, title, ring; the second activity in a bubble. Clear. |
| Event banner, notification | [states](ui-audit/island/states.png) row 2 right, row 3 left | One line, dismiss ×. The × is 10 px. |
| Dot, its menu | [states](ui-audit/island/states.png) row 3 right, row 4 left | A 15 px dot (24 px target); the right-click menu has two entries. |
| Retracted over full screen (peek) | [retracted](ui-audit/island/retracted.png), [at 240 %](ui-audit/island/retract-notch-240.png) | A 4 px strip, as wide as the island (after A2). |
| Expanded: 11–13 tabs | [tabs 1](ui-audit/island/tabs-1.png), [2](ui-audit/island/tabs-2.png), [3](ui-audit/island/tabs-3.png), [tab bar with AI and Cloud](ui-audit/island/tabbar-13.png) | Media, System, Weather, Notifications, Controls, Apps, Tools, Habits, Calendar, Notes, (AI, Cloud), Clipboard, then the time, a collapse chevron and the settings button. Icons only, ~14 px glyphs on ~22 px targets; under the page a row of 11–13 page dots repeats the tab bar. |
| Empty states | tabs 1–3 | Short and helpful (weather, apps, calendar, clipboard, habits); notes lists four apps to connect. |
| A requirement missing | [card](ui-audit/island/requirement-card.png), [without the native module](ui-audit/island/without-native.png) | One card since B (what, why, how, path, check again). |

### The settings window

| Page | Keys it edits | Controls shown by default | Height at 820 px | Texts | Long texts (>150 chars) | Picture |
|---|---|---|---|---|---|---|
| General | 17 | 27 | 1112 | 55 | 2 | [en](ui-audit/before/en/general.png) · [tr](ui-audit/before/tr/general.png) |
| Appearance (layout, notch, full screen, look, themes) | 31 (+ the notch's and full screen's own) | 28 | **3152** | **219** | **14** | [en](ui-audit/before/en/appearance.png) · [tr](ui-audit/before/tr/appearance.png) |
| Layout (tabs and modules) | 15 | 14 | 986 | 13 | 1 | [en](ui-audit/before/en/layout.png) |
| Controls | 4 | 2 | 1439 | 16 | 1 | [en](ui-audit/before/en/controls.png) |
| Activities | 18 | 18 | 1045 | 37 | 1 | [en](ui-audit/before/en/activities.png) |
| Download tracking | 13 | 29 | 1180 | 30 | 3 | [en](ui-audit/before/en/downloads.png) |
| Alerts | 5 | 10 | 400 | 7 | 0 | [en](ui-audit/before/en/alerts.png) |
| Calendar | 7 | 9 | 400 | 104 | 4 | [en](ui-audit/before/en/calendar.png) |
| Weather | 3 | 4 | 449 | 19 | 1 | [en](ui-audit/before/en/weather.png) |
| Notes | 5 | 6 | 400 | 13 | 1 | [en](ui-audit/before/en/notes.png) |
| AI | 7 | 9 | 559 | 25 | **7** | [en](ui-audit/before/en/ai.png) |
| Cloud | 11 | 14 | 617 | 30 | 3 (one of 684 chars) | [en](ui-audit/before/en/cloud.png) |
| Tools | 6 | 10 | 513 | 26 | 0 | [en](ui-audit/before/en/tools.png) |
| Habits | 3 | 8 | 644 | 27 | 2 | [en](ui-audit/before/en/habits.png) |
| Cat | 15 | 17 | 985 | 49 | 2 | [en](ui-audit/before/en/cat.png) |
| Suggestions | 6 (+ each rule) | 27 | 1277 | 42 | 1 | [en](ui-audit/before/en/suggestions.png) |
| Language | 1 | 0 (a list) | 400 | 4 | 0 | [en](ui-audit/before/en/language.png) |
| Diagnostics (new in B) | 1 | — | 1906 | 46 | 1 | [en](ui-audit/before/en/diagnostics.png) |

- **217 settings keys** (`main.xml`); about **165 can be changed in the
  window**, the rest is the island's own state (timers, what was learned,
  accounts, notices, a preview's working copy).
- **18 pages** in the sidebar, plus Plasma's own entries (*About*): the
  sidebar needs scrolling at the window's usual height.
- Every page shows everything at once: nothing is folded away.

## 2. What is wrong, most important first

1. **Too many pages, the wrong way round.** 18 entries, and four of them are
   one feature split up (Activities, Download tracking, Alerts; Layout,
   Controls), one is a single list (Language), and seven are tabs that may be
   switched off (AI and Cloud are off by default, yet their pages are there).
   A first-time user looks for "the clock" or "the notch" and has to guess the
   page.
2. **Appearance is a wall.** 3152 px, 219 texts, 14 of them over 150 chars:
   the layout picker, ~20 notch settings, the full-screen mode with five of
   its own, the look with its fine tuning, the themes. Settings that only
   apply in one layout are greyed out instead of hidden (*Distance from top*
   on General in the notch layout; the notch's settings in the oval one).
3. **Everything at once.** Delays in milliseconds, a cache's size, half-lives
   of what suggestions learned, alert pause hours, border opacity, the
   notch's height in pixels: next to the two or three settings a page is
   opened for. No page has a "details" part.
4. **No search.** A setting is found by opening pages one by one.
5. **Long explanations.** 46 texts over 150 chars; a few are paragraphs
   (Cloud 684, Calendar 386, Weather 345, AI 330). They push the controls
   apart and are read by nobody twice.
6. **One setting, two places.** *Distance from top* (General and the look's
   fine tuning); the habits' colour source (Appearance and Habits); the tab
   switches (Layout) and the tabs' own pages (which stay in the sidebar while
   their tab is off).
7. **No first run.** A new island starts with 11 tabs and the notch; nothing
   says what can be switched off or what is missing.
8. **The island's tab bar** (13 icons with AI and Cloud) has no names, small
   targets (~22 px) and a page-dot row that repeats it.
9. **Accessibility.** The island's own buttons (`PillButton`, `IconButton`,
   tab icons) have no accessible name or role and cannot be reached with
   the keyboard (the island never takes the keyboard by itself; by design).
   In the settings, KDE's own controls are fine; the page's own pieces (the
   preview boxes, the drag lists) are mouse-only.
10. **Narrow windows and translations.** At 520 px the form switches to
    labels above their controls, which works; but the Cat page's opening text
    and its row of *Try* buttons run past the right edge and are cut off
    (Turkish and English; [Turkish, 520 px](ui-audit/before/tr-narrow-cat.png)).
    Turkish is as long as English on the whole (1 % longer), but 245 of the
    1454 texts are over 30 % longer (mostly short labels: *Kenarda belir*,
    *Gösterme süresi*); elsewhere nothing is cut.

## 3. What to do, and in which order

| # | Problem | Solution | Priority |
|---|---|---|---|
| 1 | 18 pages | **Group into fewer pages:** *General* (with Language), *Appearance* (with the oval layout's place from General), *Tabs* (Layout with Controls and the System view), *Activities* (with Alerts and Download tracking), *Suggestions*, *Cat*, *Diagnostics*; the tabs' own pages (Weather, Calendar, Notes, Tools, Habits, AI, Cloud) **only while their tab is on**. A *Privacy and data* page and an *Advanced* page were considered and not made: each setting stays beside the feature it belongs to, behind that page's *Details*, where the search finds it; what goes over the network is in the README's privacy table and Diagnostics. Plasma's own *About* cannot be changed, so the island's about (version, GitHub, the tour) is on *Diagnostics*. | high |
| 2 | Everything at once | **Folding *Details* parts** (one component, arrow, keyboard, remembered open or closed, loaded only when opened): each page shows the 3–6 settings it is opened for. | high |
| 3 | Appearance | Hidden instead of greyed: notch settings in the oval layout and the oval's in the notch, peeking's in other full-screen modes, dot mode's while it is off; the notch's border, height, width and ears, the look's fine tuning in *Details*. | high |
| 4 | No search | **A search field at the top of every page**: every setting, also those inside *Details* and on hidden tab pages, by its name and a few words; a result opens its page and its *Details*, and shows it. | high |
| 5 | Delays and durations | **One choice, *Response: Calm / Balanced / Lively*,** for the hover and collapse delays and how long events and notifications stay; *Customize* opens the four values. No new setting: it is read from the values (an island whose values match no preset shows *Custom*). | medium |
| 6 | Long texts | One sentence under a control; the rest in a `?` tooltip. Texts over 150 chars only where they explain something new (Diagnostics, the native module). | medium |
| 7 | Duplicates | One place each: *Distance from top* on Appearance (oval only), the tabs' switches on *Tabs* only (their pages are hidden when the tab is off). | medium |
| 8 | No first run | **A short tour** on the island's first opening (layout, which tabs, what is missing; three steps, can be skipped, shown once; again from Diagnostics). An island that ran before does not see it. | medium |
| 9 | Island tab bar | Proposal only (the island's look and behaviour stay as they are in this round): names in a tooltip, the page-dot row only for a swipe, a *More* menu past nine tabs. | low |
| 10 | Accessibility | Accessible names and roles for the island's buttons and the new settings pieces; keyboard for the folding parts and the search; 24 px targets in the settings pieces. | medium |
| 11 | Consistency | The settings pieces from one place (`SettingsFold`, `SettingsSearch`, `RequirementNotice`), spacing from Kirigami's units; the island's from `Theme`. | medium |
| 12 | Performance | Folded parts are not loaded until opened; the page-opening time is measured before and after (`tools/settings-shots`). | medium |

What does **not** change: no setting is removed or renamed, every key keeps
its value and meaning, the island's look and behaviour stay as they were
(apart from the full-screen and requirement fixes before this). The settings
are only arranged anew.

## 4. After the simplification

Commits `5e5dd58` (the settings) and `1094082` (the tour, schema 3). Pictures:
`docs/ui-audit/after/` (the same tool and defaults as before, English and
Turkish, 820 px; the tour's three steps in
[island-tour.png](ui-audit/after/island-tour.png)).

After, page by page: General [en](ui-audit/after/en/general.png) [tr](ui-audit/after/tr/general.png) · Appearance [en](ui-audit/after/en/appearance.png) [tr](ui-audit/after/tr/appearance.png) · Tabs [en](ui-audit/after/en/layout.png) [tr](ui-audit/after/tr/layout.png) · Activities [en](ui-audit/after/en/activities.png) [tr](ui-audit/after/tr/activities.png) · Weather [en](ui-audit/after/en/weather.png) [tr](ui-audit/after/tr/weather.png) · Controls [en](ui-audit/after/en/controls.png) [tr](ui-audit/after/tr/controls.png) · Tools [en](ui-audit/after/en/tools.png) [tr](ui-audit/after/tr/tools.png) · Habits [en](ui-audit/after/en/habits.png) [tr](ui-audit/after/tr/habits.png) · Calendar [en](ui-audit/after/en/calendar.png) [tr](ui-audit/after/tr/calendar.png) · Notes [en](ui-audit/after/en/notes.png) [tr](ui-audit/after/tr/notes.png) · AI [en](ui-audit/after/en/ai.png) [tr](ui-audit/after/tr/ai.png) · Cloud [en](ui-audit/after/en/cloud.png) [tr](ui-audit/after/tr/cloud.png) · Cat [en](ui-audit/after/en/cat.png) [tr](ui-audit/after/tr/cat.png) · Suggestions [en](ui-audit/after/en/suggestions.png) [tr](ui-audit/after/tr/suggestions.png) · Diagnostics [en](ui-audit/after/en/diagnostics.png) [tr](ui-audit/after/tr/diagnostics.png).

### Pages

| Before (18) | After (15; 13 with a new island's tabs) | Why |
|---|---|---|
| General, Language | **General** (language at the top) | the language is one choice; General is where it is looked for |
| Appearance | **Appearance** | the layout, its own settings (notch or oval, whichever is chosen), full screen, the look |
| Layout, (General's System view) | **Tabs** | the page that decides which tabs there are; the System view is how one of them looks |
| Activities, Alerts, Download tracking | **Activities** (Alerts and Download tracking folded in it) | three pages of one feature: what the small island shows |
| Weather, Controls, Tools, Habits, Calendar, Notes, AI, Cloud | the same, **only while their tab is on** | a page for a tab that is off had nothing to do; the search still finds them |
| Cat, Suggestions, Diagnostics | the same (Diagnostics also has the island's about and the tour) | |

A *Privacy and data* and an *Advanced* page were not made (section 3, #1):
each setting stays beside the feature it belongs to, folded where it is
rarely changed, and the search finds it.

### Settings, before and after

| | Before | After |
|---|---|---|
| Keys in `main.xml` | 217 | 218 (+ `tourShown`, the island's own) |
| Set in the window | about 165 | 166 (`tools/settings-index`: each on a page and in the search; 50 are the island's own state, 2 are set on its pages: the apps, the glow) |
| Controls shown when a page opens (all pages, a new island's settings) | 232 | 101 |
| Height of all pages at 820 px | 17 254 px | 11 590 px |
| Appearance | 3152 px, 28 controls | 1336 px, 10 controls |
| General | 1112 px, 27 controls | 596 px, 11 controls |
| Cat | 985 px, 17 controls | 502 px, 4 controls |
| Activities (+ Alerts, Download tracking) | 2625 px over three pages, 57 controls | 400 px, 3 controls (2384 px with every part open) |

### What was folded (91 of the 153 entries of the search)

| Page | Part | Settings |
|---|---|---|
| General | Customize (Response) | hover delay, collapse delay, how long events and notifications stay |
| General | Dot mode details (while dot mode is on) | start as, dot size, hovering the dot, events in dot mode, critical events |
| General | Details | preferred player |
| Appearance | Notch details | the preview, border (on, width, colour, opacity), upper corners, height, opening as wide, over full screen (also for a window under it, size and width there), hiding the cat |
| Appearance | Full-screen details (not in Normal) | the preview, the part that shows, opens after, trigger width, important events |
| Appearance | Saved looks (custom look only) | profiles |
| Appearance | Fine tuning | blur, horizontal position, corner roundness, background and gradient, controls, buttons and text colours, border, shadow |
| Activities | Events shown | the 9 system events and 5 live activities |
| Activities | Priority | the priority list |
| Activities | Warning thresholds | battery, critical, device battery, CPU and GPU temperature |
| Activities | Download tracking details (while it is on) | sources, background, how long and how large, the end, folders, waiting, commands |
| Calendar | Details | keep after it ends, update interval |
| AI | Limits | longest answer, longest question |
| Cloud | Details | storage thresholds, the same alert again, fetching for dragging, cache |
| Cat | Behaviour (while the cat is on) | reactions, pointer, sulking, sleep, dot, motion |
| Suggestions | Customize (while they are on) | cards a day, a rule's wait, between two cards, half-life |

Hidden instead of greyed: the notch's settings in the oval layout and the
oval island's place (distance from the top, below top panels) in the notch
layout; the colours, ready-made looks and saved looks while following the
system, *Colours from* in a custom look; the look's border and shadow in the
notch layout (it has its own); the time format without the clock; keeping
media visible without the split island; the cat's settings while it is off.

### Migration (settings schema 3)

No key was removed, renamed or given another meaning: a page that moved
reads and writes the same keys (`tools/settings-index` checks that every key
is on a page). Step 3 of `SettingsMigration.js` only decides the tour: a new
island shows it at its first opening; one that ran before (schema 1 or 2, a
version it noted, settings it kept or that were brought back) gets
`tourShown` and never sees it. Its look and behaviour do not change.
`tests/settingsmigration.test.js` checks both, also undone and taken again.

### Island (proposal #9)

Not changed in this round, as planned: names for the tab icons in a
tooltip, the page-dot row only for a swipe, a *More* menu past nine tabs.
The island's own buttons (`PillButton`, `IconButton`) now have an accessible
name and role; the island still takes no keyboard focus by itself (by
design: it would take it from the window in front).

### Checked, and how

- `tools/run-tests`: every test, `text-check`, `i18n-check` (1455 texts, 0
  missing), `scroll-check`, `settings-index --check` (166 of 166 reachable).
- `tests/tst_settings_ui.qml`: a part is made only when opened, opens and
  closes with Space on its focused header, is remembered across a new page;
  the search in English and Turkish, a result opens its part, a setting
  shown only while a switch is on is shown by that switch; Response;
  **every entry of the search found on its page** (with the switches that
  show it on, every part opened, in the notch and oval layouts, a custom,
  a gradient and the system's look); the tour.
- Narrow window (520 px, Turkish): nothing runs past the edge any more
  ([Cat](ui-audit/after/tr-narrow-cat.png)).
- Opening a page, off screen, made and drawn once in an engine of its own
  (`tools/settings-shots`, one run each, so a few ms of noise): General
  84 → 71 ms, Appearance 270 → 187 ms, Activities with Alerts and Download
  tracking 208 ms over three pages → 82 ms, Cat 91 → 86 ms; with every part
  opened Appearance is 188 ms, Activities 80 ms. Closed parts cost nothing.
- Retracted over full screen (A2's peeking), measured in
  `tools/nested-session` (Wayland, headless, 1920×1080) with
  `tools/bench/run --reps 2 --warmup 45 --duration 90`: music playing, the
  notch with its cat (`media-cat-notch`), then the same with Konsole in
  full screen in front and the full-screen mode *Peek at the edge*
  (`media-cat-peek`, new scenarios of `tools/bench/run`):

  | | plasmashell CPU | wakeups/s | RSS / PSS | KWin CPU |
  |---|---|---|---|---|
  | notch, nothing in full screen | 2.69 % / 2.74 % | 895 / 968 | 303–360 / 141–198 MB | 1.17 % / 1.13 % |
  | peeking over full screen | 0.16 % / 0.17 % | 7 / 7 | 304 / 141 MB | 0.00 % / 0.01 % |

  Drawn up, the island's content is a still picture and the album light,
  equaliser and cat stop: the shell is as quiet as with the island idle and
  its cat hidden; memory does not change.
- In `tools/nested-session` the island loads with these settings and its
  log has no QML error (the first try found one: the tour's wiring,
  fixed in `0e7422e`).

### Not verified on a real screen

- Nothing was tried on the live desktop; everything in the isolated Wayland
  session or off screen. No X11 session.
- The tour on a real island (headless, nothing can hover the island to open
  it): checked as a component off screen and by its tests, and that the
  island loads with it.
- The settings window in Plasma itself: the pages, the search and the
  folding parts were checked off screen; the sidebar hiding a tab's page
  (`ConfigCategory.visible`, as Plasma's own Folder View does) and a search
  result opening a page that is not in the sidebar were not tried in the
  real window.
- Keyboard: the folding parts (Tab, Space) and the search (Down, Enter,
  Escape) are tested; a whole pass with Tab through every page was not made.
- Screen readers: names and roles were set, not heard with Orca.
