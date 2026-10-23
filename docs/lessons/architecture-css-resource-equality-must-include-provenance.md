# Architecture: CSS Resource Equality Includes Its Source

**Date**: 2026-10-22
**Lesson**: Identical serialized CSS URLs can require different requests, so value reuse must compare their retained provenance too.

**Why**: A stylesheet contributes a base URL, referrer, referrer policy and origin-clean state. Resolving a URL to an absolute string does not encode those facts. A fragment-only URL also has a local-reference flag which cannot be reconstructed by comparing absolute URLs.

**What Happened**: Crane kept image values in counted serialized strings. CSSOM's set-declaration optimization compared only those strings. Adding source records without changing that optimization would discard a replacement declaration's source whenever its text equaled the old declaration, retaining the old request policy.

**Fix**: Keep an owned, refcounted source record and ordered URL occurrences with the value. Preserve the metadata through shorthand joins, computed-value copies and content substitution. Keep textual equality for serialization comparisons, and include resource equality when deciding whether an existing declaration can be reused. Test two declarations with the same absolute URL and different policies, then release the original declaration and source owner before inspecting the retained value.

Gecko's [URLExtraData](https://github.com/mozilla/gecko-dev/blob/master/layout/style/URLExtraData.h) and Blink's [CSSUrlData](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/css_url_data.h) demonstrate the separation of URL spelling, resolution and source metadata. Crane's source record owns only plain CSS data, with no reference back to a document, realm or sheet.

**Takeaway**: **A string is a serialization, not a resource identity. Preserve the source at parsing time; never rediscover it by scanning stylesheets later.**
