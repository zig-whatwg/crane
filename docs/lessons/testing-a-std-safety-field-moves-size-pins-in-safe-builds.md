# Testing: A std safety field moves size pins in safe builds

**Date**: 2026-10-31
**Lesson**: Zig 0.17's std.ArrayList carries `pointer_stability`, a std.debug.SafetyLock that takes one word under runtime safety (Debug, ReleaseSafe) and none otherwise, so every struct holding lists grows in safe builds and every size pin over one moves.

**Why**: Crane pins struct sizes where an allocation class or a cache line depends on them: NodeBase, StyleEngine, the style Rule, and Document's state, which must stay in the 2,048-byte class. Crane's tests and its WPT runner's Crane modules build in Debug, so the pins see the safe layout.

**What Happened**: In the port, NodeBase went from 456 to 472 bytes (2 lists), StyleEngine from 248 to 280 (4), Rule from 216 to 232 (Data 160, FontRule 152), and Document's state from under 2,048 to 2,160 bytes (15 lists). That puts Document's state in the 4,096-byte class in Debug and ReleaseSafe. ReleaseFast is unchanged.

**Fix**: The pins keep asserting Crane's own layout plus the lock words they count, and they say so. tests/html/document_size_class.zig holds a FIXED count of the lists Document's state reaches (15 at the port), so a new list still trips the pin: its own bytes and its lock are not covered. What the real allocation class costs went to the post-port performance analysis, measured with createHTMLDocument's cost page. It is not hidden in the pin.

**Takeaway**: **When a toolchain bump moves a size pin, find the field that grew before you change a number.** Pin your own layout, keep the std part explicit and fixed, and send the real cost to a measurement.
