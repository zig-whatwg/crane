# Testing: Pre-existing allocations distort failure-injection accounting

**Date**: 2026-10-19
**Lesson**: A failure-injection allocator can account for cleanup of a pre-existing fixture even though it never accounted for that fixture's allocation.

**Why**: `checkAllAllocationFailures` compares allocations and frees observed by its allocator. Replacing a live container's allocator changes which wrapper sees its later frees; sharing the same backing allocator does not make those accounting histories identical.

**What Happened**: The session-storage clone test seeded an existing storage shed with `std.testing.allocator`, then injected failures into cloning by substituting a `FailingAllocator`. At failure index zero, the wrapper observed zero allocated bytes and 800 freed bytes when the fixture's outer map was destroyed. The operation had correctly unwound; the test had attributed an older allocation's cleanup to it.

**Fix**: The private-copy test reserves the existing outer map before injection, then restores that map's original allocator before teardown. Each newly cloned key, shelf and bottle retains its own injected allocator, so `checkAllAllocationFailures` checks their cleanup. A separate exhaustive failure-index loop covers destination-map growth: all allocations use the leak-checking `std.testing.allocator` as backing, every induced failure checks that nothing was published, and the successful run checks the complete clone. This second test does not treat the wrapper's byte balance as a leak count, because growing the map can free its pre-existing table. Both cases pass in `tests/html/pm2_session_storage_clone_test.zig`.

**Takeaway**: **Keep allocator accounting aligned with allocation ownership, and separately cover publication paths that can replace pre-existing storage.**
