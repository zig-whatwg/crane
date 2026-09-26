# Testing: `--parallel` can manufacture ERROR results; confirm a surprising number serially

**Date**: 2026-09-22
**Lesson**: The same directory measured two ways disagreed completely, and the
sharded answer was the wrong one.

**What Happened**: `html/dom/render-blocking/` immediately after the rAF fix:

    --parallel=2   62 files   OK  2   TIMEOUT  0   CRASH 0   ERROR 60
    --parallel=1   62 files   OK 37   TIMEOUT 17   CRASH 5   ERROR  3

The 60 ERRORs carried `nav_ms 103, load_ms 728, wall_ms 833` and zero subtests -
the pages LOADED, in under a second, and reported nothing. Running one of them
on its own gave `OK in 51ms with 6 subtests`, so the file was fine and the
sharded run was inventing the result.

`html/webappapis/timers/` sharded at `--parallel=3` three times with no ERRORs
at all, so this is not every directory. Do not assume sharding is broken; do
assume a surprising result needs a serial confirmation.

**Fix**: take FINAL numbers at `--parallel=1`. Use higher parallelism for
sweeps and triage where the cost of a wrong cell is low, and re-measure anything
you are going to act on or report.

Per-file comparison against the previous state is stronger than comparing
totals, because it survives a change in parallelism or load:

    32  TIMEOUT -> OK        the actual win
    17  TIMEOUT -> TIMEOUT   still hanging, other causes
     5  CRASH   -> CRASH     untouched by this change
     5  OK      -> OK        no regressions

**Takeaway**: **An aggregate can move for reasons that have nothing to do with
the change; a per-file transition table cannot.** Three separate measurement
artefacts impersonated engine defects in one session - a 404 read as TIMEOUT,
`journal.jsonl` read as a missing `wptreport.json`, and this. A result that is
uniformly catastrophic across independent runs is the instrument, not the code.
