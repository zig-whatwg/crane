# Spec Compliance: A degenerate cubic-bezier tangent follows the browsers, not the prose

**Date**: 2026-10-30
**Lesson**: CSS Easing 2.2.2's extrapolation says "return 1" for cubic-bezier(1, 1, 1, 1) above 1 (and 0 for cubic-bezier(0, 0, 0, 0) below 0), but every browser treats both as linear; a WPT pins the linear equivalence.

**Why**: Extrapolation outside [0, 1] only shows when an effect's easing overshoots and a keyframe easing then reads an interval distance beyond the range - a path no test reached until animated values were applied.

**What Happened**: Lane rendering3's probe lost one PASS name in effect-value-transformed-distance.html: before animated values existed both elements showed the same underlying width, a coincidental pass. With values applied, the linear-equivalent keyframe easing returned 1 above 1 while linear kept going (102.407px vs 100px). Chrome 156, Firefox 159 and Safari 27 pass the file 28/28 (wpt.fyi stable 07ce6e987a); Blink's gfx::CubicBezier::InitGradients documents the rule: both control points coincident with an end point give slope 1, a vertical tangent gives slope 0.

**Fix**: easing.zig's cubicBezier uses Blink's start and end gradients, with the evidence in a comment (golden rule 2), and a native test pins both degenerate curves and the vertical-tangent case.

**Takeaway**: **When a feature first exercises an algorithm's edge (extrapolation, overshoot), check the browsers before trusting prose written for the common case - and treat a lost "pass" that only held because nothing was applied as a real defect to fix, not noise.**
