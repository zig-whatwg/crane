# Spec Compliance: XPath browser strings use UTF-16 units

**Date**: 2026-10-14
**Lesson**: Browser XPath string operations use UTF-16 code units even though XPath 1.0 describes Unicode characters.

**Why**: Crane stores DOM strings as WTF-8. Neither counting UTF-8 sequences nor searching their bytes reproduces a browser's operations on surrogate pairs: a search can match just one half of a pair, and substring can return that half.

**What Happened**: The first XPath string tests expected `string-length("a😀b")` to be three. Review of Blink's `xpath_functions.cc` and WebKit's `XPathFunctions.cpp` showed both count four UTF-16 units, index substring and translate in those units, and search their UTF-16 strings. An isolated browser-compatibility fixture failed before the correction.

**Fix**: Use `infra.wtf8.codeUnitLength` for length, the standard library's WTF-8/WTF-16 conversions for unit-based operations, and `infra.wtf8.appendJoined` for concatenation. Joining a high surrogate and a low surrogate must restore canonical WTF-8 so subsequent byte equality remains string equality. Preserve lone surrogates in results. The `xp2-string-units` fixture and native allocation-failure tests cover these paths.

Sources: [WebKit XPathFunctions.cpp](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/xml/XPathFunctions.cpp), [Blink xpath_functions.cc](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/xml/xpath_functions.cc), XPath 1.0 §§3.6 and 4.2.

**Takeaway**: **Choose string units from browser behavior, and preserve WTF-8's surrogate-seam invariant when assembling strings.**
