# Spec Compliance: Restore temporary state on abrupt completion

**Date**: 2026-10-04
**Lesson**: Review temporary state transitions together with every abrupt completion inside their scope.

**Why**: A fallible operation can leave an object in its temporary state when restoration appears only after a successful return. A blind deferred restoration is also wrong if script can abort or finish the object during that operation.

**What Happened**: IndexedDB add, put and cursor update deactivated their transaction during structured cloning. A getter exception or uncloneable value escaped before reactivation, so the next write threw TransactionInactiveError. Six isolated throwing-clone cases failed; all three abort-in-getter controls already passed. The ED's literal question-mark propagation skips its own restoration step; this is already filed upstream as w3c/IndexedDB#490, with #476 related.

**Fix**: Scope the clone and defer restoration only while the transaction remains inactive. Preserve aborted or finished states and the original exception. Perform key-path validation and request enqueueing after leaving that scope. Document the ED 5.11 steps 3–5 discrepancy, the upstream issue, and the matching WPT and WebKit IDBObjectStore::putOrAdd / IDBCursor::update behavior.

**Takeaway**: **Restore the temporary state, not a newer state established by reentrant script.**
