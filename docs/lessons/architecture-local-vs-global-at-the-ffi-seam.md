# Architecture: Local vs Global at the FFI seam

**Date**: 2026-09-21
**Lesson**: The C++ wrapper allocates a `Global<T>` wherever V8 lends a `Local<T>`.

**Why**: V8's API returns borrowed handles scoped to a `HandleScope`. Crossing
into Zig needs something that outlives the scope, so the wrapper heap-allocates
— and ownership transfers to the caller, silently.

**What Happened**: One unstated convention produced identical leaks in ~20
unrelated places at once: `GetCurrentContext` (2 per element),
`GetArgument` (1 per element), and the `[Global]` getter path. 635,764 leaked
handles per 200,000 cycles, on the DOM's hottest paths, with a green test suite.

**Fix**: `leaks --atExit -- <cmd>` named all three in one run. Dispose what you
acquire, or restructure so you never acquire it.

**Takeaway**: **Every `v8_*` call returning a pointer allocates. The caller owns it.**
