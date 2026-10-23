# Spec Compliance: Currentcolor must survive filter inheritance

**Date**: 2026-10-23
**Lesson**: A computed drop-shadow keeps symbolic currentcolor until a resolved value is requested for its receiving element.

**Why**: CSS computed values and CSSOM resolved values can differ. Inherited filter lengths already use the parent's font metrics, but currentcolor still refers to the child's color. Resolving both in the parent's cascade freezes the wrong color into the inherited filter.

**What Happened**: The first typed filter implementation turned a parent's currentcolor shadow red. Its green child inherited that red value; changing the child to blue also had no effect. The upstream `css/filter-effects/drop-shadow-currentcolor-inheritance.html` failed both assertions, while aligned Chrome, Firefox and Safari passed both.

**Fix**: Preserve currentcolor while computing the filter's other components. At CSSOM serialization, resolve the retained color against the receiving style through Color's API. Keep the immutable filter text and its URL metadata unchanged. Test both explicit and omitted shadow colors, differing parent/child font sizes, inheritance, mutation, and allocation failure.

The design follows Blink's `ConvertShadow` and `ResolveColorValue` in [style_builder_converter.cc](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/resolver/style_builder_converter.cc), and `ValueForShadowData`/`ValueForFilter` in [computed_style_utils.cc](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/properties/computed_style_utils.cc). No implementation is copied. The normative separation is Filter Effects1 §§6.2–6.3 and CSS Color's computed currentcolor rules.

**Takeaway**: **Before resolving a component during computation, test what inheritance must preserve and what CSSOM resolves for the receiver.**
