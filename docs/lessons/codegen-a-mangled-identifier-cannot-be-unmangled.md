# Codegen: A mangled identifier cannot be unmangled

**Date**: 2026-10-04
**Lesson**: Generated enums name each value by replacing every character an identifier cannot hold with `_` (`"same-origin"` is `_same_origin_`, `"back_forward"` is `_back_forward_`), and the binding recovered the value from the name by turning `_` into `-`.

**Why**: The mangling is many-to-one: `-`, `_`, `/`, `+` and `.` all become `_`. Its inverse guesses. Two binding paths guessed differently (enumToV8String made every `_` a `-`; toV8Value's enum branch kept them), and input matched any of `-`, `_`, `/` for each `_`.

**What Happened**: PerformanceNavigationTiming.type read "back-forward" (three navigation-timing files fail on it), a dictionary-returned "non-blocking" read "non_blocking", and `new Request(url, {mode: "same_origin"})` was accepted.

**Fix**: generator.writeEnum emits `idl_values`, variant i's exact IDL string at index i, and conversions.idlEnumValue / enumFromIdlValue use it in both directions (exact, case-sensitive comparison, WebIDL 3.2.23). The variant names are unchanged, so no impl changed. tests/codegen/enum_value_table_test.zig, tests/v8/webidl_value_conversion_test.zig, crane/bd2-enum-values-exact.html.

**Takeaway**: **Keep the source string beside a generated identifier; never derive one from the other.**
