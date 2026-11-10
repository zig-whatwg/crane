# Testing: MallocStackLogging=lite adds eight bytes to every block it records

**Date**: 2026-11-10
**Lesson**: Under `MallocStackLogging=lite`, `malloc_history -allBySize` reports each block about 8 bytes larger than it was asked for, rounded to the 16-byte quantum: a 32-byte request shows as 48. Take a block's real size from the request (the code, or a clean run), and use the stack-logging run for counts and sites only.

**Why**: Inferred from the sizes, not from libmalloc's source: every reading fits request + 8 bytes rounded to 16 (the lite mode keeping a stack id with each block would explain it). On 16-byte classes this is invisible for some sizes (312 + 8 = 320, 104 + 8 = 112, the same class either way) and doubles others (32 + 8 = 40, which takes the 48-byte class).

**What Happened**: Lane rare1 b1 measured the framework pages' rare data by site. The fixed 312-byte ElementRareData showed as 320 B, exactly its class. But the new sparse block, 32 bytes for `el.style`, showed as 48 B on every page. The disassembly of the release console's style getter showed the request at 32 bytes (`mov w9, #0x10; lsl w22, w9, w8` for two fields, then the allocator call) and `std.heap.c_allocator`'s raw path calling `malloc(32)`, and the same history also listed other allocations at exactly 32 B. The extra 16 was the logging's own 8 bytes, rounded up.

**Fix**:
1. For bytes per object, count blocks from the stack-logging run, then multiply by the requested size (from the code or a pin) rounded to the allocator's class.
2. Compare sides in the same mode: base and tip both under lite logging cancel the overhead only for sizes on the same side of a class boundary.
3. Read the footprint from a clean run (fw.sh's `clean` mode), never from the logging run.

**Takeaway**: **A stack-logging run tells you how many blocks and from where, not how big they are: under lite logging a 32-byte block reads 48.**
