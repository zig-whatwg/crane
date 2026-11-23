# Architecture: The inspector knows a realm from the realm's life, not from a session's start

**Date**: 2026-11-22
**Lesson**: Make a realm known to the inspector where its life is known - when the Browser becomes served (every realm it already shows) and at each commit - never when a session starts or a domain is enabled: a session-start registration leaves every operation that runs before it (Runtime.evaluate without Runtime.enable, a debugger pause, console replay) with no context.

**Why**: Blink's MainThreadDebugger::ContextCreated registers every context with V8's inspector as the context is created, whether or not DevTools is attached; a session that attaches later finds them all, and Runtime.enable only reports what is known. Crane's inspector exists only while a server serves the Browser, so "as it is created" splits in two: the realms that exist when the Browser becomes served (BrowserSide.install -> contexts.onServed), and each later commit (lane tpc's onServedCommit). Both go through registerWithToken, so a realm is known once whichever path saw it first.

**What Happened**: Lane tpg's CDP pass found a tab loaded before the server started: an earlier fix registered its realms at a page session's start (f30aa6b86), which covered Runtime.enable but not a pause or an evaluate that came first, and duplicated tpc's commit-time path. The integrator asked for one path.

**Fix**: contexts.onServed walks every navigable's live realm (skipping closed navigables, ones with no window, and a child's pending initial about:blank), isolated worlds included, through registerWithToken; the session-start registration in domains/runtime.zig went (64de91d6a).

**Takeaway**: **Register state with an observer at the owner's lifecycle points - its creation, and the moment the observer starts existing - not at the first consumer's arrival; a consumer-triggered registration is always one consumer late.**
