# Workflow: Only a var inside a test declaration leaves the global-state count

**Date**: 2026-11-02
**Lesson**: lint-global-state exempts a container-level `var` only when its declaration lies inside a `test "..." { }` block; a test helper's `var` anywhere else - behind `if (builtin.is_test)`, in a struct a helper function returns, in a function's `struct { var ... }` static - is still counted, under the file's key.

**Why**: The lint reads the source with `std.zig.Ast` (tools/lint_global_state.zig `zigVariables`): it collects every container's `var` members and skips one only when its first token falls inside a `.test_decl` node's token range. It does not evaluate comptime conditions, so `builtin.is_test` means nothing to it, and a helper outside a test block is product source as far as it can see. (A zero-argument function returning a struct type is also memoized by Zig: every call returns the SAME type, so its `var` is one shared variable, not one per test.)

**What Happened**: Lane gstate2 moved the 16 test-instrumentation (`X`) globals out of product files. The inventory's rule reads "into the test block, or behind `builtin.is_test`", and the first draft for src/dom/activation.zig made a `fn TestBehavior() type { return struct { var runs ... } }` helper shared by two tests. It would have kept the count (`TestBehavior.runs`) and shared the counter between both tests. Reading the lint's scanner before building caught it.

**Fix**: Each test declares what it records in its own body - `const Test = struct { var runs: usize = 0; fn run(...) void { runs += 1; } };` - or, when the callback takes a context, passes a record of its own (`addListener(TestListener.callback, &seen, ...)`), which needs no `var` at all. A counter that a test in ANOTHER file must read (the stub platform backend's handle counters, native_timer's) cannot move into a test block: it becomes a field of the object it counts for.

**Takeaway**: **To take a test variable out of the global-state count, declare it inside the `test` block that uses it (or pass the test's record as the callback's context) - `builtin.is_test` and shared helpers do not lower the count.**
