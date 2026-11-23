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

**Addendum (2026-11-23, lane mcp1)**: the same holds for a plain crane-remote job that has to wait. A gate submitted at 3:00 PM ET sat queued behind three hosts' windows and synced the worktree only when it was placed, at 3:30 PM ET. In between the lane had committed the next batch's red test into the same worktree and reverted its fix files for a red run. The gate therefore ran batch 1's code plus a red test from batch 2, and its test step failed on that test. The gate script's tree stamp (`.cdpd1/tree.head`, written at submission and copied with the tree) did not catch the mix: a stamp written before the sync says nothing about what the sync copies. So commit nothing into the worktree, and edit nothing in it, while a job for its mirror waits. Do the next batch's work in a second worktree. A job whose mirror's home host is in a window can also be refused at placement ("not running ... Retry after GAP OPEN"), so read its log for `job pid` before you count on it.

**Takeaway**: **A window runs what the mirror held at the last crane-remote sync, not what the worktree holds now. Sync and list the files with a crane-remote job, then queue. A waiting crane-remote job syncs when it is PLACED: commit nothing into the worktree while one waits, and use a second worktree for the next batch.**
