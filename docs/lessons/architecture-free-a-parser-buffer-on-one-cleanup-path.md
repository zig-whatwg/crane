# Architecture: Free a parser buffer on one cleanup path

**Date**: 2026-10-11
**Lesson**: Deinitializing a buffer before a fallible return must also disarm any deferred error cleanup for that buffer.

**Why**: A successful allocation hides the second cleanup. Allocation failure runs both the explicit deinit and the earlier errdefer.

**What Happened**: Fetch's HTTP quoted-string collector can return either its extracted buffer or a copy of the raw substring. Its raw branch deinitialized the extracted buffer and then duplicated the substring. The allocator-failure test crashed at a poisoned address when that final allocation failed, because errdefer deinitialized the list again.

**Fix**: Keep one unconditional defer for the temporary list. The extracted branch transfers it with toOwnedSlice, which empties the list; the raw branch leaves it for the deferred cleanup. Run checkAllAllocationFailures with std.testing.allocator across both return forms before wiring the helper into header splitting.

**Takeaway**: **Use one cleanup path, and test failure at the final allocation as well as success.**
