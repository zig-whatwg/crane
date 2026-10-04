# Testing: A poisoned Array.prototype poisons testharness.js too

**Date**: 2026-10-04
**Lesson**: A test that puts setters or getters on `Array.prototype[i]` (or `Object.prototype.x`) to prove the engine defines rather than assigns must remove them before it asserts: testharness.js builds arrays with push and reads them back, and its own assertion messages come out garbled.

**Why**: The poison is global to the realm. `Array.prototype.push` is a [[Set]], so the harness's own lists run the test's setter, and a getter on `Array.prototype[0]` answers for every hole the harness reads.

**What Happened**: crane/bd-sequence-result-create-data-property.html first poisoned indices 0-4 for the whole test with a getter returning "inherited"; the failure read "inheritedinheritedinheritedinheritedinherited but got 6" - the message itself built from poisoned arrays. With the setter only around `dispatchEvent` and a `finally` that deletes it, the same red read "no Array.prototype setter ran expected 0 but got 5".

**Fix**: Poison right around the call under test, in a `try`/`finally` that removes it, then assert. Prefer a setter-only accessor (no getter) so reads of holes stay undefined.

**Takeaway**: **Scope a prototype poison to the one call it tests; the harness shares the realm and trips over it.**
