# tools/bench: what the island costs

None of these needs root, and none touches your own session.

| | |
|---|---|
| `sample` | Reads a process from `/proc` once a second and writes CSV: CPU time (user + system, all threads), CPU time of its finished children, resident and proportional memory (`smaps_rollup`), threads, open file descriptors, voluntary context switches (wakeups), child processes it started, and with `--gpu` its share of the GPU (`nvidia-smi pmon`; elsewhere the card's `gpu_busy_percent`). Works on any process: `tools/bench/sample --pid $(pgrep -x plasmashell) --children --duration 60` measures the shell you are sitting in. |
| `run` | Plays scenarios in [`tools/nested-session`](../nested-session) (an isolated, headless Plasma session with only the island): for every repetition a fresh shell and island, the scenario's settings, a warm-up, then `sample`. `tools/bench/run --list` names them. |
| `soak` | One long run with mixed activity, sampled every ten seconds: whether memory, threads or file descriptors grow. |
| `startup` | How long the shell takes to come up, with and without the island. |
| `chain` | All of the above in one go, in the background, made to be cut off: see below. |
| `done` | The marks that say a measurement was taken whole (`done.tsv` beside the CSV files). |
| `summarize` | Turns the CSV files into `docs/perf/summary.md`, `summary.csv`, `cpu.svg` and (for a long run) `soak.svg`; with `--readme` also into the figures of `docs/PERFORMANCE.md` and the short table of both READMEs, each with a list of what is not measured yet. Only what has its mark in `done.tsv` counts: a file that was cut off is left out and named. |

```bash
tools/bench/run --reps 3 --warmup 60 --duration 120 all    # every scenario that needs no pointer, about three hours
tools/bench/run --reps 3 idle idle-no-cat                  # or only some
tools/bench/run --resume --reps 3 all                      # go on where a run was cut off: what is marked as done is kept
tools/bench/run --resume --dry-run --reps 3 all            # only say what would be kept and what measured
tools/bench/run --frames --reps 1 cat-awake                # also frames per second and frame times (costs CPU itself)
tools/bench/soak --hours 2                                 # one long run with mixed activity, sampled every 10 s
tools/bench/summarize
```

What the figures mean, on which machine they were taken and what could not be
measured is in [`docs/PERFORMANCE.md`](../../docs/PERFORMANCE.md).

**Everything in one go, and what happens when the computer goes off.**

```bash
tools/bench/chain             # start it in the background (or go on where it was cut off); says how long it will take
tools/bench/chain --status    # what is measured, what is left
tools/bench/chain --stop      # end it, and its session
```

The chain takes hours: every scenario three times, `background` for ten
minutes, seven scenarios with their frames, the start of the shell, and last
the long run of two hours. It keeps the computer from going to sleep
(`systemd-inhibit`) and writes what it does to `docs/perf/chain.log`.

- A repetition that has ended is written to the disk for good (`fsync`) and
  gets a line in `done.tsv` beside it: the file's SHA-256, its lengths, the
  code it measured, when it ended.
- Started again, the chain measures only what has no such line. The
  repetition that was cut off is measured again from its start; a file that
  is not the one that was marked (damaged, edited) too.
- What was measured **of other code** does not count: the mark holds a
  checksum of `org.phobby.dynamicisland/` and `native/`, and after a change
  there everything with the island in it is measured again (the baseline has
  no island: it is kept). So do not change the island's code while a chain
  runs.
- The long run cannot go on in the middle (the shell it watched is gone): it
  starts anew. What the cut run had measured is on the disk up to the last
  quarter of an hour at the least, is kept as `soak.cut-DATE-TIME.csv`, and
  `summarize` draws it, with its slope, as long as there is no whole run.

**Keep the machine quiet while it runs**: a build or a video in another
window shows in the figures of the compositor, and the shell's own figures
get noisier. The session is headless: your screen may be locked or off.

**Scenarios that need a pointer** (hovering, a page held open, stroking the
cat) cannot be played headless: KWin takes input only from programs it knows.
They are played by `tools/demo/pointer` in a windowed session, on your own
screen, with your real pointer.

**Energy.** `sample` measures no watts. On most machines the counters that do
(RAPL under `/sys/class/powercap`) are readable by root only; `tools/bench/energy`
reads them when you run it with `sudo` yourself (it only reads) and writes a
CSV beside the others. Without it, CPU seconds per hour and wakeups per second
are what say how much the island keeps the machine from idling.
