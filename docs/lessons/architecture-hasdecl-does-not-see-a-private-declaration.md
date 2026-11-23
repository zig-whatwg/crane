# Architecture: @hasDecl does not see a private declaration - an optional hook a type declares must be `pub`

**Date**: 2026-11-22
**Lesson**: Under the pinned Zig 0.17, `@hasDecl(T, "drop")` is false when `T`'s `drop` is not `pub`, even in the same file: a generic that calls an optional member only `if (@hasDecl(T, ...))` silently skips every private one.

**Why**: Zig's `@hasDecl` answers for the declarations visible to the code that asks. A private `fn drop` inside `const ClosedTask = struct { ... }` is not visible to a generic `postTask(comptime T: type, ...)` that inspects it, so `comptime @hasDecl(T, "drop")` is false and the branch is compiled out - no error, no warning. Probed on chat2 with `~/crane-bin/zig` (0.17.1-dev+77c319a0f0): a struct with a private `fn drop` -> false, with `pub fn drop` -> true, both in one file.

**What Happened**: The devtools Server posts tasks to its inbox through `postTask(T, value)`, whose generic wrapper calls `value.drop(allocator)` when the inbox refuses or discards a task - `if (comptime @hasDecl(T, "drop"))`. Every task type (AddConnection, HttpTask, MessageTask, ClosedTask, TargetEventTask) declared `fn drop`, private. So a dropped task never released what it held: a reader's ClosedTask, posted after the devtools thread's last batch and dropped by the inbox's close at Server.stop, kept its Connection (and the Connection's Outbound and queue). Every tests/devtools replay test ended with the DebugAllocator reporting those three blocks leaked; some runs passed when the ClosedTask happened to run before StopTask. A refcount trace (scratch prints on retain/release and at each teardown step) showed the ClosedTask neither ran nor dropped, while its Task wrapper was freed - the wrapper's destroy ran, its value's drop did not.

**Fix**: Make every hook a generic looks for with `@hasDecl` `pub` (here `pub fn drop` on the five task types), and say in the generic's doc comment that it must be. Where a missing hook is a bug rather than an option, require it (`@compileError` when `!@hasDecl`) instead of skipping it.

**Takeaway**: **Never let a generic skip an optional member silently: `@hasDecl` cannot see a private declaration, so declare such hooks `pub` - and when a leak's owner "can't" be missing a release, check that the release is compiled in at all.**
