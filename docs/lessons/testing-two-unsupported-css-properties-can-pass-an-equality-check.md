# Testing: Two Unsupported CSS Properties Can Pass an Equality Check

**Date**: 2026-10-22
**Lesson**: A passing comparison between two computed properties does not prove that either property is implemented.

**Why**: A test can compare two empty CSSOM strings and pass. Adding one property makes the comparison meaningful and reveals the missing reference property.

**What Happened**: SVG's stroke-width-computed.svg passed 15 unit-comparison subtests on a runner that supported neither stroke-width nor text-indent. Each compared the target's computed strokeWidth with a reference element's textIndent; both were empty. Implementing either side alone would lose those passes.

**Response**: Read the passing assertions as well as the failures. Implement text-indent as a prerequisite, then stroke-width, and deliver the combined dependency tip only after all 15 comparisons pass with actual values. Keep the original WPT expectations and compare subtests by name across BASE and TIP; do not dismiss the earlier passes as an exemption from the no-regression rule.

**Takeaway**: **A reference comparison needs a working reference.** Inspect the values behind a baseline pass before treating it as evidence of support.
