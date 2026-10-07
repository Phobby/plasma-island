# Before publishing

What only the owner can decide or fill in. Each line names the place.

- [ ] **Repository name.** `OWNER/REPOSITORY` in `README.md` and `README.tr.md` (the clone command, twice each with `tools/notify-done.sh`).
- [ ] **The store's address.** `CATALOG_URL` in `org.phobby.dynamicisland/contents/ui/ThemeFile.js` is `https://raw.githubusercontent.com/OWNER/REPOSITORY/BRANCH/catalog`: until it is set the store asks nothing and says it has no address. After setting it, install again and open Settings → Appearance → Add New… → Browse the Store.
- [ ] **The main video.** `<!-- TODO(owner): hero video / GIF here -->` at the top of both READMEs.
- [x] **Version and date.** 0.1.0, 2026-10-07: `Version` in `org.phobby.dynamicisland/metadata.json`, the version badge in both READMEs, the heading in `CHANGELOG.md`.
- [x] **Licence file.** `LICENSE` holds the text of the GNU General Public License, version 2; the sources say `GPL-2.0-or-later` (every file and `metadata.json`).
- [ ] **Where security reports go.** The TODO in `SECURITY.md`.
- [ ] **Website.** `metadata.json` has no `Website`; add the repository's address.
- [ ] **Author e-mail.** `metadata.json` and every commit carry the author's e-mail address; it becomes public with the repository.
- [ ] **Roadmap.** The TODO near the end of both READMEs (only what is decided).
- [ ] **Themes people send.** `CONTRIBUTING.md` does not say under which licence a theme added to `catalog/` is published; decide and say it there.
- [ ] **Code of conduct.** Optional; none is in the repository.
- [ ] **Clips still to record.** The `<!-- GIF: … -->` lines left in the READMEs are clips that are not recorded yet; `docs/media/STORYBOARDS.md` says how each is shot.
