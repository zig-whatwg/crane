# Testing: A footprint test reads each step as its own rise or fall, and forces the allocator path that loses the bytes

**Date**: 2026-11-16
**Lesson**: A test that asserts what the OS charges a process for (macOS phys_footprint, Linux resident set) compares the reading just before a step with the reading just after it, with slack - never a reading against one from an earlier step. And when the fault is on one path of an allocator, the test must force that path, or the other path passes it.

**Why**: The rest of the process moves the footprint while the test runs: libc malloc gives large freed blocks back late, and a test repeated in one process (verify mode) starts beside what the run before left to be released. And V8 15.7's default in-sandbox allocator has two ways to give memory back: a free range at the TOP of its used range is decommitted and reads correctly when used again; a free range BELOW a live block is discarded (MADV_FREE_REUSABLE) and is not counted when written again.

**What Happened**: tests/v8/ab1_array_buffer_footprint_test.zig first compared "written again" with "written" (within 4 MiB). Alone it was red on main (15 -> 79 -> 15 -> 15 MiB) and green with the fix. Repeated ten times in one process it failed 9 times with the allocator correct: "before 28 MiB, 64 MiB written 92 MiB, freed 18 MiB, written again 81 MiB" - the second writing was counted in full, but 10 MiB left over from the run before went out mid-run. The first draft also had no live block above the 64 buffers: on main the freed range could then be at the top and be decommitted, and the test would have passed on the bug.

**Fix**:
1. Each step is a difference over the few milliseconds it takes: `counted(released, reused) >= total - slack`, 16 MiB of slack on 64 MiB (main's last rise is 0).
2. One live allocation above the buffers before they are freed, checked by address, with larger ones tried until one is above.
3. Run a memory test in verify mode before calling it done: ten repeats in one process find what one run alone hides.

**Takeaway**: **Assert a footprint as each step's own rise or fall with slack, and put a live block where the allocator's faulty path needs one - absolute readings from different moments, and the allocator's other path, both lie.**
