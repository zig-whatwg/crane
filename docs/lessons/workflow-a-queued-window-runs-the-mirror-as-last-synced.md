# Workflow: A queued window runs the mirror as last synced

**Date**: 2026-11-23
**Lesson**: `crane-pool.sh queue <host> <mirror> ...` does not copy the worktree to the mirror. The window runs its command in the mirror exactly as the last crane-remote job left it. A script, patch or suite written after that sync is not there. Sync the mirror with a crane-remote job first, check that the files exist in the mirror, and only then queue the window.

**Why**: crane-remote.sh copies the worktree one way to `<host>:~/crane-work/<mirror>/` each time it places a job. A queued window is handed the host by the keeper later and runs in the mirror as it stands. It never syncs, and the queue command never reads the worktree. Any file that came into being between the last crane-remote job and the queue is missing.

**What Happened**: Lane mem1 built its cost consoles with a crane-remote job on mirror mem1-c (chat.local). It then wrote three new files: `.mem1/roffwin.sh` (an attribution window: build one more console, then run a cost pair), `.mem1/roff.patch` and `.mem1/perf-rs/`. It queued the window `TIP=... bash .mem1/roffwin.sh`. The window waited 25 minutes for chat.local to drain, started at 1:43 AM ET, and exited at once with rc 127: ".mem1/roffwin.sh: No such file or directory". A no-op crane-remote job (`ls` of the three files) synced the mirror and showed the files present. The re-queued window landed behind another lane's window. In all, about an hour of a timed host went by with nothing measured.

**Fix**: Before queuing a window whose command uses anything new, run one crane-remote job on the same mirror that lists those files:

```bash
crane-remote.sh <mirror> 'ls .lane/new-window.sh .lane/new.patch .lane/suite/suite.json'
crane-pool.sh queue <host> <mirror> <kind> --est N '<command>'
```

The listing is both the sync and the check. Also, do not change the worktree's files, or switch its branch, while a crane-remote job is waiting for placement. That job syncs when it is placed, not when it is queued.

**Takeaway**: **A window runs what the mirror held at the last crane-remote sync, not what the worktree holds now. Sync and list the files with a crane-remote job, then queue.**
