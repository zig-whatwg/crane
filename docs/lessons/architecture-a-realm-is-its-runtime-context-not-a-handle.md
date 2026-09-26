# Architecture: A realm held across turns is its runtime.Context, not a handle to its engine context

**Date**: 2026-09-26
**Lesson**: A timer or animation-frame callback that must run later in the realm that registered it can name that realm by its `runtime.Context` pointer; it needs no engine handle to the realm's context.

**Why**: The context manager never frees a realm's `ContextData` while the process runs: `removeContext` and `destroyChildContext` RETIRE the entry (its `engine_ctx` becomes null) and only the manager's teardown frees it. So the pointer is a stable, unique identity for the realm's whole life and after, and a retired one says so (`engine_ctx == null`) instead of dangling. A `Global<Context>`, by contrast, keeps the page's whole heap alive (see "A timer that keeps a Global<Context> keeps the whole page"), and comparing two of them needed a raw-address read.

**What Happened**: Moving the window's timers and animation frames behind the Engine table, the host side could not keep `*v8.ffi.Context` Globals. Keying them on the runtime.Context removed three kinds of V8 handle per timer (the context, and the raw-address comparison), and a timer whose realm is gone now fails to enter it rather than running in a detached context.

**Fix**: `WindowTimerData.realm: runtime.Context`, compared by pointer (`clearTimer`, `cancelAnimationFrame`, `windowDestroyed`); the engine enters it through `runTaskInRealm` / `invokeCallbackFunction`.

**Takeaway**: **Hold a realm by its runtime.Context; the context manager keeps it valid and tells you when it has ended.**
