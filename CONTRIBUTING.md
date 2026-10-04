# Contributing

## Adding a theme to the store

The store of Settings → Appearance → "Add New…" shows the `catalog/` folder of
this repository: `catalog/index.json` lists the themes, `catalog/themes/` holds
them. A theme reaches every user through a pull request that adds one file.

### 1. Make the theme

In Settings → Appearance choose **Custom**, start from a ready-made look and
tune it (colours or a gradient, opacity, blur, roundness, border, shadow…).
Then press **Export Theme…**, give it a name (and, if you like, an author and
a description) and save the file. That file is the theme.

A theme is **data only**: one JSON file, at most 64 kB, with no code, no QML,
no scripts and no images.

```json
{
  "schema": 1,
  "name": "Aurora",
  "author": "Your name (optional)",
  "description": "One or two sentences (optional).",
  "style": {
    "preset": "aurora",
    "material": "flat",
    "opacity": 90,
    "blur": true,
    "blurLevel": 1,
    "radius": 100,
    "fill": "gradient",
    "gradientType": "linear",
    "gradientAngle": 120,
    "gradientStops": ["#047857", "#0e7490", "#6d28d9"],
    "control": "#5eead4",
    "text": "",
    "border": true,
    "borderWidth": 1,
    "borderColor": "",
    "shadow": 1
  }
}
```

Every field and what it may be is written down in
[`catalog/islandtheme.schema.json`](catalog/islandtheme.schema.json) (a JSON
Schema, so an editor can check the file while you write it). In short:

| Field | Value |
|---|---|
| `schema` | `1` |
| `name` | 1–60 characters; shown in the list of looks |
| `author`, `description` | optional; at most 80 and 300 characters |
| `style.preset` | the ready-made look the style starts from: `oxygen`, `breezeDark`, `breezeLight`, `glass`, `contrast`, `aurora`, `sunset`, `ocean`, `midnight` |
| `style.material` | `metal`, `flat` or `glass` |
| `style.fill` | `solid` (uses `background`) or `gradient` (uses `gradientType`, `gradientAngle`, `gradientStops`) |
| `style.background`, `style.control` | `"#rrggbb"`, or `"accent"` for the system's accent colour |
| `style.gradientStops` | two or three `"#rrggbb"` colours |
| `style.gradientType` | `linear` or `radial`; `gradientAngle` is 0–360 (as in CSS: 0 upwards, 90 to the right) |
| `style.text`, `style.borderColor` | `"#rrggbb"`, or `""` for automatic |
| `style.opacity` 0–100, `radius` 0–100, `scale` 80–120, `top` 0–40, `offsetX` −100…100, `blurLevel` 0–2, `borderWidth` 1–4, `shadow` 0–2 | whole numbers |
| `style.blur`, `style.border`, `style.strong` | `true` or `false` |

A field that is left out takes the value of the preset. A field the island
does not know is ignored; a known field with a value outside the table makes
the whole file invalid.

Please check that the text reads well on your colours. On a gradient the
settings warn when one text colour cannot be read on all of it.

### 2. Put it into the catalog

Copy the file to `catalog/themes/<id>.islandtheme.json`. The id is the file's
name: lower-case letters, digits and `-`, for example
`catalog/themes/copper-dusk.islandtheme.json`. A theme whose look depends on
where the island sits should leave out `top`, `offsetX` and `scale`.

Then let the helper write the list:

```bash
tools/catalog-update            # checks every theme, writes catalog/index.json
tools/catalog-update --check    # only checks (what the tests run)
```

It refuses a theme that does not keep the rules and says why. For every theme
`index.json` holds its id, name, author, description, the file's path, its
**SHA-256 checksum** and a small `preview` (the colours a card of the store is
drawn from):

```json
{
  "id": "copper-dusk",
  "name": "Copper Dusk",
  "author": "Your name",
  "description": "…",
  "path": "themes/copper-dusk.islandtheme.json",
  "sha256": "9f2c…",
  "preview": { "fill": "gradient", "gradientStops": ["#7c2d12", "#134e4a"], "…": "…" }
}
```

The island refuses a download whose checksum is not the one in `index.json`,
so the list has to be written again whenever a theme file changes, even by one
byte. To see a file's checksum:

```bash
tools/catalog-update --sha256 catalog/themes/copper-dusk.islandtheme.json
# or: sha256sum catalog/themes/copper-dusk.islandtheme.json
```

### 3. Open a pull request

1. Fork the repository and make a branch: `git checkout -b theme/copper-dusk`.
2. Add `catalog/themes/<id>.islandtheme.json` and the changed
   `catalog/index.json` (nothing else is needed).
3. Run `tools/run-tests`: it checks the catalog too.
4. Commit, push and open the pull request. A screenshot of the island in your
   theme helps the review.

A theme is published once the pull request is merged into the branch the
store reads (see "Themes" in the README for where that is set).

## Code

`tools/run-tests` runs every check that needs no running island: the texts
(`tools/i18n-check`), the rules written in JavaScript (node) and the QML tests
under `tests/` (qmltestrunner, off screen). Tests never read or change the
system's clock: what depends on time takes the day or the moment as an
argument. New texts go through `Lang.i18n()` and get their Turkish translation
in `contents/ui/translations/tr.js`.
