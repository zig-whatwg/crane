# Spec Compliance: A result the spec hands over from onComplete arrives in a task

**Date**: 2026-09-26
**Lesson**: HTML's fetch algorithms deliver a script's result through onComplete, which marks the script ready from a queued task - even when this engine's fetch is synchronous.

**Why**: Running script-inserted scripts inside `appendChild` put their execution before the rest of the inserting script, where no browser runs it.

**What Happened**: About 60 execution-timing subtests failed on ordering, and pages waiting on `onload` after `appendChild` hung because the load event fired before the listener existed.

**Fix**: Script-inserted and module scripts are marked ready from a queued task that keeps the element's wrapper alive until it runs (lane/scripting 7e18ea8e4).

**Takeaway**: **A synchronous fetch does not make the spec's task synchronous; deliver the result where the spec does.**
