# Architecture: Stable continuations own their native record

**Date**: 2026-10-07

**Lesson**: A queued stable-state section must retain its original native activity record until it runs or is dropped.

**Why**: Native element teardown and microtask completion have different lifetimes. An activity bit roots an existing wrapper, but does not identify an unwrapped element after its native slot is returned. A callback that looks up state through the old element address can run against a later element at that address.

**What Happened**: The parser's completed native subtree cleanup exposed an intermittent media callback failure. A deterministic test loaded an audio element, destroyed it, then created and loaded another audio element in the reused slot. An observer between the old and new stable callbacks saw NETWORK_EMPTY instead of NETWORK_NO_SOURCE: the old callback consumed the new element's resource generation.

**Fix**: Allocate an independent continuation with the original Activity, resource generation and native slot generation. Queue it through the existing resolved-promise reaction contract, which supplies exactly one fulfilled or dropped end. Keep the native Activity until all tasks, pending continuations and running callbacks end. Detach cancels behavior without freeing queued identity. Promise fulfillment already enters its registered realm; avoid another realm scope that could outlive retirement inside the callback. Test FIFO behavior, detached completion, realm-end drops and retirement from within the running callback with std.testing.allocator. Repeat the original sweep prefix to distinguish a proven local fix from a merely plausible explanation of an intermittent crash.

The design follows V8 13.1 Promise::Then in src/api/api.cc and PerformPromiseThenImpl in src/builtins/promise-abstract-operations.tq: the native API bypasses user then/species and queues a fulfillment job directly. A later shutdown test showed that separate promise creation and reaction registration can run an automatic checkpoint between them. The engine protocol therefore provides one atomic `queueRealmMicrotask` operation, and V8 uses its existing `SuppressMicrotaskExecutionScope` across both calls. The scope's destructor only decrements suppression; it does not run a checkpoint.

**Takeaway**: **Retain queued identity separately from the element, and give every continuation a completion and a drop path.**
