# Testing: Measure that the blocked thing runs before building what blocks it

**Date**: 2026-10-18
**Lesson**: Before implementing a mechanism that defers something (render-blocking defers frames), measure whether that something runs at all in the situation the tests set up - a mechanism that withholds what never happens moves no test.

**Why**: The 32 blocking html/dom/render-blocking/element-render-blocking-*.html files all assert, inside a requestAnimationFrame callback, that the parser has NOT yet reached a late element. They delay the parser with a document.written `<script src=dummy.js?pipe=trickle(d1)>` and expect frames to run during that second. Whether `<link rel=expect blocking=render>` holds a frame back only matters if frames run while the parser waits.

**What Happened**: Lane style2's brief scoped item 6 (render-blocking) around those 32 files and asked for the expect link type and a rendering-update hunk. A three-line Crane probe run on main's Debug runner first - a rAF loop and a setTimeout loop started before a 1 s parser-blocking script - read `frames 0 timers 0 parsedAt 1013`: while the parser waits for a parser-blocking external script (document.written or parser-inserted), Crane's event loop runs no task and no rendering update. So implementing `expect` would move none of the 32 files; worse, a parsed expect link without its parser-pop processing would block every frame until the 30 s timeout and turn the nine files that pass today into timeouts. The integrator routed the real fix (parser suspension at a pending parsing-blocking script) to the parser lane, and the expect work waits for it.

**Fix**:
1. Write a probe that asserts the precondition the target tests rely on (here: frames and timers run during a parser pause), and run it on main.
2. If it fails, the target files depend on that, not on the mechanism - report the measured numbers and route the precondition first.
3. Check what the half-built mechanism would do to the files that pass today before landing any part of it.

**Takeaway**: **Measure that the thing a mechanism blocks actually runs before you build the block** - otherwise the work moves nothing, and a partial version can turn passing files into timeouts.
