# Debugging: Computed shorthands may need symbolic colors

**Date**: 2026-10-26
**Lesson**: Keep a symbolic color until the consumer that decides whether to omit it; resolving it first can erase a distinction CSSOM exposes.

**Why**: A computed `text-decoration` shorthand omits its initial `currentcolor`, while an explicit color remains even when it equals the element's color. Comparing resolved RGB values cannot recover that distinction. The `text-decoration-color` longhand still returns the resolved color, and `text-emphasis` uses a different shorthand rule.

**What Happened**: Crane's common computed-shorthand assembly resolved every color before calling the property serializer. Once the Decoration properties were registered, `color:rgb(10, 20, 30); text-decoration:underline solid currentcolor` returned `underline rgb(10, 20, 30)` instead of `underline`. The isolated CSSOM test reproduced the failure before the assembly condition changed.

**Fix**: Following Blink's `TextDecoration::CSSValueFromComputedStyleInternal` and its `IsCurrentColor` check, retain the symbolic value only for the `text-decoration` shorthand's `text-decoration-color` component. The existing serializer can then omit its initial value. Test both symbolic currentcolor and an equal explicit RGB color, plus the resolved longhand and inherited shadows. The isolated test, the whole upstream computed-decoration file and the inheritance fixture pass.

**Takeaway**: **Resolve values according to the receiving API's contract; a shared preprocessing step must not erase distinctions that a later serializer needs.**

Design reference: https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/properties/shorthands/shorthands_custom.cc (`TextDecoration::CSSValueFromComputedStyleInternal`).
