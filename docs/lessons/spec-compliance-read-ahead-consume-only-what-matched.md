# Spec Compliance: Read ahead, consume only what matched

**Date**: 2026-09-27
**Lesson**: "Consume the maximum number of characters possible, where the consumed characters are one of the identifiers in the named character references table" means look ahead, consume exactly the match, and leave the rest for the state that reads next.

**Why**: The named character reference state matches the longest table entry that is a prefix of the input. Characters after the match belong to whatever state comes next; only the matched name is consumed.

**What Happened**: Crane consumed the whole run of name characters, then restored what an attribute value needed and nothing else. In text, everything past the match was lost: "x &c y" read "x & y", "AT&T" read "AT&", "&notit;" read "¬" instead of "¬it;", and two-code-point references lost their second code point. WPT's named-character-references (2138 -> 2231 of 2231 subtests) and html5lib_entities01 (14 -> 150) measured it.

**Fix**: f66f0b49b looks ahead for the longest match, consumes exactly it, and returns both code points of a two-code-point reference.

**Takeaway**: **Match by looking ahead, not by consuming and restoring; restoring for one caller loses text for every other.**
