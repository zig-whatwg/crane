# Spec Compliance: A property any animation drives starts no transition

**Date**: 2026-11-06
**Lesson**: CSS Transitions 1 section 4 says a transition's value is not applied while a CSS Animation runs the property; the browsers go further and start no transition at all for a property an animation in effect on the element drives - Web Animations included.

**Why**: Gecko's nsTransitionManager skips a property its effect set animates (HasEffectiveAnimationOfProperty) and Blink's CanCalculateTransitionUpdateForProperty returns false for it; the before- and after-change styles of an animated property are the animation's values, so a transition between them would be noise. web-animations/interfaces/Animation/style-change-events.html uses this as its probe: a "covering" opacity animation is played right after each API call, and a transitionrun means the API flushed style early. Chrome 27/27, Firefox 24/25, Safari 26/27.

**What Happened**: Lane anim1's first transitions compared base styles only (Blink's before/after-change styles) and started an opacity transition under the covering animation: style-change-events.html fell from 23/26 to 0/26 in the probe, before any A/B.

**Fix**: css_transitions.Run.property returns before step 1 for a property effect_stack.animatesProperty reports (an in-effect effect, not an owned transition, with the property among its keyframes' properties), so it neither starts nor cancels a transition.

**Takeaway**: **Before trusting a spec's narrower rule, probe the files that use the behaviour as a measuring stick: a test whose probe is "did a transition start" tells you what all three browsers do.**
