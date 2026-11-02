# Debugging: A fault a few bytes past a page boundary is a freed bucket

**Date**: 2026-11-02
**Lesson**: An EXC_BAD_ACCESS whose address is a page boundary plus a small offset (0x16d460021) is usually a read of a field at that offset in an object that sat first in a page the allocator has since unmapped. On macOS arm64, mmap regions and thread stacks share the 0x16xxxxxxx range, so an address there does not show that the object lived on a stack.

**Why**: The runner's DebugAllocator keeps small allocations in bucket pages and unmaps a page once its last slot is freed. A read through a freed pointer faults only when the freed object was the last live slot of its page. Otherwise the stale bytes still hold the old values, and the read silently succeeds. So a deterministic use-after-free shows up as a crash in only a few of N runs: 2 of ~198 journal records, and 1 of a 13,197-file sweep.

**What Happened**: The streams/readable-streams/from.any.js crash report put the fault in `protocol_conversions.iteratorNextValue`, at 0x16d460021. The brief called it a stack-range address and proposed a stack record outliving its frame. Zig's auto layout puts the Iterator Record's `kind` at offset 0x21 (33), after two pointers and an allocator (measured: `@offsetOf` = 33, size 40). A record at the page-aligned 0x16d460000 explains the address exactly. `kind` is read only after the call into the iterator's `next()`, and that call had freed the record (see "A stream source that calls script keeps itself alive across the call").

**Fix**: Read the faulting address against the layouts of the structs that the top frame dereferences, before building on a theory of the address range. Then reproduce in Debug with the testing allocator: Debug overwrites freed memory, so the same use-after-free crashes on every run, in a unit test.

**Takeaway**: **A sweep-only crash at page + small offset is a field read of a freed object; find the field at that offset, and make it deterministic under Debug, which overwrites freed memory.**
