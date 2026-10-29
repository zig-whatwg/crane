# Workflow: A pattern kill stops the step, not the job

**Date**: 2026-10-29
**Lesson**: A STOP watcher that kills a remote job by matching its children's command lines (`crane-work/<mirror>/`, `crane-caches/<mirror>/`) kills the step that is running, and the job's own shell - whose command line matches none of them - starts the next step.

**Why**: A crane-remote job is `bash -s -- <mirror> '<cmd>'` on the host. When `<cmd>` is a loop or a `;` chain of builds, the zig processes carry the mirror's paths but the job shell carries only `bash -s -- <mirror> ...`. Killing what the pattern finds ends one `zig build` and returns control to the shell, which runs the next command of the chain.

**What Happened**: Lane rendering2's watcher (copied from another lane's) fired at the 06:41 CLOSING NOTICE for chat.local, printed "killed", and the job went on: its `for t in ...; do zig build test $t; done` moved from the killed html test to `-Dspec=v8` and then `-Dspec=dom`, compiling on a host closed for a timed window, until the lane killed the job shell by its exact pid (the one crane-remote prints: "job pid N on <host>").

**Fix**: Kill the job shell first - its exact pid from crane-remote's "job pid N" line, or the pattern `^bash -s -- <mirror> ` - then the children; and check with pgrep that nothing of the mirror is left before posting PAUSED.

**Takeaway**: **Stop a multi-step remote job at its shell (the pid crane-remote prints), not at the step that happens to be running - and verify with pgrep before saying it stopped.**
