# Testing: A leave-one-out console that moves no symbol is the base again - compare `nm -n` before reading its window

**Date**: 2026-11-23
**Lesson**: Before a leave-one-out window "narrows" a cost row to one commit, prove that the console with that commit removed differs from the base in the binary: same section sizes and no symbol at another address means it IS the base, and its window is base against base on one layout.

**Why**: A commit whose only output is comptime data that nothing reads (a generated table, a declaration, a type) leaves no trace in a ReleaseSafe executable. Removing the commit that reads it removes both. The console named "the tree minus commit B" then carries neither A nor B, whatever its BUILD_INFO says, and "the row is clean without B, so B carries the cost" only says "the build whose layout moved carries it" - which every layout effect also says (lesson testing-a-memory-level-shift-between-builds-is-not-a-cost-until-base-against-base-says-so.md).

**What Happened**: Lane bind1's batch B3 was two commits: codegen's union arms tables (1ccad4f86, `pub const arms` on 95 typedefs) and the binding's union conversion that reads them (62ebb2e30). Its cost window read page.fetch steady 1.038 in the ring-off memory pass. A console of "main + the tables only" (the binding commit reversed) read 1.002-1.017 against the base, and the row was reported as narrowed to the binding commit; an agent then looked for what that commit's conversion path retains, and escalated when live handle counts came out identical. The takeover's first check took a minute: `size -m` gave the tables-only console the base's section sizes to the byte, and `nm -n` with the `__anon_NNN` names folded showed 0 of 187,538 symbols at another address (67,192 lines differed only in those numbers). The tables are comptime-only; without their reader the linker has nothing to keep.

**Fix**:
1. For every leave-one-out console, before its window: `size -m <console>/repl` beside the base's, and `nm -n` of both with compiler-numbered names folded (`sed -E 's/___anon_[0-9]+/___anon/'`), diffed. Zero moved symbols: the console is the base's layout and code; do not spend a window on it, and do not cite it.
2. A leave-one-out is of something that reaches the binary. When a batch is "data + its reader", the removable unit is the pair.
3. When no partial removal changes the binary, attribute by what the process does instead: live blocks at the mark (`heap`), allocation calls by size and their order (a `DYLD_INSERT_LIBRARIES` interposer over the frozen consoles), footprint by category (`footprint -w`). See debugging-footprint-levels-that-vanish-with-one-malloc-magazine-are-placement-not-held-memory.md.

**Takeaway**: **"Removed" is a claim about the binary: check that a leave-one-out console moved at least one symbol before its window is allowed to narrow anything.**
