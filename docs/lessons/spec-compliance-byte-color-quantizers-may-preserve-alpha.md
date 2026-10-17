# Spec Compliance: A byte-color quantizer may preserve floating-point alpha

**Date**: 2026-10-17
**Lesson**: Verify every component's precision at a shared conversion boundary: byte RGB does not imply byte alpha.

**Why**: A CSS quantizer may deliberately keep alpha as a floating-point number. HTML's limited-sRGB color well requires eight-bit precision for every component, including alpha; its display-p3 destination retains floating-point alpha.

**What Happened**: Crane's existing input sanitizer serialized opaque hex. Extending it with the shared quantizer alone would get half-transparent limited-sRGB wrong: 0.5 must become 128/255, but remain 0.5 for P3. FloatColor.quantize returns byte RGB and a float alpha, so its name does not establish HTML's required precision.

**Fix**: Keep the CSS quantizer's contract unchanged. At the HTML color-well boundary, quantize limited-sRGB alpha independently with the same eight-bit rounding as RGB; preserve P3 alpha. Native tests pin alpha=8/255, the 0.5 -> 128/255 case, and already-serialized clean values that must allocate nothing. Complete upstream color tests provide the end-to-end bar. Validation: 196/196 upstream color cases, 2/2 color-attribute cases and all three new color fixture cases pass; the full native suite also passes.

**Evidence**: HTML “serialize a color well control color” steps 3–6, CSS Color 4 §§16.1/16.5; WHATWG HTML PR10456 and Safari's shipped alpha/colorspace support. Pinned aligned WPT cc74d2669f, color.window.html: Chrome24/196, Firefox70/196, Safari196/196. A newer shipped algorithm follows refined golden rule2. This extends [the destination/conversion boundary lesson](spec-compliance-color-conversion-keeps-the-destination-separate.md) with its per-component precision requirement.

**Takeaway**: **Check the precision of alpha separately from RGB; apply the caller's required rounding at its own boundary.**
