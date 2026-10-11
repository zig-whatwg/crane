# Testing: A DebugAllocator that captures stack traces grows RSS with every allocation

**Date**: 2026-10-11
**Lesson**: On aarch64-macos with Zig 0.16, a stack capture leaks up to about 830 B, so a DebugAllocator that captures traces makes each Zig allocation look like retained memory. gc_bench reported a "660 B per DOM call" leak that did not exist.

**Why**: `std.debug.captureCurrentStackTrace` unwinds with DWARF CFI (`StackIterator` `.di`). When a frame cannot be unwound that way, `StackIterator.next` switches to frame-pointer unwinding by overwriting itself (`it.* = .{ .fp = fp }`, lib/std/debug.zig:1056) without calling `deinit` on the `SelfUnwinder` it replaces. That unwinder's CFI virtual machine owns two ArrayLists, its columns (640 B) and its stack (190 B), so both leak on every capture. Where they go depends on `std.debug.getDebugInfoAllocator()`. By default it is an ArenaAllocator over `page_allocator`, so the leaked bytes become anonymous VM:
- vmmap shows it as "Untagged", with arena chunks growing 1.5x each;
- `mstats()` does not count it;
- the DebugAllocator's own outstanding count does not count it;
- `leaks` does not count it.

`DebugAllocator(.{})` in Debug captures 6 frames on every allocation AND every free. `std.testing.allocator` captures 10, and the WPT runner's traced allocator (`CRANE_LEAK_TRACES=1`) captures 6.

**What Happened**: Lane utf16 found RSS growing 6.6 MB per 10,000 calls of `e.hasAttribute("title")`, `e.getAttribute("title")` or `e.title`, while these all stayed flat: malloc, the Zig-side count, the V8 heap, `global_handle_bytes` and the live object globals. `object_globals_from.FunctionCallbackInfo_This` rose by one per call, which looked like the constructor receiver leak lane smallfix had fixed, now on the method path. Both readings were wrong:
- `object_globals_from.*` counts creations cumulatively by design (protocol.zig, diagnosticCounters), and the receiver was released on every path.
- The calls that grew were exactly the ones that make a Zig allocation: a string argument or a string result.
  - `e.nodeType`, `e.isConnected` and `e.hasAttributes()` were flat.
  - Under `--c-alloc` (malloc), `hasAttribute` grew 6.1 MB over 30 cycles, against 6.6 MB for `Math.abs`. Under DebugAllocator it grew 189 MB.
- A walk of the DebugAllocator's buckets at the end of the run found 14 pages in use. The growing VM was elsewhere: vmmap showed "Untagged" regions of 18.2, 27.3 and 40.9 MB, each 1.5x the last - an arena's chunks.
- A 20-line probe settled it: 100,000 `captureCurrentStackTrace` calls in a loop added 80 MB of RSS. With `getDebugInfoAllocator` overridden to `c_allocator`, `leaks --atExit` named `VirtualMachine.runTo`'s two ArrayLists, one each per capture.

**Fix**:
1. gc_bench's allocator is `DebugAllocator(options.allocator_config)`: no stack traces, safety on, the same as the runner's sweep allocator. tools/gc_bench_options.zig pins this in a test.
2. Reading RSS from anything that captures traces:
   - A traced WPT run (`CRANE_LEAK_TRACES=1`) grows by up to about 830 B per capture, and makes two captures per allocation-and-free pair (gc_bench measured 660 B for a call that made one of each). Its RSS, footprint and OOMs are not results, and a long file can exhaust memory on traces alone. Keep traced runs to small files, as the lessons on traced runs already say. Its leak REPORT is unaffected: the arena is mmap, which `leaks` and the DebugAllocator never count.
   - `zig build test` binaries grow the same way through `std.testing.allocator`'s 10 frames, and nothing in the repo can change std's test allocator. A test that loops over many allocations can take a lot of memory: budget for it, never read it as a leak.
3. Confirm any "per-call RSS" claim under `--c-alloc` before chasing it. The leak is real only if it also shows in malloc or in `global_handle_bytes`.
4. Upstream: the leak is in Zig's std, not in Crane. An issue text is in tmp/plans/lane-callleak-handoff.md.

**Takeaway**: **RSS growth that only a DebugAllocator shows is the allocator's own bookkeeping until a malloc control shows it too. Before reading a per-call leak off RSS, run the same body under `--c-alloc`, and read `global_handle_bytes`, not a hand-kept counter, for handles.**
