# Architecture: A transition's keyframes are its typed values, not their text

**Date**: 2026-11-07
**Lesson**: A CSS transition made from style must run between the computed start and end values it captured, not between those values serialized to text and parsed again.

**Why**: CSSOM serialization keeps six significant digits. A transition whose keyframes are the serialized computed values loses precision exactly where the value is sensitive: `skewX(10rad)` computes to 572.957795deg, serializes as 572.958deg, and tan() of the difference moves the matrix by 1e-4 - more than WPT's tolerance. CSS Transitions 1 section 3 runs the transition "from the start value to the end value"; Blink's TransitionKeyframes hold the computed values themselves.

**What Happened**: Lane anim1 batch 4 made transform lists interpolate. CSS Animations and Web Animations matched css/css-transforms/animation/transform-interpolation-001's skewX(10rad) perspective() cases, but CSS Transitions missed them by 2e-4 to 1e-3 - including at p = 1, where the value is V_B itself.

**Fix**: css_transitions.ownLonghandValues returns the transition's typed start and end values while its effect still has the keyframes it was made with (script's setKeyframes drops that), and effect_stack substitutes them for the keyframes' re-cascaded text - the shape batch 2 already used for custom properties (ownCustomValues), so attr() taint and precision survive the same way.

**Takeaway**: **Values a step computed should travel typed to the step that uses them; a round trip through serialization is a lossy cast, even when the text looks complete.**
