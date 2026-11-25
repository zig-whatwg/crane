# Workflow: A timed window proves its subject runs before it measures, and bounds itself

**Date**: 2026-11-24
**Status** (2026-11-24, lane tool1): the smoke and the watchdog are in the tools now - `perf_bench check` launches `workloads/overhead.html` in every pinned engine and fails on no result, `perf_bench run --max-timeouts=3` stops after three launches of one engine in a row time out or crash (exit 4), and `perf_bench window` runs both (docs/performance.md, "A lane's cost pair"). The list and estimate advice stands.
**Lesson**: A queued window must check that the thing it measures works at all, stop itself when nothing comes back, and carry an estimate that covers every step it runs - or it holds a pool host for hours and measures nothing.

**Why**: A window's input checks (checksums, pins, list sizes) say the files are the right files, not that the binary runs. A window that fails slowly looks, from outside, like a window that is working: the keeper sees CPU and changing files. And a window's script is shared state - a list one step writes is read by others.

**What Happened**: Two of lane rc8's windows ran away in one night.
1. The cost pair on chat.local ran 7 hours: all 170 records were "no result in 600 s", on both consoles. Main's release console had been broken by a merge (a 1 MiB stack buffer in the console's main frame put it past V8's stack limit, so every script threw). `perf_bench check` had validated the pins without launching a page. The same night another lane's window on chat2 did the same.
2. The A/B window on server1 ran 7.5 hours against an estimate of 110 minutes, with two lanes queued behind it. The lane had added 408 files (those with no generation record) to the window's changed-file list so the pair step would compare them with main. The verify step reads the same list and runs each file ten times; many of the 408 time out. And the estimate had been taken from an earlier window's first script only - the second script the window chains (two hours a side) was never in it.

**Fix**: In the window's own command, before the measurement:
- **Run the subject once.** For a console pair, the one-line page on BOTH consoles, and do not start if either fails: `repl 'data:text/html,<script>console.log("ran", 6*7)</script>' --proxy=direct --timeout=3000` must print `ran 42`.
- **A watchdog.** A background check that, once enough time has passed for the first records, sets the window's stop file if the journal has records and none is ok (lane rc8 used 1,300 seconds for a pass whose launches time out at 600).
- **A cap on what a derived list may add.** A step whose input is computed inside the window (changed files) refuses, with a loud line, beyond a bound the estimate covers.
And before queueing:
- **Find every reader of a list before changing what goes into it** (`grep` the list's name through the window's scripts).
- **Estimate every step the window runs**, from the last measured run of each, and say them in the note.

**Takeaway**: **A window earns its host only if it can fail fast: smoke the subject first, stop on an all-failed journal, bound every derived list, and estimate every step - a window that cannot tell "working" from "timing out" will hold the pool all night.**
