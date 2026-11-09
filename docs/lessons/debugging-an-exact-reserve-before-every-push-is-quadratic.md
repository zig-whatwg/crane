# Debugging: An exact reserve before every push_back is quadratic

**Date**: 2026-11-09
**Lesson**: `std::vector::reserve(size() + 1)` before each `push_back` reallocates and copies the whole vector on every insert, because `reserve` allocates exactly what it is asked for and gives up the geometric growth `push_back` would have used. Nothing in the unit tests or the WPT A/B noticed it; only the performance pair did.

**Why**: `reserve(n)` with `n > capacity()` allocates capacity `n`, no more (libc++ and libstdc++ alike). Reserving one more slot each time leaves `capacity() == size()` after every insert, so the next reserve copies everything again. n inserts cost about n^2/2 element copies. The reserve existed for a good reason: the `push_back` after `Object::Wrap` must not allocate, so that no failure can leave a half-made wrapper. But growth has to be decided separately from "make room for one more".

**What Happened**: In the wrapper redesign's P4, `v8_NodeWrapper_Attach` registers every node anchor in a per-agent vector, and it reserved `anchors.size() + 1` before allocating the anchor. The PRE gate was green: `zig build test`, test-browser and both verify runs passed, and the FULL A/B and the no-snapshot full run matched generation 213 (1,857,177 passing). The Crane-only perf pair on chat.local then measured:
- dom.create-element at 9.569x the time of round 5's console, and dom.build-tree at 4.437x;
- gc_bench wrapper-churn-nogc 0.19 -> 0.91 s;
- qsa-deep 5.18 -> 23.52 s, with its footprint 134.8 -> 212.7 MB.
Every workload that keeps many wrappers alive at once paid per wrap for the number already alive. The binding loops got faster in the same run (getter-loop 0.758), so the slowdown was in the wrap path, not in the unwrap path.

**Fix**: Reserve only when the vector is full, and then double it (floor 1,024): `if (size == capacity) reserve(max(1024, 2 * capacity))`. The shrink in the weak processing keeps twice the live count, so growth and shrink do not thrash. tests/v8/node_anchor_test.zig pins it through the probe's capacity: after 3,000 wraps the capacity is a power of two and larger than the size.

**Takeaway**: **Making room for one more and choosing a growth policy are two decisions; a reserve on the per-object path must grow geometrically. Correctness gates do not catch quadratic cost. For engine work, the performance pair (or a gc_bench timing row) is the gate that does, so read it before calling a change done.**
