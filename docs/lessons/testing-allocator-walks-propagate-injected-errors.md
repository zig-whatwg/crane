# Testing: Allocator walks propagate injected errors

**Date**: 2026-10-03
**Lesson**: An allocation-failure walk must return an injected OutOfMemory even when the successful path expects a different operation error.

**Why**: checkAllAllocationFailures recognizes OutOfMemory as the intended failure at each allocation point. An unconditional expectError(ConstraintError, operation) instead turns a valid injected failure into TestUnexpectedError.

**What Happened**: A record-write regression first caught a genuinely dangling replacement key. After the ownership fix, its allocation walk failed while cloning a duplicate add's key: the test required ConstraintError even though that allocation was deliberately failing.

**Fix**: Propagate OutOfMemory from the operation to the walk. For other errors, assert the required ConstraintError, and reject unexpected success. Keep the successful-run result-key and duplicate-key assertions, so accepting the injected allocation error does not relax the operation's behavior.

**Takeaway**: **Let the allocation walker recognize its injected failure; assert domain errors only after allocation succeeds.**
