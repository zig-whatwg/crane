# Testing: A use-after-free that reads stale bytes passes - allocate from pages unmapped on free

**Date**: 2026-10-12
**Lesson**: To make a test red on a use-after-free, give the code under test an allocator whose free unmaps the memory, so the stale read faults instead of reading what was there.

**Why**: A freed block usually keeps its bytes until something reuses it, and std.testing.allocator's bucket slots are poisoned only in some modes. A reader that checks a flag in the freed struct can see a plausible value - or the poison, which a defensive check (`orphaned or is_closed`, both non-zero) happens to accept - and carry on.

**What Happened**: Lane inst5 wrote the two-Browser test for the navigables list (tests/html/instances_navigables_test.zig): Browser A's end freed Browser B's retired browsing contexts through the process-wide `retired` list, and B's script then read `w.closed` and `w.length`. On base the test PASSED: Window.navigableOf read the freed context, the poisoned `orphaned` byte read as true, and the getters answered `closed === true`, `length === 0` - exactly what a live retired context answers.

**Fix**: The test gives both Browsers a counting wrapper over `std.heap.page_allocator` (`Pages`): every allocation is its own mapping, and free unmaps it. On base the same read is a SIGSEGV at the retired context's address; at the tip it passes. The wrapper counts live allocations, so the test still fails on a leak (the check `testing.allocator` would have made).

```zig
const Pages = struct {
    live: std.atomic.Value(isize) = .init(0),
    fn allocator(self: *Pages) std.mem.Allocator { return .{ .ptr = self, .vtable = &vtable }; }
    // alloc/free forward to std.heap.page_allocator.vtable and count;
    // resize/remap forward unchanged.
};
```

**Takeaway**: **A green result over freed memory proves nothing: when the bug is a read after a free, run the red test on an allocator that unmaps on free, and count its allocations so leaks still fail.**
