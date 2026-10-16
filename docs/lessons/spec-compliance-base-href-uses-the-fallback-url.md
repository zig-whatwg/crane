# Spec Compliance: Base href uses the fallback URL

**Date**: 2026-10-13
**Lesson**: The base element's href getter resolves against the document's fallback URL, independently of its effective base URL.

**Why**: HTML's base href algorithm explicitly ignores other base elements and the element itself. Generic URL reflection resolves through the effective document base URL and therefore implements a different algorithm. The getter also returns data and javascript URLs even though those schemes cannot become the document's frozen base URL.

**What Happened**: HTMLBaseElement's generated setter reflected the attribute, while its getter still returned NotImplemented. Tests covering another base, missing attributes, invalid URLs, document encoding and inherited about:blank fallback URLs exposed the gap.

**Fix**: Reuse the URL parser and the existing document fallback hook, supplying the document's encoding. Preserve the original scalar value string when parsing fails. Keep frozen-base maintenance separate: its mutation-time state and CSP checks belong to a different algorithm and need their owning files.

Sources: [HTML base element](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element) and [WebKit HTMLBaseElement::href](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLBaseElement.cpp).

**Takeaway**: **A URL-valued property is not necessarily generic URL reflection; read its complete getter and mutation algorithms.**
