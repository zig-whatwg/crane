# Architecture: A waiting algorithm resumes once and restores its registration

**Date**: 2026-10-05
**Lesson**: Resuming an existing asynchronous algorithm needs its own transition, not just another callback with the same generation.

**Why**: A generation guards against obsolete work after a restart. It does not prevent two resumptions of the same waiting algorithm, nor distinguish a queued flag update from ending that algorithm's resources.

**What Happened**: After media source exhaustion, inserting two sources queued two stable-state callbacks. The second advanced past a candidate while the first was fetching. A resumed load also stayed outside the live registry, so it failed to delay document load. An earlier queued delay-release task called the full finish path and terminated the new fetch. Three Crane tests respectively timed out, observed early window load, and timed out.

**Fix**: Coalesce same-generation pending resumptions, restore live registration before resuming, and make the queued delay task change only its specified flag. It removes the registry entry only if the algorithm is still waiting and has no active fetch. Keep separate tests for simultaneous insertions, a released then restored document delay, and resumption before an older task runs.

**Takeaway**: **A load generation identifies an algorithm; it does not identify its current phase or make every same-generation cleanup safe.**
