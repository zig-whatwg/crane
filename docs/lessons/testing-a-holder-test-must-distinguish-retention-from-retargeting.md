# Testing: A holder test must distinguish retention from retargeting

**Date**: 2026-10-10
**Lesson**: Observe the held object's lifetime directly, and prove the test fails when that one hold is removed.

**Why**: A queued CSP violation selects its event target when it runs. A detached element retargets to the document whether the element survived collection or not; a reattached element is already kept alive by the tree. Neither event-target assertion proves the task holds its element.

**What Happened**: CSP3's first two GC fixtures passed on main without the new element hold. Integrator review S2 caught that they tested event targeting rather than retention. The added native test and Crane WeakRef fixture observe the detached element before dispatch, then its collection after dispatch releases the hold.

**Fix**: Make the WeakRef in an earlier job while the tree still owns the element. In the later job, trigger the violation, detach the element and drop every strong script reference. Collect twice before dereferencing the WeakRef, while the violation task remains queued. Assert the element survives. Run the violation task, leave the dereference's job, collect again and assert the element is gone. Verify both tests fail on a temporary tree with only the element hold removed, then restore the hold and rerun.

**Takeaway**: **A holder test needs a red without the holder. WeakRef construction and dereference themselves retain their target for the current job, so task boundaries are part of the test.**
