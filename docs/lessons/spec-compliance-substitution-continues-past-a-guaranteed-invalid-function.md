# Spec Compliance: Substitution continues past a guaranteed-invalid function

**Date**: 2026-10-25
**Lesson**: Values 5's "substitute arbitrary substitution functions" replaces an invalid function with the guaranteed-invalid value and CONTINUES with the rest; stopping at the first invalid one hides the dependencies - and the cycles - of every later function.

**Why**: Cycle detection (Values 5 Appendix A, the guard stack) only sees a reference when substitution actually visits it. A value is invalid as soon as one of its functions is, so an early exit looks like a harmless shortcut, but the functions after it still define which custom properties take part in a cycle, and every participant of a cycle is guaranteed-invalid whatever its fallback.

**What Happened**: Lane vars1's first custom property cascade made `Resolver.walk` return error.Invalid at the first function that failed. In css/css-variables/variable-substitution-variable-declaration.html target5 (`--A: var(--B); --B: var(--A) var(--C); --C: var(--B, 13px)`), resolving --A reached --B, whose `var(--A)` closed the cycle and failed, so `var(--C)` was never visited. --C was later resolved on its own, found --B invalid and took its fallback: "13px". All three browsers say "" - --C is in the cycle through --B's second reference. The unit test pinned from the WPT expectations caught it; the walk now records the failure, keeps substituting, and returns invalid at the end (step 2.5 "replace func ... and continue").

**Fix**:
1. In the walk, catch error.Invalid from a function's replacement, remember it, and continue with the next function; return the guaranteed-invalid value only after the whole sequence is walked.
2. Keep laziness where the spec has it: a fallback is still substituted only when the reference is invalid, so an unevaluated fallback creates no edge (target7's --varC stays 13px).
3. Pin both sides with the WPT file's own cases (target5 "" and target7 "13px"), and the case where the spec and two browsers disagree with the third (target6: Chrome 13px, spec/Firefox/Safari "").

**Takeaway**: **When an algorithm's side effects (dependency edges, cycle marks) come from visiting the input, an early return on the first failure is a behaviour change, not an optimization - walk what the spec walks.**
