# Spec Compliance: Typed OM Fallback Retains the Whole Property

**Date**: 2026-10-28
**Lesson**: When valid CSS has no Typed OM subclass representation, preserve its native property value, including the whole list when one item is unsupported.

**Why**: Native CSS math supports more operations than the Typed OM hierarchy. A valid `round()` or `hypot()` can survive simplification under a supported `calc()` node. Rejecting that descendant turns valid CSS into an exception; falling back item by item can change the property's observable list shape.

**What Happened**: Q95's browser probe found generic `CSSStyleValue` results for unresolved math and unit values for simplified controls. Q124 found that `animation-range-start: round(1em, 1px), 10px` returns one opaque value for the whole property. Q126 confirmed the same shape for a registered repeated `<length-percentage>#` computed value while reifiable controls kept their separate items. Firefox lacked Typed OM; Safari's exceptions and missing items were failures. The integrator ruled Chrome's behavior under [Typed OM §5.2](https://drafts.css-houdini.org/css-typed-om-1/#unrepresentable-values), consistent with Blink's `StyleValueFactory` fallback.

**Fix**: Check the existing parsed tree, including descendants, against the reifier's own supported-operation allowlist before allocating wrappers. Retain the owning native value and its property association, and use its existing serializer. Keep specified registered custom properties unparsed; retain the whole computed Registered owner when any numeric component is unsupported. Ordinary computed values keep their existing rules. Preserve `CSSNumericValue.parse`'s separate SyntaxError boundary. Pin parse/get/getAll/set and retention after declaration removal.

**Takeaway**: **A fallback is still a representation of the whole owning value; successful item conversion does not define the API's list shape.**
