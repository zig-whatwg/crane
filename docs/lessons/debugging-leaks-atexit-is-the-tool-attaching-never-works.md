# Debugging: `leaks --atExit` is the tool; attaching never works

**Date**: 2026-09-21
**Lesson**: Use `leaks --atExit -- <cmd>`, not `leaks <pid>`.

**What Happened**: `gc_bench` runs 500,000 cycles in ~15s, so both `leaks <pid>`
and `heap <pid>` lose the race to attach. Worse, `MallocStackLogging=1` panicked
with "incorrect alignment" — which looked like a tool problem and was actually a
teardown bug (an undefined `DebugAllocator` deinitialised in
`deinitIsolateAllocator`). Most of a phase was spent inferring what one command
would have named.

**Fix**: Fix teardown first, then `leaks --atExit`. Tally by entry point and
divide by cycle count — a clean `1.00/cycle` points straight at the call site.
To prove a residual is startup cost rather than a leak, compare two cycle
counts: 100k vs 400k differing by <3 KB is ~0 B/cycle.

**Takeaway**: **If a memory tool looks broken, suspect your own teardown before
the tool.**
