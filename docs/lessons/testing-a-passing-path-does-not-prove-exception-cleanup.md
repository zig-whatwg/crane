# Testing: A Passing Path Does Not Prove Exception Cleanup

**Date**: 2026-10-27
**Lesson**: When fixing a failing script also removes a leak, repeat its resource accesses followed by deliberate uncaught exceptions before accepting cleanup.

**Why**: A successful script may avoid the leaking return path. A passing assertion and a clean allocator report do not establish that ordinary script exceptions release the same resources.

**What Happened**: CSSMarginRule had a stale interface skip-list entry even though its pinned IDL no longer referenced the supposedly missing type. Accessing a margin rule created its native model, but script could not see the interface. The original 31-case selection reported one ReferenceError failure and five leaked allocations. Removing only that entry made all 31 unchanged cases pass with no allocator leaks; four exposure tests also passed.

The liaison required an additional check before accepting the leak result. Two native tests parsed the same page sheet, accessed its cssRules and the margin rule's style, then left either a deliberate Error or an undefined-global ReferenceError uncaught. Each verified that the public engine reported the intended exception, not a setup failure, and then used ordinary realm/agent/runtime teardown with std.testing.allocator. Both passed with zero leaks. No ownership change was needed in this lane. The general defect in returning instances of other unregistered interfaces was routed to the bindings owner separately.

**Fix**: Preserve the original failing selection and rerun it unchanged. Add a separate exception regression with the same resource accesses, no script catch, no forced collection and no manual resource cleanup. Verify the intended exception was reached; let the normal teardown and leak-checking allocator detect stranded resources. If it still leaks, isolate the holder and prove which release was missed before changing ownership.

**Takeaway**: **A clean successful path is evidence about that path; test the exception path explicitly.**
