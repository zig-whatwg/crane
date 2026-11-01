# Testing: CSS family cohorts include cross-directory quirks

**Date**: 2026-11-01
**Lesson**: A property's targeted A/B must include every WPT directory that tests its behavior, including `quirks/`.

**Why**: Tests organized by a cross-cutting parsing rule can exercise a property outside its named CSS family directory. Registering a previously absent property can also turn vacuous equality checks into meaningful comparisons.

**What Happened**: The Tables A/B covered `css/css-tables/` and passed. A later full comparison lost seven `border-spacing` subtests in `quirks/unitless-length/quirks.html`. BASE returned an empty computed value for both the test and reference because the property was absent. TIP implemented the property but rejected its unitless quirky lengths, so the test computed to `0px` while the reference computed to the expected pixel length. Three isolated BASE/TIP pairs reproduced all seven losses and no other differences.

**Fix**: Read CSS Values 4 Appendix C, keep its property membership in the existing `quirky_length` table flag, and pass that flag through both spacing axes. Pin the seven values, strict parsing, functional-notation exclusions, range checks, CSS.supports and allocation failures in native tests. Include all worklist `quirks/` sources in the subsequent family comparison, alongside Tables and the unchanged cross-property controls. Keep the original failed comparison and its exact lost names as evidence.

**Takeaway**: **Choose a family cohort by behavior and callers, not only directory names; a vacuous BASE pass is still a pass that must be preserved.**
