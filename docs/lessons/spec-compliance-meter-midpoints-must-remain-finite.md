# Spec Compliance: Meter midpoints must remain finite

**Date**: 2026-10-13
**Lesson**: A midpoint of finite gauge bounds must handle both overflowing sums and subnormal endpoints.

**Why**: HTML defines meter's default optimum as the midpoint of its derived minimum and maximum. `(min + max) / 2` can overflow despite finite endpoints, while always halving each endpoint first can turn equal subnormal endpoints into zero.

**What Happened**: Implementing the six meter getters required computing their dependent defaults and clamps. Ordinary 0–1 tests would not distinguish the mathematically required midpoint from either defective arithmetic shortcut.

**Fix**: Use the sum divided by two when finite; otherwise add the individually halved endpoints. Test large same-sign values, equal-and-opposite bounds, and equal smallest subnormal values. Read attributes with HTML's floating-point parser before deriving minimum, maximum, actual, low, high and optimum values.

Sources: [HTML meter element](https://html.spec.whatwg.org/multipage/form-elements.html#the-meter-element) and [WebKit HTMLMeterElement::optimum](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLMeterElement.cpp), which uses `std::midpoint`.

**Takeaway**: **Test arithmetic defaults at both ends of the finite floating-point range.**
