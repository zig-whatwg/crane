# Testing: An all-OOM count that lets resizes through depends on the backing allocator

**Date**: 2026-10-30
**Lesson**: Under Zig 0.17's `std.testing.allocator` (a SafeAllocator), whether a block grows in place depends on where the run started in its bucket, so a failure-injection loop that counts allocations must refuse resizes, or the count changes from run to run.

**Why**: Zig 0.17 made `std.testing.allocator` a `SafeAllocator`. It never reuses memory and fills 16 KiB buckets (aarch64-macos) one allocation after another, so a block can grow in place only while it is the last allocation in its bucket AND the bucket has room for the growth. Each run starts where the previous one left the bucket. `std.ArrayList` grows by `remap` and falls back to alloc, copy and free, so a remap that fails in the counting run and succeeds in a later run makes that run allocate one block less, finish before its failure index, and `checkAllAllocationFailures` reports `error.NondeterministicMemoryUsage`. Zig 0.16's DebugAllocator grows in place exactly when the new length stays in the block's size class: a function of the lengths alone, the same in every run.

**What Happened**: The Zig 0.17 trial (lane zig017trial, Zig 0.17.0) saw 62 tests/css tests fail `NondeterministicMemoryUsage`; a minimal probe passed and the cause was left open. Lane zig017mem found it in std: 0.17.0's `checkAllAllocationFailures` built its FailingAllocators with resizes allowed. Upstream fixed it on the 0.17.x branch in 7c793c291683 "std.testing: refuse resizes in checkAllAllocationFailures" (codeberg ziglang/zig#37142, fixing #37141, 2026-10-09), which the pinned toolchain 0.17.1-dev+77c319a0f0 contains (`lib/std/testing.zig`, `.resize_fail_index = 0` in both `FailingAllocator.init` calls). With it, tests-css had 0 such failures (1,172 pass, 2 fail: the @hasDecl flips). The issue's own reproduction (two interleaved lists) passed on aarch64-macos, whose blocks never met a bucket's end; a probe that grows one block once, at 96 sizes, did: `growOnce(1344)` counted 2 allocations, and `fail_index` 1 completed with 1. The same loop with resizes refused, or over a DebugAllocator, passed on 0.17 and on 0.16.

**Fix**:
1. Use a Zig whose `checkAllAllocationFailures` refuses resizes (0.17.x since 7c793c291683; not 0.17.0).
2. A hand-written failure-injection loop over `std.testing.allocator` that counts allocations, iterates up to a count, or fails "the next" allocation passes `.resize_fail_index = 0` to `FailingAllocator.init`, as std does now. Otherwise its result can change when unrelated code moves an allocation within a bucket.
3. A test that asserts an exact allocation count measures the code under a refused-resize allocator, or names the allocator it assumes.

**Takeaway**: **Count allocations with resizes refused: under a non-reusing allocator, in-place growth is a property of the run, not of the code.**
