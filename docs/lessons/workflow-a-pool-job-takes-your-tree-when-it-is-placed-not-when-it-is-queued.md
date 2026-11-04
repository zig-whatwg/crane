# Workflow: A pool job takes your tree when it is placed, not when it is queued

**Date**: 2026-11-04
**Lesson**: crane-remote.sh syncs the worktree to the mirror only once the job is placed on a host - after any wait for a build slot or for the mirror's lock - and prints the job's own output only when it ends; the line `job pid N on <host>` is the moment the tree was taken.

**Why**: Placement waits on the Mac (no slot anywhere, or another job of the same mirror holding its lock), and the rsync runs after it. Every edit made before that line is in the job; every edit after it is not - whatever the order of the commands that queued them.

**What Happened**: Lane compiletime1 queued a RED run with stubs in place while chat.local was closed, then had to keep the stubs on disk for 15 minutes until it was placed. Later, a GREEN run queued behind the RED one (same mirror) was placed - and synced - within a second of RED's end; a one-line fix made a few seconds later missed it, and the whole run (dom, v8, css builds) failed on the error the fix removed and was cancelled.

**Fix**: Before restoring files after a RED run or editing for the next run, wait for `job pid` in the job's output (`until grep -q "job pid" out; do sleep 3; done`); queue the next run only once the tree holds everything it should test.

**Takeaway**: **The tree a pool job tests is the one on disk at `job pid N`, not at the command: keep RED stubs until that line, and finish an edit before queuing the run that needs it.**
