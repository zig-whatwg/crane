# Architecture: On macOS a recommitted page needs MADV_FREE_REUSE, or the footprint never counts it again

**Date**: 2026-11-10
**Lesson**: A page decommitted with `MADV_FREE_REUSABLE` and written again stays in the task's `reusable` ledger, out of `phys_footprint`, until `MADV_FREE_REUSE` is called on it - so every commit of a page that may have been decommitted makes that call. And `MADV_FREE_REUSABLE` fails with EPERM on an inaccessible page or any range with one in it, so decommit before you protect, never across a part that is not committed.

**Why**: XNU marks a reusable page `vmp_reusable` and keeps the mark through later faults; only `vm_object_reuse_pages` (MADV_FREE_REUSE) clears it (vm_fault.c, vm_object.c; the deep review's research R10). `vm_map_reusable_pages` refuses a non-writable entry and a range with holes (vm_map.c). The footprint is what /performance/ publishes, so a recycled span missing from it would make Crane's per-node bytes look smaller than they are on the host that publishes them.

**What Happened**: The oss review's probe P1 (tmp/redesign/review/oss/appendix-probes.md) measured 64 MiB touched at 65.14 MiB footprint, 1.14 after REUSABLE, still 1.14 written again without REUSE, 65.14 after REUSE; REUSABLE on PROT_NONE and on a mixed range: EPERM, nothing released. Lane h1 turned it into a red test (tests/platform/h1_address_space_test.zig, "footprint after decommit and recommit equals a fresh commit's"): with `commitPages` making no REUSE call it failed on chat.local; with the call it passes.

**Fix**: PartitionAlloc's order (page_allocator_internals_posix.h at Chromium 145), in kit/posix's address-space group: `commitPages` = mprotect read-write, then `madvise(MADV_FREE_REUSE)` on every commit (harmless on a page never decommitted); `decommitPages` = `MADV_FREE_REUSABLE`, falling back to `MADV_DONTNEED`, returning an error when both fail; a caller retiring pages decommits first and protects second (BrowserHeap.retire).

**Takeaway**: **On macOS, discard with REUSABLE and recommit with REUSE, in pairs, and discard before you change protection - or the memory is either never released or never counted again.**
