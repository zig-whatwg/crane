# Spec Compliance: Preserve Invalid Tokens Until Their Grammar Decides

**Date**: 2026-10-22
**Lesson**: A generic CSS serializer must preserve malformed tokens so each consuming grammar can apply its own rejection or recovery rules.

**Why**: CSS Syntax excludes bad-string and bad-url from ordinary declaration values, but a forgiving descriptor list can discard one malformed component and retain another. Erasing invalidity invents valid input; dropping the whole declaration too early defeats forgiving recovery.

**What Happened**: Crane's rule serializer turned a bad URL into `url()` and a bad string into a quoted valid string. Both property grammars and the font-src parser then saw valid syntax that the author never wrote. Rejecting the entire declaration in the generic rule parser would instead lose the valid trailing URL in `src: url(not a valid url/bar.ttf), url(foo.ttf)`.

**Fix**: Preserve the raw bad-url span and the bad-string span plus its newline terminator. Ordinary property and custom-property consumers reject those tokens under CSS Syntax 3 section 7.2. CSS Fonts 4 section 4.3.1 keeps its per-component recovery. Test both paths, including nested bad tokens and the separate case of a syntactically valid empty URL.

**Takeaway**: **Serialization must not sanitize an invalid token into a valid one. Keep the evidence until the consuming grammar decides what to discard.**
