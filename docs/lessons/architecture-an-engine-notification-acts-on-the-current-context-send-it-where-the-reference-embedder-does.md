# Architecture: An engine notification acts on the current context - send it where and how the reference embedder does

**Date**: 2026-11-11
**Lesson**: Copying which value Blink passes to a V8 notification, without the context it is inside and the moment it sends it, timed out 41 files.

**Why**: A V8 notification is not only its argument. `Isolate::ContextDisposedNotification(kNoDependants)` also
aborts the asynchronous WebAssembly compilations of the isolate's CURRENT context (15.7 src/api/api.cc: "We left the
current context, we can abort all WebAssembly compilations of that context") and drops that context's dirty
FinalizationRegistries: V8 takes the entered context for the disposed one, because Blink calls it from
`LocalWindowProxy::DisposeContext`, inside a `ScriptState::Scope` of the context being disposed, at the navigation.
An embedder whose contexts stay entered, or which sends the notice later, hands V8 another page's context.

**What Happened**: Lane v8up b5 made a page's end say `kNoDependants`, as Blink's
`V8GCForContextDispose::NotifyContextDisposed` does (it had said `kSomeDependants` for every realm). Crane sent the
notice after exiting the realm's context, and for a realm a navigation replaced it ran from the collector's queued
end, during the next page. The unit tests (counts of each kind) passed, the gate was green, and the FULL A/B lost
123,171 subtests: 41 `wasm/core` files timed out because the running page's `WebAssembly.compile()` jobs were
deleted and their promises never settled. The same sweep showed a second cost of changing the collector's cadence:
a finalizer that writes a JS object, which V8 15.7 forbids in weak callbacks and V8 13.1 allowed, crashed three
files that six forced collections per page end had hidden.

**Fix**:
1. Read the engine's implementation of the call, not only its header comment: list everything it does and which
   state it reads implicitly (the current context, the current isolate, the entered realm).
2. Read the reference embedder's call SITE: which scope it is inside, at which moment of the algorithm.
3. Send the signal at that moment, inside that scope (`v8_Isolate_ContextDisposedNotification` now enters the
   disposed context; the notice goes out at detach, never from the collector-driven end).
4. Test the side effect on a bystander, not only that the signal was sent: here, a compilation in another page
   still resolves.
5. A change to WHEN collections happen needs the full sweep before it is called done: it moves every finalizer.

**Takeaway**: **A signal copied from a browser is three things - its argument, the scope it is sent in and the
moment it is sent; read the engine's implementation for what it reads implicitly, and test a bystander.**
