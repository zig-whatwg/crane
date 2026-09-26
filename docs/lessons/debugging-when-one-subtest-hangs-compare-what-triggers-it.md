# Debugging: When one subtest in a file hangs and its siblings pass, compare what triggers each one

**Date**: 2026-09-26
**Lesson**: The string-compilation-* files each had one subtest that timed out while the rest passed, and the feature under test (`import()`) looked broken.

**Why**: The hanging subtest was the only one triggered through `click()`, which was a no-op.

**What Happened**: Time went into `import()` before anyone compared the triggers.

**Fix**: Compare how each subtest is started; the odd one out names the missing piece.

**Takeaway**: **Before blaming the feature, diff what triggers the passing and the hanging subtests.**
