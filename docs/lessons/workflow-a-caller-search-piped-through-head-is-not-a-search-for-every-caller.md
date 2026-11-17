# Workflow: A caller search piped through `head` is not a search for every caller

**Date**: 2026-11-17
**Lesson**: Before removing a function, count its callers with an unbounded search (`grep -rn ... | wc -l`, then read every line) - a `| head` on the same command shows the first screen and silently drops the rest.

**Why**: A truncated list looks exactly like a complete one: no marker says lines were cut. The search that decides "no caller is left" must be the one whose output was read to its end.

**What Happened**: Lane gcp1 removed `v8_GetGlobalPrototype` and `v8_FunctionTemplate_GetPrototypeObject` from the V8 adapter once the wrap path stopped calling them. The search for callers ran `grep -rn ... src tests tools | grep -v v8_wrapper.cpp | head`; its ten lines were all the ffi declarations, the wrap path's comments and one test comment, and the functions were declared dead. The eleventh line - `tests/v8/wr8_young_generation_test.zig:246`, a real call - was cut. The consoles built (they compile no tests), the lane's own test file built alone, and the first whole `tests/v8` build stopped with "root source file struct 'ffi' has no member named 'v8_GetGlobalPrototype'", one job and twenty minutes later.

**Fix**:
1. For a removal, search without a limit and count first: `grep -rn 'name(' src tests tools build.zig | wc -l`; read every line when the count is small, narrow the pattern when it is not - never cap it.
2. Build every directory the removed symbol could reach (`zig build test -Dspec=v8` for an ffi symbol) before calling the removal done, not only the changed test file.

**Takeaway**: **`| head` answers "what are some callers", never "are there callers left": count before you delete.**
