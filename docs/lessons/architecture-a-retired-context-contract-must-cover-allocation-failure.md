# Architecture: A retired context contract must cover allocation failure

**Date**: 2026-10-03
**Lesson**: A promise that a retired realm's Context remains readable must hold on allocation failure as well as on the normal retirement path.

**Why**: Queued work can borrow a Context without keeping its realm alive. A liveness check is safe only if the record containing that check still exists. Keeping an engine value rooted does not guarantee that its native platform instance survives explicit realm retirement either.

**What Happened**: IndexedDB retrieval needs the method's current realm, including cursor iterations that reuse a request from another realm. The protocol owner documented an agent-lifetime Context record and `hasEngine()` as its liveness test (lane Q22). Reading the complete retirement implementation found that `context_manager.retireEntry` appended to a retired-entry list, then freed the Context immediately if that append ran out of memory. The owner confirmed this violated the new contract (Q23). This was a source finding, not a reproduced sweep crash.

**Fix**: The adapter owner queued reserving retirement capacity during fallible realm registration, so retirement can append without allocation. IndexedDB uses the approved Context contract without changing the adapter and records the remaining OOM defect. Each queued request stores its Context separately from its instance pointer, checks it before dereferencing the instance, and rechecks cancellation after script and microtasks. Work must end on its own agent's event loop, before the Context's ultimate owner ends.

**Takeaway**: **Prove the lifetime of the liveness record itself, including OOM paths; a check through freed memory cannot establish safety.**
