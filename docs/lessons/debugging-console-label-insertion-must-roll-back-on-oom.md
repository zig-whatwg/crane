# Debugging: Console Label Insertion Must Roll Back on OOM

**Date**: 2026-10-18
**Lesson**: Inserting a borrowed string key before allocating its owned copy needs rollback if that allocation fails.

**Why**: `StringHashMap.getOrPut` publishes a new entry immediately. Its key remains borrowed and its value remains undefined until the caller initializes them. Returning after a failed key duplication leaves invalid state for later lookup and teardown.

**What Happened**: Console's count map and timer table both inserted the caller's label before duplicating it. A failure of the second allocation left a borrowed label in a map whose teardown frees every key. The ordinary WPT checks never exercised this path; the output tests also stopped at an unavailable BiDi subscription before calling Console.

**Fix**: Remove only the new entry when duplication fails. Keep the existing-entry path allocation-free. Test each allocation point through the generated namespace with `std.testing.FailingAllocator` backed by `std.testing.allocator`. In a red test, remove a detected borrowed entry before asserting so teardown does not obscure the failed ownership assertion with an invalid free.

**Takeaway**: **A failed owned-key allocation must leave the map as it was before insertion.**
