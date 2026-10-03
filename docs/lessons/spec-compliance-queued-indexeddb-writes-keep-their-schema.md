# Spec Compliance: Queued IndexedDB Writes Keep Their Schema

**Date**: 2026-10-03
**Lesson**: A queued write must preserve the index definitions that applied when it was accepted.

**Why**: IndexedDB exposes schema changes synchronously while processing their storage operations in transaction order. Looking up the latest index set when an earlier write executes changes the meaning of that write.

**What Happened**: While connecting Crane's synchronous native storage to queued requests, the apparent shortcut was to enumerate the store's current indexes during write execution. IndexedDB 4.5's createIndex example rules that out: two earlier writes with duplicate values both succeed, then creating a unique index aborts the transaction. Conversely, deleting an index after accepting a write must not remove that write's earlier uniqueness constraint. The new Crane regression is `idb-index-schema-order.html`.

**Fix**: Preserve each operation's applicable index definitions at placement, keep their native storage alive through execution, and queue index population alongside ordinary requests. An index-population failure aborts the transaction without manufacturing a script-visible request error. Keep the script-visible schema and the queued storage work in their specified order. WebKit's `IDBTransaction::requestPutOrAdd` captures `objectStore.info()` in its operation, and `createIndex` separately schedules index creation: [design reference](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/indexeddb/IDBTransaction.cpp). Take the design, not its ownership or threading implementation.

**Takeaway**: **Synchronous schema visibility does not rewrite operations already in the queue.**
