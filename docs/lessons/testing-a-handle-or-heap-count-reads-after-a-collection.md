# Testing: A handle or heap count compares figures read after a collection

**Date**: 2026-11-19
**Lesson**: A test that compares global-handle or heap figures between two phases must collect garbage before each reading, or it measures when the collector last ran.

**Why**: A dead wrapper's weak handle is counted in V8's used global-handle bytes until a collection takes it, and a collection runs on V8's schedule - driven by how much the code around it allocates, not by what the code under test keeps.

**What Happened**: tests/html/window_index_iframe_lookup_test.zig compared the handles 20 frames looked up by `window[i]` left with those of 20 frames reached through contentWindow first, reading without a collection. It passed for months: every frame's realm deserialized and replaced ~1,120 interface objects (~2.6 MB of V8 heap), so collections ran during each phase. Lane tmpl1 made a realm cheap; 20 frames then passed with no collection, and the lookup phase read 7.5 handles more than the control (+9,136 vs +8,896 bytes) - garbage. With two TestUtils.gc() before each reading the lookup phase held 5.5 handles FEWER than its control on the tip, 4 fewer on main.

**Fix**: Collect (twice: a first pass can leave second-pass work) before every reading a comparison uses; keep the threshold as it was. Probe on both trees (main and tip) with the same instrumented test before deciding whether a change leaks or a test measures timing.

**Takeaway**: **"Leaves no Global behind" is a claim about what survives a collection - read the count after one. A count read mid-schedule changes whenever unrelated work allocates more or less.**
