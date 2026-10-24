# Workflow: Cancelling a remote wrapper can leave build children

**Date**: 2026-10-23
**Lesson**: Verify that a cancelled remote job's build and test descendants have exited before starting its replacement.

**Why**: Stopping a shell is not proof that every process it launched stopped. Orphaned children can keep compiling or testing after the wrapper has returned, violating a lane's one-job limit when its replacement starts.

**What Happened**: Row119 cancelled its already-failed CSS gate by sending TERM to the printed crane-remote job PID29168. The wrapper returned143, but ps and pgrep still showed its zig build29169, build runner29187, active test29515 and pipeline cat29170. The zig build and cat processes had been reparented to PID1. No replacement job had started.

**Fix**: Save the partial log and inspect the exact job's process tree. Stop only its confirmed remaining descendants; keep parent build runners from spawning more children during cleanup. Then check the recorded PIDs and the lane-specific pgrep output again. Row119 started its replacement only after that check was empty. Do not kill every Zig process or use another lane's cache path as a selector. This was cleanup of an observed cancelled job, not a change to crane-remote or its scheduler.

**Takeaway**: **A wrapper's exit is not the job's complete exit; prove that its own descendants are gone.**
