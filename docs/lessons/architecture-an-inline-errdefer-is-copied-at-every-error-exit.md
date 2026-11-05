# Architecture: An `errdefer inline for` is copied at every error exit - quadratic code in a generic

**Date**: 2026-11-04
**Lesson**: Zig emits a `defer`/`errdefer` body at every exit it covers. An `errdefer inline for` over n members, armed before a loop whose n iterations each have several `try`s, is emitted n x exits times - quadratic machine code per instance, which LLVM Emit Object then pays.

**Why**: Every `try` is an exit, and each exit runs - so carries a copy of - every errdefer in scope. An unrolled loop is n statements, so the copies multiply. Nothing in the source looks quadratic: it reads as one cleanup.

**What Happened**: Lane compiletime1's code-size report (tools/code_size_report.zig) of tests-dom found conversions.convertValueAs at 7.2 MB over 2,154 instances, half of it in 72 instances of 16 KB or more; the largest, MediaTrackConstraintSet's dictionary conversion, was 878 KB of machine code for one function (found by its locals with `dwarfdump --name=... --show-children` on the object the binary's debug map names). The dictionary path freed the members converted so far with `errdefer inline for (members, 0..) |field, index| { if (index < converted) free(...) }`, armed before `inline for (members)` whose member conversions each have several `try`s: ~40 members x their exits x 40 frees.

**Fix**: The cleanup is a function of its own, generic per dictionary type (`freeConvertedMembers(T, allocator, &result, converted)`), and the errdefer calls it: the same frees, in the same order, on the same paths, and each exit carries one call.

**Takeaway**: **Never `errdefer`/`defer` an `inline for` (or any large unrolled body) in front of code with many exits: call a function from the errdefer. And measure code size by family before guessing where compile time goes.**
