# Release checklist

What was settled for 0.1.0, and what is left for the owner once it is
published. Each line names the place.

## Settled for 0.1.0

- [x] **Repository.** `https://github.com/Phobby/plasma-island`: the clone command and `tools/notify-done.sh` in `README.md` and `README.tr.md`, `Website` in `org.phobby.dynamicisland/metadata.json`.
- [x] **The store's address.** `CATALOG_URL` in `org.phobby.dynamicisland/contents/ui/ThemeFile.js` is `https://raw.githubusercontent.com/Phobby/plasma-island/main/catalog`: the `catalog/` folder of the `main` branch.
- [x] **Version and date.** 0.1.0, 2026-10-08: `Version` in `org.phobby.dynamicisland/metadata.json`, the version badge in both READMEs, the heading in `CHANGELOG.md`, the tag `v0.1.0`.
- [x] **Licence file.** `LICENSE` holds the text of the GNU General Public License, version 2; the sources say `GPL-2.0-or-later` (every file and `metadata.json`).
- [x] **Where security reports go.** `SECURITY.md` names GitHub's private vulnerability report (*Security → Report a vulnerability*).
- [x] **Author e-mail.** `metadata.json` and every commit carry GitHub's noreply address of the account, no private one.

## Left for the owner, after publishing

- [ ] **Make the repository public.** As long as it is private, `raw.githubusercontent.com` serves `catalog/` to nobody without a login: the theme store of an installed island finds nothing, and the clone command of the READMEs asks for a login. After making it public: install, then Settings → Appearance → Add New… → Browse the Store, and download one theme.
- [ ] **Switch on private vulnerability reports.** On GitHub, in the repository's settings under *Security*: *Private vulnerability reporting* (the page is called "Advanced Security", earlier "Code security"). It is off in a new repository, and GitHub offers it for public ones: until it is on, the button `SECURITY.md` points to is not there.
- [ ] **The main video.** `<!-- TODO(owner): hero video / GIF here -->` at the top of both READMEs. Nothing is shown in its place until then.
- [ ] **Clips still to record.** 23 of the `<!-- GIF: … -->` lines in the READMEs have no clip yet (`tools/demo/place-clips --check` lists them): 22 need a pointer and a windowed session, and `appearance-looks.gif` is to be recorded again (its gradients came out in bands). `docs/media/STORYBOARDS.md` says how each is shot; `tools/demo/place-clips` then puts them into both READMEs, and `tools/link-check` says whether every picture is there.
- [ ] **The measurements that are missing.** `tools/bench/chain` (hours, in the background; the island's code must not change meanwhile): the scenarios `docs/PERFORMANCE.md` lists under "Not measured yet", the frames, and the long run of two hours. It also takes the measured scenarios again, which are of the code before the last changes. Then `tools/bench/summarize --readme`, and take the section "Since the measurements" out of `docs/PERFORMANCE.md`.
- [ ] **Energy.** `sudo tools/bench/energy` beside a scenario and beside its baseline (the processor's counter is readable by root only); `docs/PERFORMANCE.md`, "Energy".
- [ ] **What needs a pointer.** The scenarios `hover`, `page` and `cat-petting`, played on the real screen with `tools/demo/pointer`.
- [ ] **Roadmap.** The TODO near the end of both READMEs (only what is decided).
- [ ] **Themes people send.** `CONTRIBUTING.md` does not say under which licence a theme added to `catalog/` is published; decide and say it there.
- [ ] **Code of conduct.** Optional; none is in the repository.
