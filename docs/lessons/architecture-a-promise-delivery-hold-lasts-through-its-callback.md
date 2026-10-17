# Architecture: A promise delivery hold lasts through its callback

**Date**: 2026-10-17
**Lesson**: Release a promise reaction's existing record hold after its callback returns, including every script callback it invokes.

**Why**: Clearing the ongoing operation can make its native record eligible for collection even though the current completion callback still uses it. Script invoked during completion can start another operation and run collection recursively.

**What Happened**: Navigation's `Wait.deliver` decremented `record.waits` before entering `successSteps`. Those steps cleared `ongoing_event` and reset focus. A blur handler started an intercepted navigation, whose collection freed the delivering record. `successSteps` then read the freed tracker and passed a corrupt handle to `resolveFinished`. On the frozen ReleaseSafe base, both the single and nested focus-reset regressions aborted with a misaligned `v8::Global<v8::Value>` pointer; the actual-process leak runs reproduced the same stack. Debug reproduced the single case's misaligned pointer and the nested case's segmentation fault in `v8_Context_Enter`, both reached from `resolveFinished` during delivery.

**Fix**: Move the existing wait decrement into the existing collection defer, immediately before `collect(internal)`. Collection already skips records with a nonzero wait count, so this extends the existing hold through commit, success and failure delivery without adding a new holder. The regression focuses a button with a focusable body, then starts an intercepted navigation from its blur handler; this reaches the bug independently of any new viewport-focus behavior.

Blink's [NavigateEvent::React and ReactDone](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/navigation_api/navigate_event.cc) bind the event into the promise reaction and then call `PotentiallyResetTheFocus` during delivery. Crane uses its own explicit record count to provide the corresponding lifetime.

**Takeaway**: **The reaction is still using its record while it calls script; release its hold when delivery returns, not when delivery begins.**
