# Spec Compliance: Color contrast conversion has an observable precision boundary

**Date**: 2026-10-23
**Lesson**: Preserve CSS color data at its own precision, then follow the browser's numeric precision at an explicitly lossy destination.

**Why**: Non-finite and overflowing color components expose the operation order and precision of a color conversion. A double-precision equivalent can select a different contrast color from the shipping browsers.

**What Happened**: Browser probes for contrast-color gave a majority for every tested input. Blink's single-precision conversion through XYZ-D50, followed by one inverse sRGB matrix and byte quantization, reproduces those results. Applying chromatic adaptation separately or using double precision changes infinity cancellation and overflow. Gamut mapping also changes finite controls and is not part of this path.

**Fix**: Keep unbounded values in CSS components and computed serialization. For contrast only, use the evidenced f32 conversion, map NaN to zero at the byte destination, quantize, and take the byte color's WCAG luminance. Other gamut-mapping callers must stop when a binary-search midpoint makes no progress. Pin non-finite inputs and finite out-of-gamut controls.

**Takeaway**: **A mathematically equivalent conversion is not necessarily browser-equivalent at overflow, NaN, and quantization boundaries.**
