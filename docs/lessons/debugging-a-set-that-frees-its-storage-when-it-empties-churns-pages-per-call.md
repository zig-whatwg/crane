# Debugging: A set that frees its storage whenever it empties churns pages on every call

**Date**: 2026-11-06
**Lesson**: A side set that hovers between zero and one entry and calls `clearAndFree` when it empties allocates its table on every insert and frees it on every removal. On `std.heap.page_allocator` that is a page mapped, first-touched and unmapped per call. Keep the capacity when it empties, and give it the owner's allocator.

**Why**: Every addEventListener and removeEventListener converts its callback argument into a CallbackWrapper. The wrapper joins its agent's set of live wrappers (src/runtime/engines/v8/callback_registry.zig, `Live`) and leaves it when the converted argument is freed after the call. In an add/remove loop the set goes 0, 1, 2, 1, 0 on each iteration. `unregister` freed the set's storage whenever its count reached 0 (`clearAndFree(std.heap.page_allocator)`), so the next `put` grew it from nothing: an `mmap`, then a memset of the new page's metadata (the first touch faults it in), and an `munmap` at the next empty.

**What Happened**: Lane perf2's batch 2 profile (macOS `sample`, main-thread shares, main 0ed2ad979d1's apple_m1 release console) put events.add-remove-listener - 38x Chrome in perf round 1 - at 80.2% under the set: `__munmap` 31.1%, `__mmap` 8.8%, and 39.7% in the `<deduplicated_symbol>` that `grow` calls (the page's first touch). The registry lookups the batch was about were 0.2% of that row. The defect was invisible to every leak check, because the storage was always freed, and to the unit tests, which never timed a loop.

**Fix**:
1. `Live` keeps its capacity when it empties (`clearRetainingCapacity`, which also resets every tombstone), and takes the agent's allocator (`AgentOptions.allocator`, read from the agent's record at the first wrapper). The agent's end frees it. WTF's HashTable never frees a table its last entry leaves either: it shrinks only while it is larger than its minimum size (WebKit Source/WTF/wtf/HashTable.h `shouldShrink`; Blink platform/wtf/hash_table.h `ShouldShrink`; minimum 8 in both).
2. The test counts allocations, not time: tests/v8/callback_set_retains_test.zig injects a counting allocator as the agent's. The first wrapper must allocate the set's storage from it, the emptied set must keep a capacity, and 500 make-and-free cycles after that must allocate nothing.
3. When a row is far off the browsers, profile it before assuming it shares the cause you are working on. Here one row's floor was a two-line bug in a file the batch did not touch.

**Takeaway**: **A container that frees its storage when it empties pays an allocation and a free per insert/remove pair; near zero entries, that is every call. Keep the capacity (as WTF's HashTable does), and pin it by counting allocations through an injected allocator, never by timing.**
