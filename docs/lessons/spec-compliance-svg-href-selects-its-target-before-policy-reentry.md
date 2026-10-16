# Spec Compliance: SVG href selects its target before policy reentry

**Date**: 2026-10-14
**Lesson**: A Trusted Types default policy can mutate the reflected element; preserve the backing attribute selected by the browsers before calling that policy.

**Why**: SVG 2 section 4.6.7 lists the Trusted Types check before selecting href or its deprecated xlink:href alternative. That order is observable when the policy adds or removes href. Ordinary writes cannot distinguish the two orders.

**What Happened**: While implementing SVGURIReference.href and SVGAnimatedString, the initial design followed the specification's step order. Reading the engines before implementing reentry showed that Blink's `SVGAnimatedHref::setBaseVal` calls `BackingString()` first. Gecko's `SVGScriptElement::Href` similarly selects a string tearoff before `SVGAnimatedScriptHrefString::SetBaseValue` calls the policy. Both therefore write the attribute selected before the callback, even when its presence changes during the callback. Crane follows that browser majority.

**Fix**: Choose only the namespace before the policy runs. Keep the element with the existing `dom.node_holds.MemberHold`, and keep reflected names in owned storage. Call `dom.trusted_types.getCompliantAttributeValue` once, then use `dom.element_attributes.set` to write the compliant value. Do not hold a borrowed attribute pointer across the callback or call the IDL setter and run the policy again. The `tt2-svg-href-enforcement.html` regression covers both an added href and a removed href; `tt2-svg-href-gc.html` covers the holder in both directions.

Evidence:

- [SVG 2 SVGAnimatedString](https://svgwg.org/svg2-draft/types.html#InterfaceSVGAnimatedString), cached in `specs/w3c/svg2/types.md`.
- [Blink SVGAnimatedHref](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/svg/svg_animated_href.cc), `setBaseVal` and `BackingString`.
- [Gecko SVGScriptElement](https://raw.githubusercontent.com/mozilla-firefox/firefox/main/dom/svg/SVGScriptElement.cpp), `Href`.
- [Gecko SVGAnimatedString](https://raw.githubusercontent.com/mozilla-firefox/firefox/main/dom/svg/SVGAnimatedString.cpp), `SVGAnimatedScriptHrefString::SetBaseValue`.
- [Blink's retained context element](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/core/svg/properties/svg_animated_property.h), `context_element_` and `Trace` (design reference; no code copied).

**Takeaway**: **Read the callers around a policy callback: the browsers may already have selected the object or attribute that the callback's result will update.**
