---
name: Something does not work
about: The island does something wrong, or not at all
labels: bug
---

<!-- Please leave out anything secret: API keys, tokens, the private link of a
     calendar, the contents of notes, names you would not post in public. -->

**What happened, and what did you expect?**

**How can it be seen again?** (step by step, as short as it gets)

**Your system**

- Distribution and version:
- Plasma (`plasmashell --version`), Qt, Wayland or X11:
- Graphics card and driver:
- How the island was installed (`./install.sh`, `--no-native`, by hand):

**The log**

What plasmashell says about the island while it happens:

```
journalctl --user -b --no-pager | grep -i -E "dynamicisland|org.phobby" | tail -50
```

Read it before pasting: a log can hold file names, titles and addresses.

**For a problem with BetterNotes**, also the output of `betternotes --diagnostics`.
