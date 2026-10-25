# Testing: Support detection activates previously skipped assertions

**Date**: 2026-10-24
**Lesson**: Adding support for a longhand can activate existing tests of its containing shorthand, even when those tests previously passed.

**Why**: A test guarded by `CSS.supports()` can report PASS without executing its assertions. Registering a new property changes the obligations that the same test exercises.

**What Happened**: The font-variant longhands made six serialization cases exercise real assertions. A seventh case set `font-variant: normal` before `font: menu` and started failing because the separate system-font delivery had not yet supplied the reset. Its previous PASS did not prove that reset worked. Three isolated pairs reproduced the same lost name.

**Fix**: Read the complete conditional test, keep the loss blocking, and deliver the dependent shorthand behavior with the newly exposed longhands. Preserve the intermediate failing results and the original baseline. Test the direct getter, each longhand and `cssText` separately: system-font pending values expose different serialization rules. Require the original test name and every other baseline PASS to survive the combined comparison.

**Takeaway**: **When support detection changes, inspect the assertions it enables and complete their dependent behavior in the same accepted delivery.**
