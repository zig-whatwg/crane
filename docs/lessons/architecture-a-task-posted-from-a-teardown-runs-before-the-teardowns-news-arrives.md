# Architecture: A task posted from a teardown can run before the teardown's news arrives from another thread

**Date**: 2026-11-23
**Lesson**: When a teardown on one thread posts a task (a release, a flush) and the matching cleanup comes from ANOTHER thread that hears of the teardown later (a detach, an unregister), the posted task can run first. Under load it usually does. The task must check that its subject still exists when it runs, and must not count on the cleanup having happened.

**Why**: Posting order is per queue. The teardown's own task is queued at once, on the teardown's thread. The other thread's cleanup is queued only after a hop: an event posted, read and answered. Nothing orders the two, and a starved host stretches the hop.

**What Happened**: fw2's CDP test "a tab closed while it navigates..." failed once in a loaded gate. The held Runtime.evaluate was answered ("expected null, found 7"). Target.closeTarget closed the tab on the Browser thread, and that aborted its gated navigation. The abort's milestone posted the session's ReleaseTask (PageSession.scheduleRelease). The DetachTask came from the devtools thread, once it heard the target went. With two CPUs held by eight spinners, the release ran first in 36 of 40 runs, on a tab already gone, and the held command got an (error) answer. Chrome answers none: its held messages go to an agent that is going away, and ForceDetachAllSessions drops the rest.

**Fix**: ReleaseTask.run returns when the session's tab is no longer an open traversable (PageSession.tabGone). The held commands wait for the detach, which drops them unanswered. Starved, 0 of 40 runs failed (.cdpd1/flake.sh: the file's own executable, launched 40 times a side, the fix reversed and then applied).

**Takeaway**: **A task a teardown posts must re-check its subject when it runs. The cleanup another thread will post has not happened yet, and a starved host makes "yet" the common case. Prove such a fix starved, base against fix, with counts.**
