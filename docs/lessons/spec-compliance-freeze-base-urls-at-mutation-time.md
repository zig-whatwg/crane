# Spec Compliance: Freeze base URLs at mutation time

**Date**: 2026-10-18

**Lesson**: A relative base element keeps a URL resolved at a base mutation; resolving it each time `Node.baseURI` is read makes history changes alter it incorrectly.

**Why**: HTML's document base URL selects a *frozen* URL. The base element's own `href` getter instead parses its attribute against the current fallback. Those two values can differ after `history.pushState`.

**What Happened**: Crane found the first base correctly but parsed its href on every read. The history regression tests returned `changed/child/` after a history update where the existing base had frozen `original/child/`. Ordinary first-base selection and removal tests passed, so they alone did not expose the missing state.

**Fix**: Store one owned URL serialization on the document, update it through the base element's existing insertion, removal and attribute-change hooks, and copy it for `Node.baseURI`. Do the brand check before any tree walk. Removal callbacks receive the removed subtree's old parent, including callbacks for shadow descendants; exclude a base still rooted in a shadow root. Free the stored bytes in the document's existing teardown. Parse with the document's character encoding: the native windows-1252 query case expected `%E9`, while the former UTF-8-only path returned `%C3%A9`.

Browser-source decisions, explicitly approved under golden rule 2:

- Blink `Document::ProcessBaseElement` and WebKit `Document::processBaseElement` recompute on every connected base insertion/removal and href or target change. Gecko also recomputes on removal, but restricts insertion/href and handles target separately. The majority avoids a separate first-base identity cache.
- WebKit clears the stored base for invalid, forbidden or CSP-blocked URLs; Gecko passes null to `SetBaseURI`. Their fallback consequently stays live. The spec's frozen-fallback wording predates the 2023 scheme-ban change (`whatwg/html` f44b31b621); all three engines implement the newer data/javascript ban. This is a majority decision about the older fallback rule.
- These history and mutation details are source-derived evidence, so their regression pins are native tests. Crane WPT fixtures retain assertions supported by actual upstream WPT browser results.

**Measure the work at both ends**: Seven alternating paired runs put 1,000 base insert/change/remove iterations at 6.4 -> 20.8 ms, because mutation now performs the freezing that the old getter deferred. The same change made baseURI reads 94.67% faster and the parser page 36.16% faster; ordinary append/remove stayed within the 3% bar (+2.16%). Keep the mutation cost visible alongside the reader improvements.

**Pin the trigger without production instrumentation**: With a valid first base connected, a test allocator can recognize the current frozen-URL buffer through the document hook and count its replacement. Each completed recomputation copies before freeing that buffer. This pins one update for a later base's insertion/removal and href/target changes, and zero for ordinary nodes or unrelated attributes. Wrap the leak-checking allocator and disable observation before teardown. The observer does not count no-href attempts that allocate nothing; the immediate return at the first href is also a separate code proof.

Sources: [HTML document base URLs](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#document-base-url), [HTML base](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element), [Blink](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/document.cc), [WebKit](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/Document.cpp), [Gecko](https://github.com/mozilla-firefox/firefox/blob/main/dom/html/HTMLSharedElement.cpp).

**Takeaway**: **When a getter looks correct until another property changes, check whether the specification requires stored state rather than a fresh calculation.**
