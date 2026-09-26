# Testing: Regression-check handle changes with timers, not DOM

**Status**: now a rule - "Regression protocol for handle-ownership changes" in AGENTS.md.

**Date**: 2026-09-21
**Lesson**: DOM WPT files do not catch V8 handle-ownership breakage.

**What Happened**: Two crashing regressions passed 12 DOM files and were caught
only by `html/webappapis/timers/ --parallel=3`. Timers exercise callback
retention across turns of the event loop; DOM property access does not.

**Fix**: Run timers three times and count crashes. The baseline floor is 0–1
per run.

**Takeaway**: **Pick the regression suite that exercises the lifetime you
changed, not the one that touches the same file.**
