# Spec Compliance: Form named lookup and own-key enumeration differ

**Date**: 2026-10-12
**Lesson**: A form's supported names are needed for named lookup even though browsers omit them from own-key enumeration.

**Why**: `[LegacyUnenumerableNamedProperties]` makes named properties non-enumerable, which excludes them from `Object.keys`. It does not by itself hide them from `Object.getOwnPropertyNames` or `Reflect.ownKeys`.

**What Happened**: Implementing HTML's supported-name algorithm exposed a binding dependency. WebKit's `HTMLFormElement::supportedPropertyNames` and Gecko's `GetSupportedNames` return no names; Blink supplies a named query without a named enumerator. All retain named lookup. Crane's adapter used one supported-name function for both lookup and own-key enumeration, so returning an empty list would disable the getter.

**Fix**: The integrator's codex-lpo Q7 ruling keeps the full current-name list in the impl and routes the adapter split separately. Main 9cac517954 supplies bindlpo's generated `Meta.named_properties_in_own_keys = false` for HTMLFormElement, separating enumeration from lookup. A native test checks name order, deduplication and allocation failure cleanup; the Crane enumeration regression follows the browsers.

**Takeaway**: **Check lookup, descriptors, enumerable keys and all own keys separately; one enumeration flag does not establish all four behaviors.**

Sources: [HTML issue 1731](https://github.com/whatwg/html/issues/1731), [WebKit](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLFormElement.cpp), [Gecko](https://github.com/mozilla/gecko-dev/blob/master/dom/html/HTMLFormElement.cpp), [Blink](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/forms/html_form_element.cc).
