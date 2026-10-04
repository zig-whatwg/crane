# Architecture: A result realm does not own the operation's task

**Date**: 2026-10-03
**Lesson**: Keep the realm that owns queued activity separate from the realm used to construct its result.

**Why**: A method borrowed from another realm can choose the result's prototypes without transferring ownership of the underlying asynchronous operation to that realm's document.

**What Happened**: An IndexedDB transaction in a live parent document accepted an index method borrowed from a removed iframe. The lane correctly captured the method's current realm for the request and result, but then ran the transaction's task in that realm too. The adapter refused the detached document's task even though its realm remained live for ordinary calls. Seven upstream cross-realm index cases timed out; the queue kept trying without executing the request.

**Fix**: Keep the database task in its saved transaction realm, whose queue accepted it. Preserve the independently captured request and result realms and their liveness checks. IndexedDB section 4 and 5.6 leave the task's document implied; HTML 8.1.7.2 calls that underspecified. The integrator's Q32 ruling follows WebKit's separation: [IDBTransaction::requestIndexRecord](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/indexeddb/IDBTransaction.cpp#L960) supplies the transaction's script execution context, and [IDBRequest::enqueueEvent](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/indexeddb/IDBRequest.cpp#L269) queues its event there. Take that ownership design, not the implementation. Verify detached-method delivery and the foreign result prototype together, then rerun the full cross-realm files.

**Takeaway**: **Choose each realm for its specific responsibility; a result-construction realm is not automatically a task owner.**
