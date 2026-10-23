# Spec Compliance: Convert Between sRGB Coordinates Directly

**Date**: 2026-10-23
**Lesson**: HSL, HWB and sRGB conversions should use their direct coordinate algorithms, without an unnecessary XYZ round trip.

**Why**: Mathematically cancelling conversion matrices do not cancel exactly in floating-point arithmetic. Tiny residue can change byte rounding or create a hue and large saturation near HSL's white singularity.

**What Happened**: The new typed color path sent every conversion through XYZ. An exact neutral half-channel became slightly less than one half, so CSSOM wrote 127 instead of 128. Plain white converted to HSL with a spurious hue and saturation, changing a white/blue mix. The independent raw probe showed that OKLCH white and LCH white had different residues; preserving a particular browser's residue would have required an unjustified source-specific exception.

**Fix**: Use CSS Color 4 §§7.1–8.2's direct conversions within the sRGB/HSL/HWB family. Express HWB's component interpolation between whiteness and one minus blackness so both endpoints stay exact. Keep the common XYZ path for other spaces. Apply the normative powerless-hue rules, including CSSWG #14133's suppression of positive colorfulness noise, rather than introducing an arbitrary rounding epsilon. Test exact halves, white controls, missing components and extended ranges; compare existing WPT PASS names before committing.

Design reference: WebKit `ColorConversion.cpp`, its HSL/HWB-to-sRGB and sRGB-to-HSL/HWB conversions. The implementation was read for its design, not copied. The newer achromatic rule is implemented by WebKit commit `16b6493d0355eb3608b0d766c963874f56c7a0ab`.

**Takeaway**: **Choose the direct color-space conversion before adding tolerances to its output.**
