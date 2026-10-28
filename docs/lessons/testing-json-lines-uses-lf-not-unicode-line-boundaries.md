# Testing: JSON Lines uses LF, not Unicode line boundaries

**Date**: 2026-10-28
**Lesson**: Read JSON Lines by ASCII LF. Unicode line separators inside JSON strings are data.

**Why**: A Unicode-aware line splitter can cut a valid JSON record in the middle of a test name. It makes intact measurement evidence look truncated or corrupt.

**What Happened**: The focus lane's baseline held 5,239 WPT result records. Some encoding test names contained literal U+0085, U+2028 and U+2029. Python `str.splitlines()` split those strings before `json.loads()` could read them, producing an unterminated-string error. All records were valid when read by LF, and their 541,101 PASS names reconciled with the journal counts.

**Fix**: Iterate the text file or split explicitly on `"\n"`, skip empty records, and parse each complete JSON object. Preserve the raw evidence. Check duplicate URL/name keys and reconcile parsed subtest counts with the per-file journal before accepting the comparison.

**Takeaway**: **A record delimiter is a format rule.** Do not substitute a language's broader definition of a line boundary.
