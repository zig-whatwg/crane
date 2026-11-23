# Architecture: std.heap.page_allocator maps a whole page for every allocation - never use it for a small record or a per-call temporary

**Date**: 2026-11-22
**Lesson**: Zig's `std.heap.page_allocator` rounds every request up to the page size and calls mmap for it (std/heap/PageAllocator.zig `map`, the pinned 0.17 toolchain), so a 24-byte record costs a 16 KiB page on macOS and a 4 KiB page plus a VMA on Linux; keep it for page-sized buffers, and give small records and per-call temporaries the owner's allocator.

**Why**: The page allocator has no size classes and no reuse; each allocation is a mapping. Linux's default `vm.max_map_count` is 65,530, and a process that exceeds it fails every later mmap - V8's and libc's included.

**What Happened**: Lane alloc1's inventory of allocation families (design batch, main 5dce9e169) found real run-time `page_allocator` uses on page-input paths: `EventTarget`'s SignalRemoval record (EventTarget.zig:990: one page per `addEventListener` with a signal, kept until the signal aborts or dies - one long-lived AbortController over 100,000 listeners is about 1.6 GB of footprint on macOS), URL.canParse, IDNA labels, the inline-style display parse, compareTreeOrder and findCommonAncestor (a page mapped and unmapped per call). READ, not run.

**Fix**: Allocate the record from the object's own allocator (`runtime.allocatorOf(instance)` for an Instance); per-call temporaries from the caller's allocator or a stack buffer. A lint keeps `page_allocator` out of src/ outside the platform and reviewed process-wide sites (allocator-hardening batch C).

**Status (2026-11-22, lane leak3)**: Done.
- Every run-time use in src/ moved: the signal record to the Browser allocator, and it now leaves its signal with its listener; the per-call lists to their owner's allocator, a stack buffer over it, or libc's where none is in reach.
- Measured on Linux: 4,000 kept signal listeners cost +18.8 MiB of footprint before, and fit within the 4 MiB the test allows after (the same listeners with no signal: +2.6 MiB).
- The VMAs did not pile up on Linux: the kernel merges adjacent anonymous mappings (+120 over those 4,000).
- `zig build lint-page-allocator` (part of `zig build test`) fails on any unmarked use. A reviewed site carries a `// page-allocator: <why>` line directly above it.

**Takeaway**: **`page_allocator` is an mmap per allocation: a small record on it costs a page and a mapping each, so it never holds per-object or per-call state.**
