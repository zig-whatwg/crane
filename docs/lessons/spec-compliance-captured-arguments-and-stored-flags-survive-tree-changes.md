# Spec Compliance: Captured Arguments and Stored Flags Survive Tree Changes

**Date**: 2026-10-29
**Lesson**: Preserve queued algorithm arguments and mutate stored flags only at the steps that assign them.

**Why**: A current ancestor walk answers a different question from a previously captured argument or a boolean stored by an earlier insertion. Recomputing both when a microtask runs silently changes its behavior.

**What Happened**: Crane derived selectedcontent disabledness from its current select ancestor. HTML instead gives selectedcontent a stored disabled flag and queues moving updates with a particular select and content element. The element may detach or move under a different select before that update runs. Insertion under an option sets disabled to true; removal does not reset it. A current-owner equality check therefore rejects valid captured updates and loses the history that suppresses disabled updates.

**Fix**: Store the flag in the owning impl, recalculate it only on insertion, post-connection and moving, and expose its read through the owner's hook. Keep each queued select/content pair alive with the existing TaskHold and fulfilled/dropped microtask contract. Read the captured select's selected option when execution reaches that step. Native tests queue two captured selects in order, change the current parent, preserve disabledness across removal, collect independently detached captures, and end a realm with an update pending. The complete algorithm is [HTML's selectedcontent section](https://html.spec.whatwg.org/multipage/form-elements.html#the-selectedcontent-element); public atomic-moving coverage remains a separate DOM dependency.

**Takeaway**: **Current structure cannot replace captured arguments or a flag whose last assignment is observable.**
