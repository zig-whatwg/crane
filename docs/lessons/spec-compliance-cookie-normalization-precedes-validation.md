# Spec Compliance: Cookie normalization precedes validation

**Date**: 2026-10-13
**Lesson**: Normalize Cookie Store names and values before validating or matching them, and preserve the difference between an empty name and an omitted filter.

**Why**: Whitespace changes which validation branch applies. A space-only name becomes the empty name, and a prefixed name hidden behind a tab still has a reserved prefix. Query normalization must not turn that empty string into the null wildcard.

**What Happened**: Crane's normalization helper was an identity function. Eight new native cases failed across set, query, delete and prefix validation. A second obsolete helper mapped `get('')` to every cookie, although generated dictionary overloads had since made omitted arguments distinguishable. Upstream nameless-prefix tests then returned an unrelated cookie after correctly rejecting a set.

**Fix**:

1. Trim only edge U+0009 TAB and U+0020 SPACE with a borrowed slice. Keep interior whitespace and forbidden controls so validation can inspect them.
2. Keep a supplied string, including the empty string, as an exact filter. Use null only for an omitted dictionary name.
3. Test normalization through set, query and delete, and test empty versus missing filters with unrelated cookies already stored.
4. Revisit workaround tests when the binding capability they assumed is replaced. Use the generated interface's current overload metadata as evidence.

Evidence: [Cookie Store normalization](https://cookiestore.spec.whatwg.org/#normalize-a-cookie-name-or-value), [query cookies](https://cookiestore.spec.whatwg.org/#query-cookies), Blink's [StripHttpWhitespace and ToBackendOptions](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/modules/cookie_store/cookie_store.cc), and WebKit's [CookieStore normalization](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/cookie-store/CookieStore.cpp). Aligned stable WPT revision cc74d2669f: all three browsers pass whitespace assertions; Chrome and Firefox pass every special-name assertion.

**Takeaway**: **Normalization is part of the algorithm's ordering, and an empty value is not an absent value.**
