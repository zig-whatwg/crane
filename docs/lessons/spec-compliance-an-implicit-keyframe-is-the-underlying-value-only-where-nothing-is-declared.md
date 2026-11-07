# Spec Compliance: An implicit keyframe is the underlying value - with its own easing, and only where nothing is declared

**Date**: 2026-11-07
**Lesson**: A CSS animation's generated 0%/100% keyframe holds the UNDERLYING value (sampled each time, not the computed value baked at creation), takes the keyframe's easing (the animation-timing-function), and applies to a property only where that keyframe declares no value of its own - a shorthand's implicit entry must not hide the longhands a declared block sets at the same offset.

**Why**: CSS Animations 2 3.2 step 3 adds "the computed value of that property" to the generated keyframe; Blink (neutral keyframes, CssKeyframeEffectModel::GetComputedKeyframes for getKeyframes) and Gecko (CSSAnimationKeyframeEffect::GetKeyframes fills values only for reporting) sample the live underlying value, so a later change of the base value moves the animation. Web Animations' own implicit keyframes are linear; a CSS animation's generated keyframe carries animation-timing-function, so it must be a real keyframe with an empty value, not a missing one.

**What Happened**: Lane anim1 (batch 3) stored implicit values as empty strings in the generated keyframes. `@keyframes { from { border: 1px solid blue } to { border: 1px solid var(--c) } }` keeps the `to` shorthand as one pending declaration ("border"), so the 0% keyframe got an implicit "border" - and the effect stack, seeing an implicit border at 0%, used the underlying red for border-bottom-color instead of the declared blue of the same keyframe (css/css-variables/variable-animation-substitute-into-keyframe-shorthand.html).

**Fix**: The effect stack uses an implicit entry for a longhand only where the keyframe has no computed value for it; a group "sets" a shorthand when it sets any of its longhands. getKeyframes() fills implicit values with the target's current base computed value (composite "replace").

**Takeaway**: **Model a generated keyframe as a keyframe with an empty value that means "underlying", keep its easing, and let a declared value in the same keyframe always win over it.**
