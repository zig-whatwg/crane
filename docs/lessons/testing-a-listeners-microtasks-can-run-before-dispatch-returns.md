# Testing: A listener's microtasks can run before dispatch returns

**Date**: 2026-10-04
**Lesson**: Locate the callback checkpoint before asserting which post-dispatch changes a listener's microtasks can observe.

**Why**: HTML's cleanup after running script performs a microtask checkpoint when the JavaScript execution context stack becomes empty. An event listener called from a native task can therefore run its queued microtasks before the surrounding event-dispatch algorithm returns.

**What Happened**: A new IndexedDB fixture initially expected an open request's transaction association to be null inside a microtask queued by the upgrade transaction's complete listener. IndexedDB clears that association after firing complete. Reviewing HTML's full callback cleanup algorithm showed that the checkpoint occurs during dispatch, so the microtask must still see the transaction. The fixture was corrected under its owner's grant before any run or implementation change; its original expectation is not evidence of an engine defect.

**Fix**: Read both the API algorithm and HTML's callback cleanup steps. Assert that the synchronous complete listener and its microtasks see the transaction, then assert null at the later open-success event. Keep a separate complete/open/read ordering regression so a fixture repair cannot be counted as fixing that independent engine failure.

**Takeaway**: **After a callback and after its enclosing algorithm are different observable moments.**
