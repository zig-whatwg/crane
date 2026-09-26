# Spec Compliance: Infra's ASCII whitespace is not `std.ascii.isWhitespace`

**Date**: 2026-09-26
**Lesson**: Infra's ASCII whitespace is TAB, LF, FF, CR and SPACE; Zig's `std.ascii.isWhitespace` also accepts VT (U+000B).

**Why**: The rules for parsing integers and every other HTML microsyntax skip ASCII whitespace as Infra defines it.

**What Happened**: With `std.ascii.isWhitespace`, `"\u000B7"` parsed as 7 where the spec gives an error (lane/reflection's integer reflection). About 20 other uses in `src/` are worth auditing.

**Fix**: A helper for Infra's set, used by the reflection parsers.

**Takeaway**: **Use Infra's whitespace set for web microsyntaxes; the standard library's includes VT.**
