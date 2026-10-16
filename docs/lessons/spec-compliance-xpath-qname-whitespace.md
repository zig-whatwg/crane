# Spec Compliance: XPath QNames accept browser whitespace

**Date**: 2026-10-14
**Lesson**: Browser XPath lexers permit XML whitespace around a QName colon and resolve its normalized prefix.

**Why**: XPath §3.7 describes whitespace between tokens. Treating a QName as one uninterrupted token rejects expressions such as `p : child` that Blink and WebKit accept.

**What Happened**: Review of both browsers' `nextTokenInternal` implementations showed whitespace skipping after the first NCName and after a single colon. The isolated `xp2-qname-whitespace` test failed with SyntaxError before the correction. Both engines still require the two colons in an axis separator to be adjacent.

**Fix**: Retain the first NCName's end before skipping whitespace. For a qualified name, combine the prefix and local name without the surrounding whitespace in the existing compile arena. Ordinary names and uninterrupted QNames keep their source slices. Native tests also reject incomplete and split colons and distinguish valid unresolved prefixes from syntax errors.

Sources: [WebKit XPathParser.cpp](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/xml/XPathParser.cpp), [Blink xpath_parser.cc](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/xml/xpath_parser.cc), XPath 1.0 §3.7 production [37].

**Takeaway**: **Check browser token boundaries as well as the grammar, and keep whitespace out of namespace resolver arguments.**
