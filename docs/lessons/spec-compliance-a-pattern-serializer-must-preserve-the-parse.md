# Spec Compliance: A pattern serializer must preserve the parse

**Date**: 2026-10-12
**Lesson**: Serializing a URLPattern part list requires the surrounding parts as well as the current part.

**Why**: Pattern syntax is contextual. An asterisk after a group can become its modifier, a suffix can extend a name, and a preceding slash can become an automatic prefix. Dropping braces changes the pattern's meaning.

**What Happened**: The serializer concatenated prefixes, names, values, suffixes and modifiers. On BASE 3983369b29a, 12 of 13 isolated serialization cases failed: `{foo}?` lost its braces, `{:foo}(.*)` became `:foo*`, and an escaped literal plus became syntax. Unicode names were also tokenized byte by byte, so a suffix of the name became fixed text and was percent-encoded.

**Fix**: Implement the complete URLPattern §2.3 grouping algorithm, including previous/next-part checks and pattern-specific escaping. Tokenize Unicode scalar values while retaining byte offsets for slices. Native regressions parse the serialized string again and compare generated regexps; script-level regressions check the exposed canonical properties.

**Takeaway**: **For syntax with context-sensitive boundaries, verify that serialization preserves the parse, not just that the output looks plausible.**
