# Debugging: In ReleaseSafe an `undefined` stack buffer is a memset per call

**Date**: 2026-11-06
**Lesson**: Under runtime safety, Zig fills every `= undefined` variable with 0xaa when it is declared, so a large scratch buffer on the stack costs a memset of its full size on every call, used or not.

**Why**: The Zig language reference says: "In debug and safe mode, Zig writes 0xaa bytes to undefined memory" (doc/langref.html of the pinned 0.17.1-dev+77c319a0f0). ReleaseSafe is a safe mode. Crane's measured build, the release console, is ReleaseSafe everywhere (docs/performance.md). A stack buffer meant as a cheap scratch arena, which in ReleaseFast reserves stack and writes nothing, therefore writes all of its bytes.

**What Happened**: Lane perf2 profiled `Element.matches` in the release console with macOS `sample` (round 0's query.html, chat2). selector_matching's entry points declared `var parse_memory_buffer: [8192]u8 = undefined` so that a selector parse would allocate nothing, and the parser declared a 4 KiB one of its own. That came to 12 KiB of 0xaa per `matches()` call. One sample offset inside `Element.call_matches` and the memset routine at the top of the stack (`<deduplicated_symbol>`) together took about 12% of the call's samples, more than the matching itself.

**Fix**: A hot path should not declare a large buffer just in case:
- The selector entry points now parse through the document's SelectorQueryCache, so the steady state declares no buffer. A miss parses with the realm's allocator.
- A scratch buffer that must stay can live on an owner that persists (a per-agent scratch area, say), or be made smaller.
- If neither works and the buffer is wanted for its no-allocation property, measure in the mode that ships. ReleaseFast does not show this cost, and the published figures are ReleaseSafe's.

**Takeaway**: **Under runtime safety `= undefined` writes the bytes: a stack scratch buffer on a hot path costs its full size every call, so keep such buffers small, or off the hot path.**
