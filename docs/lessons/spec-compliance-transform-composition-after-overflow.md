# Spec Compliance: Equivalent matrix formulas differ after overflow

**Date**: 2026-10-27
**Lesson**: A generic matrix product can expose different CSSOM results from a browser's specialized transform operations once finite inputs overflow.

**Why**: In IEEE arithmetic, infinity times a structural zero is NaN. A full four-by-four product performs products that an axis-specific scale never performs. Skipping every zero product is also wrong: translation and skew intentionally perform some of those products, and matrix()/matrix3d() retain their generic product.

**What Happened**: Row125's finite transform inputs reached nonfinite results. Q55–Q57 browser probes ruled the whole operation composition model, including structural entries, exact zero-angle returns and subsequent operations after overflow. The shared formatter already had the right spelling; changing it would not fix which entries became NaN. Q68/Q69 additionally pinned rotate3d normalization, principal-axis construction and epsilon snapping against WebKit. A finite control exposed a separate precision difference: Q71 kept the shared six-significant-digit formatter, which matched Chrome and Firefox, instead of copying Safari's extra digit.

**Fix**: Follow the ruled operation boundaries, preserve generic multiplication where required, and keep the existing formatter and unresolved-percentage behavior. Pin the browser records alongside finite mixed-order controls and allocation failures; read the engine's design before inventing arithmetic exceptions. The rotate3d reference is [WebKit TransformationMatrix.cpp at f9a95765137](https://github.com/WebKit/WebKit/blob/f9a95765137320ced3ec8b9586bf7abfaaae9abf/Source/WebCore/platform/graphics/transforms/TransformationMatrix.cpp); ordinary operation composition follows Chromium ui/gfx/geometry/transform.cc and matrix44.cc. Take their design, never their source code.

**Takeaway**: **Test observable overflow through sequences of operations. Algebraic equivalence over finite real numbers does not establish browser equivalence over floating-point values.**
