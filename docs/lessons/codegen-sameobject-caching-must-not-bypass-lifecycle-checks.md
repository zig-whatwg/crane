# Codegen: SameObject caching must not bypass lifecycle checks

**Date**: 2026-10-16
**Lesson**: A generated SameObject fast path can skip the getter's required lifecycle checks.

**Why**: Location.ancestorOrigins returns the active document's list, but a
different, stable empty list after the relevant document becomes null. Keeping
the same object within each state does not make the first value valid forever.

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

**Takeaway**: **SameObject caching must preserve the getter's state transitions and checks.**
