# Architecture: Pending image descriptors have one read contract

**Date**: 2026-10-24
**Lesson**: A specified math descriptor needs a distinct pending state that every reader respects.

**Why**: Keeping a numeric field beside an owned expression preserves the computed loader API, but its default numeric contents are inactive until the expression computes. A reader that ignores the pending state can silently select the wrong resource.

**What Happened**: Image-set resolution math introduced a pending descriptor beside the existing dppx field. A test places a usable literal candidate before a pending one: selecting that first candidate would conceal incomplete computation. Cursor hotspots similarly need to distinguish pending coordinates from an absent hotspot. Legacy cross-fade progress uses the same nullable read contract while its owned number/percentage expression is pending.

**Fix**: Expose one accessor for each state contract. Reject selection of any unresolved set defensively, compute every descriptor with the actual winning source, and require computed tests to show no pending payload. Cover ownership, equality and all dependency queries, while keeping literal/default/zero behavior unchanged.

**Takeaway**: **Make pending data explicit, and test that defensive readers cannot hide a missing compute step.**
