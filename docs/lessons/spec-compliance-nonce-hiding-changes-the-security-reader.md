# Spec Compliance: Nonce hiding changes the security reader

**Date**: 2026-10-16
**Lesson**: When implementing nonce hiding, every CSP consumer must read the private nonce slot, and anything that keeps that value must still copy it.

**Why**: HTML's nonce IDL setter changes `[[CryptographicNonce]]` without
changing the content attribute. Connection to a document with a header-delivered
CSP empties the content attribute while preserving the slot. Reading the
attribute for authorization therefore loses valid nonces and can return an old
value after script changes `.nonce`.

**What Happened**: Row 46's BASE reflected HTMLElement's nonce through the
content attribute and left SVGElement's accessors unimplemented. Script, link,
and style CSP callers also borrowed the attribute. Native slot tests failed on
both element families before the implementation changed.

**Fix**:

1. Keep an owned slot in each owning element type. Attribute changes update it;
   removal clears it; cloning makes an independent copy. SVG allocates its
   additional state only when needed, using `dom.orphan_states.Swept` so both
   normal destruction and unwrapped-orphan cleanup release its strings.
2. While hiding the attribute, detach the slot's saved allocation, set the
   attribute to empty through the ordinary attribute path, and restore the
   saved slot. An explicitly empty slot still needs hiding when its content
   attribute is nonempty. Header-delivered report-only CSP also triggers hiding.
3. Return owned strings from the IDL getters. Let internal CSP callers borrow
   through a reader installed beside the attribute-change hook. Keep existing
   copies in script records and asynchronous module-fetch requests.
4. Test slot behavior separately from rendering: inspect attributes and selectors,
   then verify that a private-only nonce authorizes a script. Allocation-failure
   tests check that setters and clones preserve their previous values.
5. Pin the connection phase and callback order. All three browsers enqueue a
   custom element's connected callback before its nonce-hiding attribute
   callback. HTML nonce hiding therefore uses the existing post-connection
   phase, before HTMLScriptElement prepares. SVGScriptElement prepares during
   insertion, so SVG nonce hiding stays in that earlier phase. A dynamic-script
   test checks that both script bodies already see an empty content attribute.

Design reference: HTML's [nonce algorithm](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#attr-nonce)
and WebKit's [Element.cpp](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/Element.cpp),
`setNonce`, `hideNonceSlow`, and `cloneAttributesFromElement`. The design was
adapted to Crane's ownership and hook contracts; no WebKit code was copied.

**Takeaway**: **The content attribute is not the authorization value; audit every nonce consumer when moving the value into a private slot.**
