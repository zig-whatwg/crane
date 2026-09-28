# Architecture: A function-pointer table hides dead code

**Date**: 2026-09-28
**Lesson**: When the V8 table's literal was deleted, about 45 functions in engine.zig turned out to have no other reference: the table's entry was the only thing that named them, and no caller reached them through it.

**Why**: A struct of function pointers counts as a use of every function it lists. Zig compiles it, grep finds the name, and a reviewer sees a wired-up operation. Whether any code calls the entry is a separate question, and the table's type does not answer it: callers reach an entry as `engine.op.?(...)`, a field access that greps for the operation name only inside the one file that uses it. So an operation whose last caller moved to the protocol (runClassicScript, createStringArray, the script and module compile/run/dispose family, freeze and thaw, forEach) kept its whole implementation alive, along with tests that checked the entry was non-null.

**What Happened**: Once the literal was gone, a per-function count of references (excluding the literal and the definition) found no caller for the table-only implementations. Their only tests were tests of the table. The EngineBinding table next to it (engine_binding.zig, engines/v8/binding.zig) had no caller at all, and its tests only checked that its stub returned errors.

**Fix**: delete the literal first, then count each function's remaining references and delete the ones at zero, repeating for helpers left without callers. Keep the tests that exercise an implementation still used through the protocol, calling it directly, and delete the tests of implementations that went.

**Takeaway**: **An entry in a dispatch table is not a caller. To know what runs, count the calls of the table's fields, not the references to its functions.**
