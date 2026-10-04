# Architecture: An opening task retains its upgrade transaction

**Date**: 2026-10-04
**Lesson**: Clearing an IDB open request's script-visible transaction must not release the transaction while the opening task still needs its outcome.

**Why**: IndexedDB commit and abort clear `request.transaction` after dispatch in the same task. The separate open task then reads the upgrade transaction to decide whether to fire success or error. A raw native pointer does not keep the transaction wrapper alive after that request association and the transaction task's own root are released.

**What Happened**: `IndexedDB/idbindex-multientry.any.js` passed its first two workloads but fired an unexpected `open.error` with `AbortError` in the window `Adding keys` case when it followed the 1,000-entry case. The `Adding keys` case alone passed. A two-case Crane reproducer failed eight of eight times, while a control that held the upgrade transaction in script passed four of four. Merely observing `open.error` did not change the failure. The source held `ConnectionTask.transaction` as a raw pointer across the task boundary. WebKit's `IDBOpenDBRequest` instead retains `m_transaction` after hiding the DOM transaction property ([implementation](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/indexeddb/IDBOpenDBRequest.cpp), [member declaration](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/indexeddb/IDBRequest.h)).

**Fix**: Keep a separate owned engine root on `ConnectionTask` when the upgrade transaction is created. Retain it through the final open success or error task, independently of `request.transaction`, then release it with the task's other roots. Run the unchanged upstream file and the two-case reproducer before and after; both are green after this change. Recheck the commit/abort association timing controls and a traced factory run for leaks.

**Takeaway**: **Script-visible association lifetime and algorithm lifetime are different; root the object through its last native use.**
