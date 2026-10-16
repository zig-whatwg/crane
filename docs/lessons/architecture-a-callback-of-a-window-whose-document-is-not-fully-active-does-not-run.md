# Architecture: A callback of a Window whose Document is not fully active does not run

**Date**: 2026-10-16
**Lesson**: A frame realm that a navigation replaced, or whose iframe was removed, stays alive while script reaches it, and its functions stayed callable through the engine's callback operations: a listener the old frame added to its parent's document still ran.

**Why**: Crane keeps a replaced frame realm alive (detached) until the collector takes it - its tasks stop (`protocol_realms.isDetached`), but nothing stopped a callback another realm held. DOM inner invoke step 8 skips a listener when targetGlobal or listenerGlobal is a Window whose associated Document is not fully active; Blink (`IsCallbackFunctionRunnable`, `JSBasedEventListener::Invoke`'s `ContextIsValid`) and Gecko (`CallbackObject::CallSetup`) refuse every such callback.

**What Happened**: execution-timing/083.html became newly blocking in gen 136 once xorigin2 made the frame's navigation replace its realm: the third `fireFooEvent()` logged an extra "event: foo". All three browsers pass it (wpt.fyi stable). The same gap left dom/events/event-listener-not-fully-active-target.html at 4/16 and -navigated at 0/3: the other half of step 8 (targetGlobal) was missing from EventTarget's inner invoke.

**Fix**: the V8 adapter's `invokeCallbackFunction`, `callUserObjectOperation` and `constructCallbackFunction` return OperationFailed for a callback whose associated realm is detached - nothing called, thrown or reported; the protocol states it for every adapter. Pinned in tests/v8/page_realm_operations_test.zig; 083.html 0/1 -> 1/1.

The targetGlobal half went into EventTarget's innerInvoke first and was reverted: it won the dom/events not-fully-active files (-target 4 -> 16/16) but newly blocked four files all three browsers pass. IndexedDB makes a request in the current realm (a removed frame's, for a method borrowed from it), and dom.document_activity already answers "not fully active" during destroyChildNavigable's step 4, where HTML still has the document fully active until step 5 - so the navigation API's abort and navigateerror reached no listener. Those two come first; the targetGlobal half follows them.

**Takeaway**: **A realm kept alive for script is not a realm that may run script: decide runnability where every callback is invoked, from the realm's own state, not where one caller happens to look. And before adding a spec check that reads another subsystem's state, run the files that state's owners care about: a correct check over an early or wrong answer regresses what the browsers pass.**
