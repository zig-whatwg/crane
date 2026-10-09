# Spec Compliance: A fresh draft can differ from shipping color behavior

**Date**: 2026-10-09
**Lesson**: Refreshing a cached specification does not remove the need to compare the algorithm with shipping engines.

**Why**: A newly changed draft can intentionally replace an algorithm that browsers still implement. Blindly preferring the newest prose changes observable results.

**What Happened**: The fetched CSS Color 4 draft specifies pure gamma 2.4 / BT.1886 for Rec.2020. WebKit's Rec2020TransferFunction, Blink's SkNamedTransferFn::kRec2020, and Gecko's Rec2020 conversion still use the same piecewise BT.2020 curve. For color(rec2020 .5 .5 .5), the draft curve gave sRGB bytes 120/120/120, while the browsers' curve gives 139/139/139; the native regression test recorded that difference before the fix.

**Fix**: Follow the unanimous browser behavior under golden rule 2. Use alpha 1.09929682680944, beta 0.018053968510807 and exponent 0.45 in the paired transfer functions. Test both sides of the knee, endpoints, negative extended channels, and the visible gray result. Keep the draft deviation and source references beside the implementation.

**Evidence**: [WebKit ColorTransferFunctions](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/platform/graphics/ColorTransferFunctions.h), [Blink color-space dispatch](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/graphics/color.cc), [Skia transfer functions](https://github.com/google/skia/blob/main/include/core/SkColorSpace.h), [Gecko color conversion](https://searchfox.org/mozilla-central/source/servo/components/style/color/convert.rs); CSS Color 4 §§10.8/19 cached in a99cc3f07e; integrator ruling Q25.

**Takeaway**: **When fresh prose changes a conversion curve, verify the engines and pin a nontrivial converted value.**
