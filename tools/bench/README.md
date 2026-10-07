# tools/bench: what the island costs

Three scripts; none needs root, and none touches your own session.

| | |
|---|---|
| `sample` | Reads a process from `/proc` once a second and writes CSV: CPU time (user + system, all threads), CPU time of its finished children, resident and proportional memory (`smaps_rollup`), threads, open file descriptors, voluntary context switches (wakeups), child processes it started, and with `--gpu` its share of the GPU (`nvidia-smi pmon`; elsewhere the card's `gpu_busy_percent`). Works on any process: `tools/bench/sample --pid $(pgrep -x plasmashell) --children --duration 60` measures the shell you are sitting in. |
| `run` | Plays scenarios in [`tools/nested-session`](../nested-session) (an isolated, headless Plasma session with only the island): for every repetition a fresh shell and island, the scenario's settings, a warm-up, then `sample`. `tools/bench/run --list` names them. |
| `summarize` | Turns the CSV files into `docs/perf/summary.md`, `summary.csv`, `cpu.svg` and (for a long run) `soak.svg`. |

```bash
tools/bench/run --reps 3 --warmup 60 --duration 120 all    # every scenario that needs no pointer, about three hours
tools/bench/run --reps 3 idle idle-no-cat                  # or only some
tools/bench/run --resume --reps 3 all                      # go on where a run was cut off: what is measured already is kept
tools/bench/run --frames --reps 1 cat-awake                # also frames per second and frame times (costs CPU itself)
tools/bench/soak --hours 2                                 # one long run with mixed activity, sampled every 10 s
tools/bench/summarize
```

What the figures mean, on which machine they were taken and what could not be
measured is in [`docs/PERFORMANCE.md`](../../docs/PERFORMANCE.md).

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
