# Debugging: A per-call allocation in a lonely size class maps a page every call

**Date**: 2026-10-16
**Lesson**: Under the WPT runner's DebugAllocator, freeing the only live object of a size class empties its bucket, which is unmapped; the next call maps it again. A short-lived allocation per call can cost an mmap and a munmap.

**Why**: `std.heap.DebugAllocator` (tests/wpt_runner/runner_allocator.zig, `never_unmap = false`) keeps one page per size class and returns an empty page to the system. Whether a given call pays that depends on whether anything else keeps the class's page occupied - so two implementations that make the same number of allocations of slightly different sizes can differ several-fold in cost.

**What Happened**: Lane selectors' new parser made exactly as many allocations per parse as the old one (2 for `li`, counted with a wrapping allocator), yet `querySelectorAll('li')` on an empty container cost 5.3 us against 1.8 us at the base, and crane/qs-perf ran ~3% over budget. `sample` on the shard child showed `__munmap` and `__mmap` at the top of the stack under DebugAllocator: the larger AST nodes had moved into a size class nothing else kept alive.

**Fix**: The parsed selector lives only for the call, so dom.selector_matching parses into `std.heap.stackFallback(8192, allocator)`: a typical query allocates nothing. Profile the shard child (`pgrep -f "wpt_runner.*--journal"`), not the supervisor.

**Takeaway**: **Count allocations AND look at where they land: a per-call allocation that empties a DebugAllocator page costs a syscall pair; put call-lifetime data on the stack.**
