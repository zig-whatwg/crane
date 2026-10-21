# Architecture: Restoring a Document Must Restore Native Rendering Work

**Date**: 2026-10-21

**Lesson**: Retiring a borrowed rendering request while its document is inactive requires recreating that request when the document becomes active again.

**Why**: The document owns pending autofocus candidates. The frame scheduler only borrows active document identities, guarded by navigable identity and slab generations. A cached document can keep its candidates while losing its scheduling request, and it need not have any requestAnimationFrame callback to restart rendering.

**What Happened**: Row 111 added candidate-driven rendering. Its native suspend/retire/restore test showed that the scheduler correctly retired an inactive document's request, but restoring the document left zero pending requests instead of one. The retained candidates could then wait indefinitely. The same test also checks that restoring a document after candidate exhaustion creates no frame timer.

**Fix**:

1. Keep candidate ownership in Document and borrowed scheduling identities in the existing frame state.
2. Continue retiring requests for replaced, destroyed, or inactive documents.
3. In `resumeWindowTimers`, recover the live realm's active document and request native rendering before the existing frame scheduler call.
4. Make the request conditional on pending candidates. An empty restore must preserve the idle behavior.
5. Test replacement, destruction, exhaustion, and reactivation independently; a generation guard alone covers only the first two.

**Takeaway**: **Restoring an owner must also restore the wakeup for work that the owner retained.**
