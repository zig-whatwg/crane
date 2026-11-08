# Spec Compliance: Clamp only the final animated value

**Date**: 2026-11-08
**Lesson**: Interpolation, addition and accumulation work on unclamped values; only the final composited value is range-checked, so an intermediate representation must be able to hold an out-of-range value - including across a text round trip.

**Why**: CSS Values 4 3.1: "Even if interpolation results in an out-of-range value, addition/accumulation might 'correct' the result ... clamping is only applied to the final result of applying all interpolation-related operations." rgb(128, 128, 128) + rgb(255, 0, 0) is a red of 383, and interpolating it with another overflowed keyframe can land back in range (WPT addition-per-property-001 "overflowed", which Chrome, Firefox and Safari pass).

**What Happened**: Crane's legacy colors combined as `RgbaColor` (u8 channels), so every step clamped and rounded: the overflowed case gave rgb(192, 128, 192) for rgb(255, 128, 255), iterationComposite colors stopped at 228 instead of 250, and box-shadow / drop-shadow() colors the same. Registered `<color>` custom properties clamped a second way: a combination's result travels as text, and the text of an out-of-range legacy color is its clamped rgb().

**Fix**: Intermediate legacy colors are float premultiplied sRGB (an exact `.rgba` when every channel is a byte, else an unclamped resolved legacy color, color_values.unclampedLegacy); clampFinal makes them a legacy rgb() color, and the transition current value goes through it too. For custom properties, an evaluation-scoped table (effect_stack TypedCustoms) keeps each combined text's typed value, holding a reference on the text so its address cannot be reused while the table lives. interpolation.zig's own unit test had pinned the clamped intermediates (128 + 128 = 255); it now checks 256 before clampFinal and 255 after.

**Takeaway**: **Range-check once, at the final value; every representation in between - including a serialized one - must carry out-of-range values unchanged.**
