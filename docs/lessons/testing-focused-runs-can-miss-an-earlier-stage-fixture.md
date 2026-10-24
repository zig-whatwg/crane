# Testing: Focused runs can miss an earlier stage fixture

**Date**: 2026-10-24
**Lesson**: When a later delivery changes a value representation, search all existing fixtures for the earlier spelling and run the full native suite.

**Why**: A focused scratch suite can cover a newer fixture while omitting an older copy that the normal test root still includes.

**What Happened**: Typed image-set values canonicalized string options to url() and computed resolutions to dppx. The later authored-URL tests had the approved spelling changes, but the URL-only delivery's earlier fixture still pinned the raw representation. The full native gate found its two cases and their allocation-failure wrapper.

**Fix**: Preserve the failing gate evidence. Check each changed expectation against authoritative parsing and computed-value tests, obtain the required grant, and change only the affected expectations. Keep inputs, ownership assertions, destruction order and allocation-failure loops intact. Re-run all gates on the actual changed tree before measuring or committing.

**Takeaway**: **A focused pass covers its selected fixtures; the complete delivery gate checks the earlier fixtures that still ship.**
