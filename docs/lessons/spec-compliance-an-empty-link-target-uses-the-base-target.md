# Spec Compliance: An empty link target uses the base target

**Date**: 2026-10-18

**Lesson**: Browser hyperlink activation treats an empty target attribute like an absent target when choosing the document's base target.

**Why**: HTML's “get an element's target” step 1.1 tests attribute presence. The browser implementations instead test the attribute's string value for emptiness. An empty string therefore exposes a difference that ordinary absent and named targets do not.

**What Happened**: `base_multiple.html` failed by navigating its source frame. Its first base element had the correct href and target, but the anchor had `target=""`. Crane resolved the URL correctly and then treated the empty target as an explicit self navigation. All three browsers passed this upstream test. The isolated a/area matrix passed six cases on BASE; only the two empty-target cases failed.

**Fix**: In hyperlink activation, use a nonempty explicit target, otherwise read the first base element with a target. Keep the subsequent dangling-markup check and navigation algorithms unchanged. This is a documented browser-majority deviation from step 1.1, with no newer specification change involved. Form submission has its own target-selection path and is outside this fix.

Evidence read before implementation:

- [HTML target algorithm](https://html.spec.whatwg.org/multipage/semantics.html#get-an-element's-target).
- [WPT base_multiple](https://wpt.fyi/results/html/semantics/document-metadata/the-base-element/base_multiple.html): Chrome 155, Firefox 158 and Safari 27 each 1/1 at WPT revision `23b0b89b1a`.
- [Blink HTMLAnchorElementBase::GetEffectiveTarget](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/html_anchor_element.cc).
- [WebKit HTMLAnchorElement::effectiveTarget](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLAnchorElement.cpp).
- [Gecko HTMLAnchorElement::GetLinkTargetImpl](https://github.com/mozilla-firefox/firefox/blob/main/dom/html/HTMLAnchorElement.cpp).

**Takeaway**: **A failure named for a base element can be target selection rather than URL resolution; isolate both outputs before changing either algorithm.**
