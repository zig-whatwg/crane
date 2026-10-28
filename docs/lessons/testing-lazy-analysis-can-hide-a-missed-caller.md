# Testing: Lazy analysis can hide a missed caller

**Date**: 2026-10-28
**Lesson**: Audit every caller when a Zig function changes signature; a passing targeted test analyzes only the paths it reaches.

**Why**: Importing a module does not require Zig to analyze every function in it. A storage or parser test may compile successfully while a CSSOM setter elsewhere still uses an obsolete signature. Registering that setter through a binding can expose the error even in a test that never invokes it directly.

**What Happened**: The nesting ownership change added a ResolutionPlan parameter to nestingInside for transactional promotion of a flat parent. The CSSOM insertion caller was updated, but CSSStyleRule.set_selectorText still called the old form. Shared-reference contracts, storage bounds and the original 22 storage controls passed. The mutation fixture then failed to compile at the missed setter. I incorrectly treated the matching diagnostic as independent because it did not call selectorText; its V8 binding registration instantiated the setter and found the same compile error. Neither attempt produced a behavioral or timing result.

**Fix**: Search all callers after changing the signature and classify what each needs. In this case selectorText parsing needs only the nearest context kind, so a separate read-only helper avoids allocating a parent resolution before rejecting invalid input. The real replacement continues through the transactional plan. Preserve compile failures distinctly from failed test cases, and run the full required gates on the final tree.

**Takeaway**: **A targeted green test proves the paths it analyzes, not that every caller in the imported modules compiles.**
