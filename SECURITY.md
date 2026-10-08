# Security

## Reporting a problem

Please report a security problem **privately**, not in a public issue:
through GitHub's private vulnerability report. On the repository's page,
*Security* → *Report a vulnerability*
(<https://github.com/Phobby/plasma-island/security/advisories/new>). Only the
maintainer sees such a report until an advisory is published.

Say what you did, what happened and what you expected; a way to see it again
helps most. Please leave out anything secret of your own (keys, tokens, the
private link of a calendar, the contents of notes).

## What the island is careful about

- **Programs are started without a shell**, each argument on its own. A
  password (a locked note's) goes to the program's standard input, never onto
  its command line.
- **What others write is shown as plain text**: a notification's title, a
  track's, a file's, a network's or a device's name, a calendar's events. Every
  text item names its format (`tools/text-check`, part of the tests).
- **Passwords, tokens and API keys live in KDE Wallet**, never in the settings.
  (Two things that are in the settings as plain text: the private `.ics` links
  of calendars you connected, and the OAuth client ID and secret of your own
  Google client.)
- **A theme is data**: at most 64 kB of JSON with known fields, checked before
  use; a theme from the store must match the checksum the catalog lists.
- **Nothing is asked of the network** until you choose a place for the weather,
  connect a calendar or a notes app, or switch on AI or Cloud. The table is in
  the README ("Privacy and the network").
- **The AI page gives no tool, file or anything you did not type** to what
  answers.

## What it trusts

The island runs inside plasmashell with your user's rights. It trusts your own
settings, the programs on your `PATH` that it starts by name (`rclone`,
`betternotes`, `claude`, `pw-dump`…) and whatever can already talk on your
session's D-Bus (the D-Bus API takes activities from any program of your
session; it can be switched off in Settings → Activities).
