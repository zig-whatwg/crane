# Architecture: Native owner liveness differs from realm callability

**Date**: 2026-10-08
**Lesson**: A context's inability to run script does not prove its native pending-operation owner is gone.

**Why**: Host contexts can expose timers without an engine, and a retired realm may outlive some native objects. An asynchronous payload must both stop script delivery and clear a still-live native owner's pending link before freeing itself. Those checks answer different questions.

**What Happened**: Review of queued XHR document-abort delivery found that a shared `instanceLive` predicate required a live engine even when detaching a plain native pending pointer. An engine-less context could start asynchronous XHR through its timer. The fetch's realm check then discarded the request, but detachment refused to clear its native link; a subsequent public open or teardown followed freed pending storage. The pre-fix native probe reports a DebugAllocator double free: fetch sweep frees PendingFetch first, then public open follows the dangling link and frees it again. A separate timer-only host path exposed an assumption that every document request had an event loop.

**Fix**: Distinguish a same-generation native owner with initialized internal state from a realm that can run callbacks. Detach pending storage using the native-owner condition; gate event delivery using both conditions. Retain independent run/drop holds for response and cancellation tasks. On timer-only hosts, use an owned timer, release its hold only after successful cancellation or callback/drop, and recheck the captured document identity before delivery. No scheduler or allocation failure is a reason to dispatch events synchronously.

**Takeaway**: **Clear native ownership links while their owners exist, even when script delivery is no longer possible.**

Integration also found this distinction in explicit realm discard, beyond the existing fetch-sweep path. A native event-loop host can own an asynchronous XHR without an engine. Select the existing clear-link-before-cancel path while its native owner is live; otherwise cancellation frees the payload but a later open follows the stale pointer. The pre-fix allocator control detected a double free on that reopen.
