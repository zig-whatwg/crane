# Codegen: SameObject caching must not bypass lifecycle checks

**Date**: 2026-10-16
**Lesson**: A generated SameObject fast path can skip the getter's required lifecycle checks.

**Why**: The cause is IDL drift, not a rule about [SameObject]. Current HTML
has no [SameObject] on Location.ancestorOrigins (webref ed/idl/html.idl:1921;
specs/whatwg/html.md:134929): it returns the active document's list, and a
different, stable empty list once the relevant document is null. Only Crane's
pinned specs/idl/html.idl:1907 (webref 08fb1a31) still carries [SameObject], so
the generated getter caches the first value forever (corrected by the row 45
review, S1).

**What Happened**: While implementing Origin and ancestorOrigins in row 45,
the generated Location getter returned cached_ancestorOrigins before calling
the impl. An impl-only change therefore could not observe iframe removal after
the first read. The upstream location-ancestor-origins-new-object.html test
requires a new empty list after removal and passes in Chrome 154, Firefox 157,
and Safari 27 in the aligned stable 2026-10-06 runs. The same issue affects the
inactive-document tests. Row 45 implements list construction and its traced
edge; the integrator assigned the codegen exemption to binding3, so the
detachment failures remain an explicit integration dependency.

**Fix**:

1. Let the impl own caching for this specific member through codegen, then
   regenerate. Do not edit generated files or write their cache fields from
   the impl.
2. Run the relevant-document and access checks before consulting the impl's
   cache. Keep the active document's list, and a distinct empty list once no
   fully active relevant document remains.
3. Keep the returned list through a traced edge from Location. Preserve any
   old list still held by script; it remains a readable snapshot.
4. Test both first access after detachment and access before and after it,
   including collection while script holds only the Location.

The relevant algorithms are [HTML's ancestorOrigins getter](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-location-ancestororigins).
Existing engine designs can be read in [Blink's Location implementation](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/frame/location.cc)
and [WebKit's Location implementation](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/Location.cpp).

**Takeaway**: **When a generated [SameObject] contradicts a WPT file every browser passes, check the current IDL first: the pinned snapshot can lag the standard (ancestorOrigins lost [SameObject] upstream). The fix is the webref IDL update, not a codegen opt-out.**
