# Debugging: A new caller can outline a function the hot path inlined - read the disassembly

**Date**: 2026-11-11
**Lesson**: A cost row that rises when no new work was added to its path can be inlining. A function the compiler inlined at its one call site may be kept out of line once another caller appears, so the hot path pays a second frame, a stack check and a call. Compare the release binary's disassembly of the hot function, base against tip, before you look for work to remove. Do not answer an outlined function by forcing it inline: the copy gives every function it calls a second caller.

**Why**: LLVM inlines an internal function with one call site almost whatever its size, because the out-of-line copy then disappears. With several call sites that bonus is gone, and a large body stays out of line. The source of the hot path does not change. Only the number of callers does, often in code the hot path never runs. A sampling profile does not show the difference well: the frame cost is spread over prologues, epilogues and stack-protector checks rather than one hot function.

**What Happened**: Lane nd2 batch 3 gave each class value a pre-split token list. Its class reads intern tokens through `Table.intern`, and `Table.find` uses the same adapted hash-map lookup. The cost pair against batch 2 then read setter 1.016 and set/get 1.009, +72 and +69 instructions an op. The plain `el.id = 'x' / 'y'` loop does no class read, and the agent first read the source looking for added work. The sample's largest DOM frame, `mem.eqlBytes`, was batch 2's too.

`objdump --disassemble-symbols` of the two release consoles showed the cause. In batch 2, `attribute_values.intern` had `Table.intern` and `KeyAdapter.eql` inlined. In batch 3 it called `Table.intern`, and each frame had its own stack-protector check: the scope's function still inlined the table's first-use creation, a 1,248-byte frame. `Table.intern` in turn called `eql` for every probed slot.

The first fix, `@call(.always_inline, Table.intern, ...)` at the scope's call site, made it worse in a new way. Zig copied the body, so `getKeyAdapted`, `unpark` and `park` each had a second caller, and LLVM outlined those instead. The shape that held was the opposite: a scope function small enough to need no frame, with the table's creation moved to a `noinline` helper, so the compiler inlines that wrapper into its callers, which call the one `Table.intern`.

Two removals in the same path then paid for what the token lists genuinely add (a length mask, the id's flag bits, a "may have a token list" test):
- The lookup's compare now hands back the record it found equal, so the found path no longer reloads the slot array after `eqlBytes`.
- The ring's `removeAt` checks its range once instead of slicing twice.

Setter ended at 0.996 and set/get at 0.999 against batch 2.

**Fix**:
1. Disassemble the hot function in both release binaries (`objdump --no-show-raw-insn --disassemble-symbols=<sym>`) and list its calls. A `bl` to a function the base inlined is the first suspect.
2. Shrink the caller rather than force the callee: move the cold part of the wrapper (first-use setup, error paths) into a `noinline fn`, so the wrapper itself inlines into its callers and they call the one shared body. Force `inline fn` only on small leaf callbacks such as a hash-map adapter's `eql`, which call nothing.
3. Pin what a test can see. An `inline fn`'s calling convention can be read at comptime (`@typeInfo(@TypeOf(f)).@"fn".attrs.@"callconv"`). Unit tests run in Debug and cannot see LLVM's inlining, so check the release binary's call list with a script over objdump as the red/green of the shape.
4. Re-list the calls after every shape change, before you measure: a forced inline can push its callees out of line.

**Takeaway**: **When a hot row rises and its source did not, count the callers of what it used to inline. A new caller elsewhere can push it out of line. Fix it by making the caller small, not by forcing the callee inline, and check the release binary's call list after each change.**
