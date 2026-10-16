# Testing: The test allocator costs more than a fast native operation

**Date**: 2026-10-16
**Lesson**: Time a fast operation with `std.heap.c_allocator`; through `std.testing.allocator` the measurement is the allocator's.

**Why**: `std.testing.allocator` is a leak-checking allocator that records a stack trace for every allocation. On macOS that unwind costs tens of microseconds, so it outweighs a native operation that takes a microsecond or two.

**What Happened**: Lane regexop's first timing of `engine.regExpBuiltinExecCaptures` (tests/v8/regexp_operations_test.zig) gave 121 us per repeated exec, against 1.2 us for `engine.matchesPatternAttribute`, which uses the same utility context and cache. The only difference was that exec returns OWNED captures - a slice and a string per group - and the test allocated and freed them with `std.testing.allocator`. With `std.heap.c_allocator` in the timing loop the same exec measured 1.9 us.

**Fix**:
1. Keep `std.testing.allocator` in the correctness tests: it finds the leaks.
2. In a timing loop, pass `std.heap.c_allocator` and free the result there. Pin the allocation-failure paths in a separate `std.testing.checkAllAllocationFailures` test.

```zig
const C = std.heap.c_allocator;
for (0..rounds) |_| {
    const captures = try engine.regExpBuiltinExecCaptures(realm, pattern, false, input, C);
    defer if (captures) |list| { for (list) |c| if (c) |b| C.free(b); C.free(list); };
}
```

**Takeaway**: **A per-call timing through `std.testing.allocator` measures stack-trace capture, not the code under test - time with the C allocator and check for leaks in a separate test.**
