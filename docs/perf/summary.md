| Scenario | runs | plasmashell CPU % (lowest–highest run) | over baseline | 1 s p95 / max | KWin % | sensors % | wakeups/s | child processes/h | RSS MB | PSS MB |
|---|---|---|---|---|---|---|---|---|---|---|
| `baseline`: the same shell and desktop without the island | 2 | **0.00** (0.00–0.00) | – | 0 / 0 | 0.00 | – | 0 | 0 | 212 | 68 |
| `idle`: the pill with the clock, default settings; the cat has fallen asleep | 3 | **0.40** (0.38–0.40) | +0.40 | 1 / 2 | 0.11 | 0.19 | 66 | 0 | 284 | 123 |
| `idle-dot`: shrunk to a dot (the cat hidden) | 3 | **0.12** (0.12–0.12) | +0.12 | 1 / 2 | 0.00 | 0.19 | 4 | 0 | 283 | 122 |
| `idle-no-cat`: the pill, default settings, without the cat | 3 | **0.12** (0.11–0.12) | +0.12 | 1 / 2 | 0.00 | 0.20 | 4 | 0 | 282 | 120 |
| `everything-off`: every page, module, alert and watcher switched off | 3 | **0.01** (0.00–0.02) | +0.01 | 0 / 2 | 0.00 | 0.07 | 0 | 0 | 263 | 110 |
| `cat-awake`: the cat kept awake (sitting, its fidgets) | 3 | **0.52** (0.52–0.69) | +0.52 | 3 / 6 | 0.17 | 0.18 | 107 | 0 | 283 | 123 |
| `cat-still`: the cat with "Reduce motion" | 1 | **0.12** (0.12–0.12) | +0.12 | 1 / 1 | 0.00 | 0.19 | 4 | 0 | 339 | 175 |
