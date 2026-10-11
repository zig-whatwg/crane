# Spec Compliance: MIME parameters compare string contents

**Date**: 2026-10-11
**Lesson**: A generic map of string slices does not necessarily implement the specification's string-key equality.

**Why**: Crane's Infra OrderedMap uses generic equality. For UTF-16 slices that compares the slice identity, so separately allocated spellings of the same MIME parameter can become distinct keys.

**What Happened**: MIME parsing lowercased each parameter name into a fresh allocation and tested `parameters.contains(name)`. Duplicate charset parameters survived even though MIME Sniffing requires the first valid occurrence. Two nearby boundary errors treated form feed as HTTP whitespace and discarded a backslash at the end of a quoted value.

**Fix**: Compare parameter names by UTF-16 contents before insertion. Use Fetch's four HTTP whitespace code points, and preserve the terminal backslash as its quoted-string algorithm requires. Validate parsing and serialization directly against both upstream WPT MIME JSON corpora, plus allocation-failure tests; Blob/File constructor behavior is a separate contract. Gecko's [MimeType.cpp](https://github.com/mozilla/gecko-dev/blob/master/dom/base/MimeType.cpp) provides the same content-keyed duplicate check and quoted-value handling.

**Takeaway**: **Check a collection's equality semantics before using it for specification strings, and test the parser separately from its callers.**
