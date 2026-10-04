# Architecture: IndexedDB Schema Handles Keep Definition Identity

**Date**: 2026-10-03
**Lesson**: Roll back schema handles by definition identity, and keep their visible metadata independent of later transactions.

**Why**: A store or index can be renamed, deleted, and replaced with a new definition of the same name in one upgrade. The name alone cannot tell which surviving handle belongs to the original definition.

**What Happened**: Native regression tests showed that abort restored the database map but left old handles deleted, while replacement handles still appeared live. Another test showed a finished store handle observing a subsequent transaction's index changes through shared record storage.

**Fix**: Assign store and index definitions IDs owned by their database/store and preserve them in rollback snapshots. Give each handle its own visible name and index-name set. Prepare rollback metadata before schema mutations, then restore old handles and invalidate new definitions without allocating during abort. Retain the memory borrowed by a finished handle's lookup maps until the handle is destroyed. WebKit similarly uses definition identifiers and original metadata in [IDBObjectStore::rollbackForVersionChangeAbort](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/indexeddb/IDBObjectStore.cpp) and [IDBIndex::rollbackInfoForVersionChangeAbort](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/indexeddb/IDBIndex.cpp); use that design, not its implementation.

**Takeaway**: **A reused schema name does not make a replacement definition the old object.**
