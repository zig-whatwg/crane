# Testing: Feature-filtered loops can pass with no iterations

**Date**: 2026-11-01
**Lesson**: When a conformance test builds its cases with feature detection, check how many cases actually ran before interpreting a baseline pass.

**Why**: A test can finish successfully because its loop is empty. Implementing the detected feature then exposes dependent behavior that the same test never exercised on the baseline.

**What Happened**: The page-break legacy-shorthand WPT filters modern break values through CSS.supports. Crane's baseline lacked break-before, so two loops had no values and passed. Registering the modern break properties made those loops execute. The missing page-break shorthands then appeared as two lost passes, even though the new FontFaceSet work being compared was unrelated.

**Fix**: Preserve the failed comparison, repeat the exact isolated BASE/TIP pair three times, and inspect the case-selection code. Attribute the loss to the earlier property registration, then implement the required legacy shorthands through normal parsing and CSSOM paths. Keep the file in final coverage and require the original passing names to be restored; a vacuous baseline pass is an explanation, not an exemption from the no-loss bar.

**Takeaway**: **A pass over an empty case set proves no behavior. Record the cause and repair the missing dependency instead of discarding the regression.**
