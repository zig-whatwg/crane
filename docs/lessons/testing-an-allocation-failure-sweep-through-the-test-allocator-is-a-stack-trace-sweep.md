# Testing: An allocation-failure sweep through the test allocator is a stack-trace sweep

**Date**: 2026-11-01
**Lesson**: `checkAllAllocationFailures(std.testing.allocator, ...)` over a callback that makes N allocations performs about N²/2 of them, each paying `std.testing.allocator`'s stack-trace capture; sweep through a leak-checking `DebugAllocator(.{ .stack_trace_frames = 0 })` and keep one unlimited run through `std.testing.allocator`.

**Why**: on macOS the test allocator's per-allocation trace costs tens of microseconds, far more than the allocation itself. The sweep replays the callback once per failure index, so that cost is multiplied by the square of the callback's allocation count. The per-index byte check that finds a leak on the failure path is `checkAllAllocationFailures`' own (it compares the FailingAllocator's allocated and freed bytes and prints the failed allocation's trace), not the backing allocator's, so the backing allocator's traces buy nothing there.

**What Happened**: tests/css/ci1_image_set_test.zig's "128 composite image levels ... at every allocation failure" took 93 s alone, over the test launcher's 60 s per-test timeout (lane tlaunch1 found it). A measurement test found 1,577 allocations per run (1,564 of them in parsing the 128 nested `light-dark()` levels), 124 ms per full run through `std.testing.allocator` and 1.2 ms through `smp_allocator`: ~78 us per allocation, almost all of it the trace. The parse-phase indices were 92.7 s of the 93.1 s, so splitting the test by phase or by index range would only have divided the same cost into several tests.

**Fix** (lane tfix1):

```zig
fn checkAllAllocationFailuresUntraced(comptime test_fn: anytype) !void {
    try test_fn(testing.allocator); // a leak on the success path names its allocation
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    const swept = testing.checkAllAllocationFailures(debug.allocator(), test_fn, .{});
    const check = debug.deinit();
    try swept;
    try testing.expectEqual(std.heap.Check.ok, check);
}
```

Every failure index is still injected and every assertion kept; the test went from 92,937 ms to 2,637 ms.

**Takeaway**: **Before splitting a slow allocation-failure test, measure one run through `std.testing.allocator` against a fast allocator: if the allocator is the cost, sweep untraced and keep the traced unlimited run.**

Related: [The test allocator costs more than a fast native operation](testing-the-test-allocator-costs-more-than-a-fast-native-operation.md), [OOM Matrices Replay Unrelated Rows](testing-oom-matrices-replay-unrelated-rows.md).
