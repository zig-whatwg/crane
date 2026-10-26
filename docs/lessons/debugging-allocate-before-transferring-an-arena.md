# Debugging: Allocate before transferring an arena

**Date**: 2026-10-25
**Lesson**: Finish allocations through an ArenaAllocator before copying that arena into its returned owner.

**Why**: An arena allocator handle refers to the arena's mutable state. Copying the arena before a later field expression allocates copies the old state, so the returned owner cannot free the new allocation.

**What Happened**: The first if() condition parser returned its special `else` expression as a struct literal whose first field copied the arena and whose second field allocated the expression. The copied arena had no buffers. Allocation-failure sweeps caught 120 allocated bytes with zero freed; ordinary parsing produced correct results but leaked the expression's buffer.

**Fix**: Allocate the expression in a local first, then construct the returned owner from the updated arena and expression. Keep an `errdefer arena.deinit()` around allocation errors. The if1 grammar tests use `std.testing.checkAllAllocationFailures` to exercise both successful cleanup and failed construction.

**Takeaway**: **A struct literal's fields can mutate an earlier field's source. Transfer resource ownership only after those mutations finish.**
