# Testing: A crash that only appears in a sweep is the previous file's teardown

**Date**: 2026-09-22
**Lesson**: A `--from-file` sweep runs many files in one process, so a file's
teardown code - sweeps that a single-file run exits before reaching - runs
while the next file loads. A crash that never reproduces standalone usually
lives there.

**Fix**: replay the shard's worklist PREFIX with `--from-file --parallel=1`,
bisecting the prefix, rather than rerunning the crashing file alone. Runner
logs contain non-UTF-8 bytes, so use `grep -a` (plain grep silently finds
nothing). Killing a `--from-file` supervisor orphans its shard child (one ran on
for 1h40m with PPID 1): after stopping a run, `pgrep -f start-index` and kill
the child.
