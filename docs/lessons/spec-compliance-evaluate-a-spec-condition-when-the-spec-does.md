# Spec Compliance: Evaluate a spec condition when the spec does

**Date**: 2026-09-26
**Lesson**: Form submission's "has not completely loaded" was checked inside the queued task, not at submit time.

**Why**: A queued task runs after the event that queued it has finished, and the world has moved on by then.

**What Happened**: An onload handler calling `form.submit()` returned, loading completed, and the queued navigation then saw a loaded document - so it pushed a history entry where the spec replaces it.

**Fix**: Record the condition when `submit()` runs and carry it in the task (lane/navigation fd6970706).

**Takeaway**: **A queued task sees the world after the event that queued it; record what the spec reads at the moment it reads it.**
