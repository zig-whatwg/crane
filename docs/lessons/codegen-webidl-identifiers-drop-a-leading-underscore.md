# Codegen: WebIDL identifiers drop a leading underscore

**Date**: 2026-09-24
**Lesson**: `_any` in IDL names a member `any`. The lexer kept the underscore, so script saw `AbortSignal._any`, and dictionaries read `_or` and `_namespace` from script objects, which never have them. Pinned by `tests/codegen/escaped_identifier_test.zig`.

**Takeaway**: **Grep the generated tables for names starting with `_` after any parser change.** Each one is a member script cannot reach under its real name.
