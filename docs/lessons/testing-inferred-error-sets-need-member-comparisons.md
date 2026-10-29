# Testing: Inferred error sets need member comparisons

**Date**: 2026-10-28
**Lesson**: Test the members of an inferred error set when an interface promises only OutOfMemory; raw type identity does not prove that contract.

**Why**: An inferred error-set type can differ from an explicit error-set type even when both contain the same errors. Successful inputs and allocation-failure tests also do not establish the complete error set.

**What Happened**: FetchLater's policy tests passed, but the full native graph could not compile its OOM-only caller: parser and origin-serialization calls exposed broader error sets. The approved repair returned explicit OutOfMemory values and handled a proven impossible IPv4 bounds error. A new test compared the inferred error-set type directly with `error{OutOfMemory}` and failed both before and after the repair. That apparent semantic RED was invalid and was withdrawn (codex-fetchlater Q54/Q55).

**Fix**: Inspect `@typeInfo(E).error_set`, reject null (anyerror), and compare its members with the exact one-element `std.builtin.Type.Error` array named OutOfMemory. Keep the actual caller contract unchanged. The corrected test passed all 26 cases, including both extreme IPv4 addresses through attribute and header policy paths and every allocation failure. The earlier full-native compile errors remain the pre-repair evidence; the false type-identity result does not.

**Takeaway**: **Compare the contract's members, and correct an invalid RED openly rather than changing product code to satisfy a mistaken test.** See Zig's [inferred error sets](https://ziglang.org/documentation/0.16.0/#Inferred-Error-Sets).
