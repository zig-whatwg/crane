# Testing: The DebugAllocator never reuses or poisons a freed slot, so a read after `destroy` passes

**Date**: 2026-11-04
**Lesson**: Zig 0.17's `std.heap.DebugAllocator` hands each small slot out once and never writes to it when it is freed, and `Allocator.destroy` writes nothing either - so under the ReleaseSafe correctness runner a destroyed struct keeps its exact bytes until its whole bucket page goes, and a read after the free finds the right values.

**Why**: DebugAllocator's small `free` only clears the slot's used bit (and its requested size); a bucket's `allocated_count` only grows, so the slot is never handed out again; the 128 KiB page is unmapped only when every slot in it is free, and a busy size class almost never empties. `Allocator.free` does `@memset(bytes, undefined)` first - but `undefined` is written as 0xaa only in a Debug build, and `Allocator.destroy` (how a struct is freed) has no memset at all. libc malloc, by contrast, writes its free-list links into a freed block at once and may hand it out again.

**What Happened**: Lane chromeref2's release runner (-Dwpt-runner-release: ReleaseSafe, libc malloc) crashed on two service-worker files every time, alone and in the full run, on both V8 builds; the correctness runner passed both (OK 36, OK 10). Both were a struct freed inside its own step and read after (lane crashes8): fetch_event.zig's InternalBodyPump ran `return self.finish(false)` (which destroys the pump) with `defer self.allocator.free(bytes)` still to run - the defer read the freed pump's allocator; BodyPump's cancel called script whose microtask checkpoint finished (freed) the pump, then read `self.realm`. Under the DebugAllocator both reads returned what had been there. Under libc malloc they read the free list's links and faulted at 0xfc and at 0x69b3a214de9fdca5.

**Fix**:
1. Red tests for each on an allocator that unmaps on free (a counting wrapper over `std.heap.page_allocator`; docs/lessons/testing-a-use-after-free-that-reads-stale-bytes-passes-unmap-on-free.md): they fault at the stale read, then pass with the fix.
2. The correctness runner's sweep allocator gained a front, `runner_allocator.Poisoning`: every block of 32 KiB or less is overwritten with 0xdd before the DebugAllocator frees it. Never reused AND poisoned, a pointer read from freed memory is 0xdddddddddddddddd - not a canonical address on arm64 or x86-64 - and faults at the read. Larger blocks are the DebugAllocator's large allocations, unmapped on free already.

**Takeaway**: **A green run under the DebugAllocator says nothing about reads after a free: its freed slots keep their bytes. Poison what you free (or unmap it) wherever a run is meant to find use-after-frees.**
