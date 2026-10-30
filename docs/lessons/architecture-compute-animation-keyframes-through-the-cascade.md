# Architecture: Compute animation keyframes through the cascade, and key animated styles per target

**Date**: 2026-10-30
**Lesson**: A keyframe's value is "computed against the element" by cascading the keyframe's declarations above every origin on that element and reading the result back; the animated result then re-enters the same cascade at the animation origin, and only animated elements' style keys move.

**Why**: Web Animations 5.3.2 computes a keyframe value "according to the Computed Value line, using the computed values of element as the context": em, rem, var(), env(), inherit, currentcolor, revert and the logical-to-physical mapping all apply. A second compute path for keyframes would have to re-implement every one of them and drift. And animated values change every frame: a document-wide style key would make one spinner invalidate every element's cached style on every frame that reads style.

**What Happened**: Lane rendering3 (animated values). The design delta first proposed a per-document values revision in the style key; the integrator required a per-target key (Blink and WebKit invalidate only animated elements and their dependents). The keyframe path reuses `css.cascade.cascade(matched ++ [keyframe block @ transition origin])` - the top origin, so no author `!important` hides the keyframe's own value - and the composited values enter `cascade(matched ++ [values @ animation origin])`, which sits between normal and important declarations (Cascade 5 6.3). The properties other values depend on (font-size, line-height, color) composite first so `2em` keyframes resolve against the animated font-size (Blink StyleCascade's high-priority interpolations).

**Fix**:
1. `Origin.animation` (above author normal, below every important) and `Origin.transition` (above all) in cascade.zig's priority; `revert` from either rolls back as author.
2. `effect_stack.component(element, pseudo)`: 0 with no effect, else the registry's values revision; the cached style stores it with its own serial and its parent's serial, and resolves again when either moved - so inheritance follows an animated parent without a global key.
3. Pull, never push: no per-frame style work happens unless something reads style.

**Takeaway**: **Reuse the cascade for "compute this value as if declared here" instead of writing a second compute path, and give time-varying style its own per-element key component so it never invalidates the rest of the document.**
