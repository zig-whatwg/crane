# Workflow: Zig 0.17 rejects a parameter named like a declaration of its container, and has no `**`

**Date**: 2026-11-21
**Lesson**: Under Zig 0.17 a function parameter may not share a name with any declaration of the enclosing container - a method's name included - and array repetition (`[_]u8{0} ** n`) is gone; write `@splat` and name parameters apart from the type's methods.

**Why**: Zig 0.17 extends its shadowing check to container-level declarations: `fn set(self: *Failure, code: Code, message: []const u8)` in a struct that also declares `pub fn message(self)` is "function parameter shadows declaration of 'message'", and so is `fn of(high: u64, low: u64)` beside `pub fn high(self)`. The `**` operator was removed; `zig fmt` then reports the leftover `*` as "binary operator '*' has whitespace on one side, but not the other". `zig fmt` also rewrites the deprecated `@intFromEnum` to `@backingInt` in place, so a script that edits by exact text written before the format no longer finds its anchor.

**What Happened**: Lane cdpt (CDP transport) wrote src/devtools on the Mac, where lanes compile nothing; the first pool compile check failed on three such shadowings (dispatch.zig `Failure.set`, ids.zig `Token.of`, fetch_observer.zig `Head.of` beside `Head.response`), and a test block's `[_]u8{'p'} ** 126` failed `zig fmt --check` on cdp/main because check-devtools never compiled that test. A Python edit script whose anchor still said `@intFromEnum` silently replaced nothing after `zig fmt` had rewritten the file.

**Fix**: Rename the parameter (`text`, `high_half`, `toResponse` for the method); `const long: [126]u8 = @splat('p');`; `var next: [n]usize = @splat(0);`. Every scripted edit asserts its anchor is present before it writes.

**Takeaway**: **Before a pool compile, grep your new Zig for `** ` and for parameters named like a method of their own type, and make every scripted edit assert its anchor - `zig fmt` rewrites deprecated builtins under it.**
