# What the island costs to run

Measured, not estimated. The figures below hold for **one machine**; on
another they will differ, mostly with the display's refresh rate and the
graphics driver. How to take your own is at the end.

<!-- RESULTS:BEGIN -->
*(the tables are written here by the measurements)*
<!-- RESULTS:END -->

## The machine

| | |
|---|---|
| Kind | Desktop PC (no battery) |
| Processor | AMD Ryzen 5 7500F, 6 cores / 12 threads, `amd-pstate-epp`, governor and power profile "performance" |
| Memory | 30 GiB |
| Graphics | NVIDIA GeForce RTX 4060, proprietary driver 595.91.07 |
| Display | 2560×1440 at 180 Hz, scale 1 (the measurements' own screen: 1920×1080 at 60 Hz, see below) |
| System | Ubuntu 26.04.1 (Kubuntu), Linux 7.0.0-38 |
| Desktop | Plasma 6.6.6, KWin 6.6.6 on Wayland, Qt 6.10.2 |

## How it was measured

**Where.** In `tools/nested-session`: a second KWin with its own D-Bus, home
and settings, an empty desktop of one colour, no panel, and `plasmashell` with
only this widget. It is **headless**: KWin draws with the GPU into a screen of
1920×1080 at 60 Hz that nobody sees, so the measurement does not depend on
what else is on the real screen, and the real desktop can be used or locked
meanwhile. The **baseline** is the same shell and desktop without the widget;
"over baseline" is the difference.

**What.** `tools/bench/sample` reads, once a second, from `/proc`:

- **CPU time** of the process, user + system, all threads
  (`/proc/<pid>/stat`): the time the kernel accounted, not a percentage some
  tool smoothed. It comes in steps of 10 ms, so one second reads 0, 1, 2 … per
  cent; a figure like 0.68 % is the whole time over the whole run.
- **CPU time of its children** that ended (`cutime + cstime`) and the
  **child processes it started** (seen by looking at `/proc` ten times a
  second).
- **Memory**: resident (RSS) and proportional (PSS, shared pages divided by
  their sharers) from `smaps_rollup`.
- **Threads**, **open file descriptors**.
- **Wakeups**: voluntary context switches of all its threads, per second. A
  thread that sleeps and is woken counts one; a process that lets the
  processor sleep has few.
- **GPU**: the process's share as `nvidia-smi pmon` reports it.

Besides `plasmashell` the session's **KWin** is sampled (drawing the island
costs the compositor too) and **ksystemstats**, Plasma's sensor daemon, which
the island's System page starts and keeps asking.

**How often.** Every scenario three times; each time a fresh shell and widget
with default settings plus the scenario's, 60 s left alone, then 120 s
sampled. The table has the median of the three runs with the lowest and the
highest, and the 95th percentile and the maximum of all single seconds.

**What the headless screen changes.** It refreshes 60 times a second; the
real display here 180 times. Anything that animates on every frame (the
island opening, a page sliding, the equalizer bars) draws three times as
often on the real display, and costs accordingly more there. Scenarios that
are still, or step a few times a second (the sleeping cat: 3 pictures a
second), do not depend on it. The figures taken on the real desktop are
marked as such.

## Energy

**Not measured in watts.** The processor's own energy counter (RAPL,
`/sys/class/powercap/intel-rapl:0/energy_uj`) exists on this machine but is
readable by root only; the graphics card reports no power draw
(`nvidia-smi`: N/A); a desktop PC has no battery to read a discharge from. No
figure in watts is given here, and none was derived from a model.
`tools/bench/energy` reads the processor's counter when run with `sudo`; the
difference between a scenario and the baseline, on a quiet machine, would be
the island's share.

What stands in for it:

- **CPU seconds per hour**: 1 % of one core is 36 CPU seconds an hour.
- **Wakeups per second**: how often the island keeps the processor from
  sleeping.
- **Child processes** started, and **network requests** made (none at idle:
  see the README's privacy table).

## What could not be measured

- **Anything that needs a pointer**, headless: hovering, an open page,
  scrolling a list, stroking the cat. KWin takes input only from programs it
  knows. Those scenarios are played on the real screen with a scripted pointer
  (`tools/demo/pointer`) and are listed separately when they were.
- **Frame times while scrolling**, for the same reason.
- **Watts** (see above).
- **Other hardware**: an integrated GPU, a laptop on battery, a 60 Hz or a
  4K display, X11.

## Taking your own

```bash
tools/bench/chain                                           # everything below, in the background; goes on where it was cut off
tools/bench/chain --status                                  # what is measured, what is left, how long that takes
# or piece by piece:
tools/bench/run --list
tools/bench/run --reps 3 --warmup 60 --duration 120 all     # about three hours; your desktop stays usable
tools/bench/soak --hours 2
tools/bench/summarize                                       # docs/perf/summary.md, cpu.svg, soak.svg
# the shell you are sitting in, as it is:
tools/bench/sample --pid "$(pgrep -x plasmashell)" --children --gpu --duration 120 --out /tmp/my-shell.csv
```

The raw CSV files of the figures here are in [`perf/raw/`](perf/raw/);
`done.tsv` beside them says which code each measured and when
([`tools/bench`](../tools/bench/README.md)).
