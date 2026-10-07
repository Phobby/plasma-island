<!-- Please leave out anything secret (keys, tokens, private links, personal data), in the text and in the files. -->

**What this changes**

**How it was tried** (what you did, on which Plasma version; Wayland or X11)

- [ ] `tools/run-tests` passes
- [ ] New texts go through `Lang.i18n()` and have their Turkish entry in `contents/ui/translations/tr.js`
- [ ] Every new `Text`/`Label` names its `textFormat` (plain, unless the island writes the markup itself)
- [ ] Programs are started with an argument list, never a shell line
- [ ] For a theme: one file in `catalog/themes/`, and `tools/catalog-update` was run
