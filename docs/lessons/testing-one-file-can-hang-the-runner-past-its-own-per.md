# Testing: One file can hang the runner past its own per-file ceiling

**Date**: 2026-09-22
**Lesson**: `html/browsers/history/the-location-interface/per-global.window.js`
ran for **78 minutes** against a 10-second ceiling, and the sweep behind it made
no progress at all.

**Why**: the per-file timeout is enforced around the page load and the harness
poll. Whatever this file reaches is not covered by either, so the ceiling never
fires and the supervisor never moves on. A `--from-file` sweep is strictly
sequential per shard, so one such file stops everything behind it.

**What Happened**: a serial sweep of the 1,181 never-run worklist files stopped
at 327 and sat there. `pgrep` showed the process alive and busy, which reads as
"still working" - the journal's mtime is what gave it away:

    journal last written  02:37:12
    now                   03:54:56
    process age           2h15m

78 minutes for 0 files. Restarting from the remainder with that one path removed
resumed normally.

**Fix**: when a long run looks slow, check the JOURNAL's mtime, not the process.
A live process proves nothing.

```bash
stat -f "%Sm" -t "%H:%M:%S" <output>/journal.jsonl; date "+now:      %H:%M:%S"
```

To resume, diff the journal's paths against the worklist and re-run the
remainder, dropping the first not-done path - that is the one it hung on.

**Takeaway**: **A sweep's progress is what it has WRITTEN, not whether it is
running.** The per-file ceiling is not a guarantee; budget for one pathological
file stalling a batch indefinitely, and check liveness by output rather than by
process.
