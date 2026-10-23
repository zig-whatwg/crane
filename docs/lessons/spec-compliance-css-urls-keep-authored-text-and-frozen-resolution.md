# Spec Compliance: CSS URLs keep authored text and frozen resolution

**Date**: 2026-10-23
**Lesson**: Preserve authored URL text for specified CSSOM and retain parse-time resolution separately for computed CSS and resource requests.

**Why**: Adding a URL resolver to a parser must not change the specified declaration's text. Replacing that text with an absolute URL breaks CSSOM read-back; resolving again during read-back lets later base changes alter an already-parsed resource. Local fragments and empty URLs have separate serialization rules.

**What Happened**: Supplying resolution context in the resource-loading lane lost four content-valid subtests and url-whitespace-consumption. The stored text became absolute. Native explicit-resolver tests reproduced that mechanism across image, content and cursor paths. A separate audit found computed shorthands bypassed the longhand resolved serializer.

**Fix**: Keep authored text and frozen ResourceUrl metadata. Serialize computed values by replacing the recorded URL spans, including quoted argument spans where modifiers or image-set strings require them. Apply local-fragment and invalid/empty rules once in the shared serializer. Forward computed mode through the background shorthand serializer as well as longhand serialization. Test changes to the base after parsing and release the original owners before reading retained values.

Design reference: Blink's [CSSUrlData::MakeComputed and CssText](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/third_party/blink/renderer/core/css/css_url_data.cc), with no code copied. The normative contracts are CSS Values4 §4.5 and CSSOM's serialize-a-URL algorithm.

**Takeaway**: **URL spelling, resolved resource identity and computed serialization are distinct data contracts. Preserve all three at their owning boundaries.**
