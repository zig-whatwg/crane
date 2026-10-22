# Spec Compliance: XML prefix and default declaration rules are independent

**Date**: 2026-10-20
**Lesson**: Validate element prefix selection separately from default namespace declaration suppression, even when both share one serialization branch.

**Why**: XML element step 11 handles both the qualified tag name and a local default declaration. Applying one browser's entire branch can change a second behavior that was not approved.

**What Happened**: Row 97's proposed Chrome restoration combined dropping a prefix in the inherited default namespace with dropping a redundant empty xmlns. The latter lost an existing passing WPT assertion. The integrator deferred that mechanism and granted only the prefix change and its existing native expectation in row 97b.

**Fix**: Read DOM Parsing's complete element algorithm and Blink's MarkupAccumulator::AppendStartTagOpen. Add failing native tests for nested prefixed elements and XML fragment serialization. Remove only the condition that excludes prefixed elements from step 11; keep the empty-default expression unchanged. Test matching start/end tags, attribute prefixes, serialization from a new root, unchanged DOM prefixes, and empty declarations independently.

**Takeaway**: **A shared branch does not make two observable mechanisms one change; isolate their tests and preserve any deferred behavior.**
