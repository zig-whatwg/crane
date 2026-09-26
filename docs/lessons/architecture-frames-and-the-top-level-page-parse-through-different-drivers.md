# Architecture: Frames and the top-level page parse through different drivers

**Date**: 2026-09-26
**Lesson**: A frame parses through `scripted_parser.zig`, which has an input stream document.write can write into; the top-level `HTMLParser` has none.

**Why**: Two parser drivers grew separately, and features landed in one.

**What Happened**: document.write worked in frames and silently did nothing at top level: load-error-events-3, execution-timing/068 and ~25 subtests.

**Fix**: Pending - give the top-level parser the same input stream, or one driver for both.

**Takeaway**: **When a feature works in a frame but not at top level, compare the two parser drivers first.**
