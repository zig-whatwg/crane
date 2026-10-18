# Spec Compliance: Named setters need the generated reaction boundary

**Date**: 2026-10-18
**Lesson**: A special setter that delegates to an IDL operation must enter its generated interface, even when both live in the same impl.

**Why**: The generated interface supplies cross-cutting behavior such as CEReactions. A direct call to the impl can mutate the correct attribute while leaving the reaction in the backup queue.

**What Happened**: `element.style.fontSize = '10px'` serialized the style correctly, but `attributeChangedCallback` had not fired when the setter returned. CSSStyleDeclaration's named setter called its own `call_setProperty` directly. The isolated Crane test failed on the callback count, and upstream `attribute-changed-callback.html` passed only 12 of 13 subtests.

**Fix**: Follow CSSOM 6.6.1's named-setter algorithm through `interfaces.CSSStyleDeclaration.call_setProperty`. Its generated CEReactions scope invokes queued reactions before returning. Test the observable callback order, including an outer callback that mutates another element through a dashed CSS property. Blink likewise marks its anonymous named setter `[CEReactions]` in [CSSStyleDeclaration.idl](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/css_style_declaration.idl).

**Takeaway**: **Attribute contents alone cannot prove a setter is correct; assert reaction order at the call boundary.**
