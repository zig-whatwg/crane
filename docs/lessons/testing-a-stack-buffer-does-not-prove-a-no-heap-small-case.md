# Testing: A stack buffer does not prove a no-heap small case

**Date**: 2026-10-25
**Lesson**: Test a stack-backed container with a fallback allocator that fails immediately, because its growth policy can bypass the stack buffer on the first item.

**Why**: `std.heap.stackFallback` uses its local buffer only when the requested allocation fits. `std.ArrayList.append` reserves more than the required element count. A buffer sized for four slice elements therefore need not satisfy the list's first growth request.

**What Happened**: The pure shadow-part forwarding helper passed its six parsing, forwarding and allocation-failure tests, but its new four-name no-heap test failed on the first append. The stack buffer held exactly four names; ArrayList's initial capacity request was larger. Using a failing fallback allocator made that cost visible without a timing measurement.

**Fix**: On the first unique name, call `ensureTotalCapacityPrecise(allocator, 4)`, then let std manage later growth. Keep the stack fallback allocator in its caller's scope: `get()` stores its address in the allocator interface, so an initialized buffer cannot move with a returned container. Pair each list's deinit with its allocation interface. Test both the four-name case with no fallback allocation and larger sets under `checkAllAllocationFailures`.

**Takeaway**: **Pin the allocation claim with a failing fallback; stack storage alone is not evidence.**
