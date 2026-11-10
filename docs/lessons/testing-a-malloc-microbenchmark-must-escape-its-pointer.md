# Testing: A malloc microbenchmark must escape its pointer - LLVM deletes a malloc/free pair it can see through

**Date**: 2026-11-10
**Lesson**: A loop that mallocs, touches and frees a block whose address never escapes measures nothing: LLVM removes the malloc/free pair (and the touch) as dead, and the baseline reads 0.00 ns while every custom allocator, which LLVM cannot see through, reads real time.

**Why**: LLVM knows `malloc` and `free` (they are library builtins with known semantics); a block that is allocated, written and freed without its address leaving the function is removable. A Zig allocator reached through its own code is not a builtin, so only the baseline is optimized away, and the comparison looks like a 100% win for the custom allocator.

**What Happened**: Lane ndalloc b1's allocator prototype benchmark (tmp/plans/ndalloc-bench/bench.zig, ReleaseSafe) printed `variant=malloc work=temp ns_per_op=0.00` on chat.local while the region allocator printed 11-21 ns. Storing the pointer through a volatile write (`@as(*volatile usize, &escape).* = @intFromPtr(p)`) before the free gave malloc 20.1 ns on macOS and 12.8 ns on glibc.

**Fix**: Escape every allocated pointer in a microbenchmark (a volatile store, or keep it in a live array), and sanity-check that the baseline's time is not zero before reading any ratio.

**Takeaway**: **When a baseline is a library builtin (malloc, memcpy, memset), make its result escape, and treat a 0 ns baseline as a broken benchmark, not a result.**
