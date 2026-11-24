# Testing: A failure sweep needs its randomness seeded from the test - an allocator that places by entropy moves the allocation count

**Date**: 2026-11-24
**Lesson**: `std.testing.checkAllAllocationFailures` first counts the allocations of a clean run, then fails each one in turn, and it expects every attempt to make the same allocations in the same order. If code under the sweep draws placement from the OS's entropy, every attempt can lay its blocks out differently. When a different layout opens a different number of spans or chunks, the allocation count moves and the sweep fails as nondeterministic. It fails only sometimes, so it shows up as a FLAKY test, not as a red one. In a test build, seed that randomness from the test's seed (`std.testing.random_seed`, which the launcher sets with `--seed`), so a run replays its layout.

**Why**: Random placement is a hardening feature (lane hard1: K = 2 random buckets per node size class, so a freed block of one interface is not reissued to a type an attacker picked). In production its seed must come from entropy. A failure sweep, though, needs the same seed in every attempt. The test harness already has a seed meant for replay; using it keeps the placement random from run to run and fixed within one.

**What Happened**: Lane hard1 set K = 2 (user-ruling 2026-11-24). The final gate on server1 read one FLAKY test in 13,788: xm1_svg_interfaces_test "SVG parent construction unwinds every failed allocation", which failed first and passed twice alone. That test sweeps six SVG element types, each attempt in a scope of its own. Each scope's heap seeded its bucket choice from entropy. Each span the heap opens asks the scope's FailingAllocator once (`Engine.grow_hook`). So in one attempt the six types shared 2 spans, in another 3, and an attempt whose failing index lay past its own count reported nondeterminism. 382 test files use the sweep. With K = 1 it never showed, because the placement had no random choice.

**Fix**:
1. Red test: two scopes in a test build with no seeded Browser share a bucket seed. From entropy they match once in 2^64 (tests/runtime/hard1_state_heap_test.zig, 405315009).
2. `BrowserScope.startHeap`: when the Browser has no seeded stream, a test build seeds the engine from `std.testing.random_seed`. The branch is comptime-gated on `builtin.is_test`, and every other build keeps the OS's entropy (2d71fe943).

**Takeaway**: **When you add random placement to an allocator, look for the failure sweeps first: in a test build, seed the placement from the test's seed, or every sweep over it becomes a flake.**
