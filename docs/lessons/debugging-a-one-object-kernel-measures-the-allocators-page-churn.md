# Debugging: A kernel that frees its only object each op measures the allocator's page churn

**Date**: 2026-10-27
**Lesson**: A bench that creates and destroys one object at a time under DebugAllocator empties that object's size class every op, so the allocator maps and unmaps a bucket page every op. Its whole-process instruction count is then mostly noisy kernel work, and a "cliff" at one size is noise.

**Why**: `std.heap.DebugAllocator` (the WPT runner's allocator; tests/wpt_runner/runner_allocator.zig, `never_unmap = false`) bump-allocates inside a bucket page and never reuses a freed slot. It returns the page to the system when its last slot is freed. `/usr/bin/time -l`'s "instructions retired" also counts the kernel work the process causes: mmap, munmap and zero-fill faults.

**What Happened**: Codex row 124's slot-count kernel created and destroyed one ComputedStyle replica per op, at 210-250 slots.
- 220 slots measured 5.5% BELOW 210. The five-point fit had R² 0.48, and the point was read as a size-specific code-shape cliff.
- Lane cascadefast2 rebuilt the kernel at both trees. The disassembled `batch(n)` instances are identical (109 instructions; `batch(250)` folded into `actual`).
- Every run made exactly 2 page reclaims per op, 202,318 per run at every count.
- 7 runs per count gave per-count spreads of 7-41% and per-run slopes from -25.9M to +40.3M instructions per slot.
- The dip moved: at row 124's tree it was at 220 again; at main's tree the lowest median was 210.
- With 1,000 styles live (the page's shape) and smp_allocator, the same per-slot cost is a clean line: 131.8 instructions per added inherited longhand and 98.7 per non-inherited one, R² 0.997.

**Fix**:
1. Measure in the page's live-set shape: keep as many objects alive as the page does, so the size class's pages stay mapped.
2. Report page reclaims per op beside instructions. A constant 1-2 reclaims per op means the allocator, not the object, is being measured.
3. Read the spread across runs, and the slope per run, before reading a size effect off medians.
4. Split the CPU parts with a reusing allocator (smp_allocator) from the allocator's own effects (the runner's config). Report both.

**Takeaway**: **Before reading a size effect off an instruction count, check page reclaims per op and the spread across runs: one object at a time under DebugAllocator measures mmap, not the object.**
