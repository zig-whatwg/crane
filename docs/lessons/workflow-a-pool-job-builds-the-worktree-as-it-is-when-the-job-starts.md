# Workflow: A pool job builds the worktree as it is when the job STARTS, not as it was when you queued it

**Date**: 2026-11-15
**Status** (2026-11-16, lane wrap2): "when the job starts" is not an instant. The copy into a new mirror took minutes (the job started eleven minutes after it was placed), and commits made inside it gave the mirror a mixed tree: [the worktree must not change until the job prints its pid](workflow-the-first-copy-into-a-new-mirror-takes-minutes-the-worktree-must-not-change-until-the-job-prints-its-pid.md).
**Lesson**: `crane-remote.sh` copies the worktree to the mirror at the moment a job gets its build slot. A job queued behind another - a chain of diagnosis builds, a job waiting for a full host - takes whatever the worktree holds then, so an edit made while the queue runs is in every build that had not started yet.

**Why**: The sync is one way and happens once per job, right before the job's command runs (tmp/remote/crane-remote.sh). Nothing records which commit the mirror was synced from: the mirror has no `.git`, and a frozen directory's `BUILD_INFO` says what the script was TOLD the tree is. A chain that builds "main with patch 1", "main with patch 2", "main with patch 3" on a host with one free slot syncs three times, minutes apart.

**What Happened**: Lane dm3 queued three diagnosis consoles of main on chat2.local (one V8 flag each, about ten minutes a build, one slot) and then began the batch's code change in the same worktree. The first console had synced; the second and third had not. Built as queued, they would have been "main + a V8 flag + half of an uncommitted change to what V8 is told", labelled "main 2bdfc95a348" by their `BUILD_INFO`, and the table sent to the integrator would have compared them with a clean console of main. It was caught by reading the first job's start time against the first edit's, before the second job started: the edits were saved as a patch, the worktree put back to main's sources, and each remaining job's mirror was checked (`grep -c <a symbol of the change>` in the mirror: 0) after it had synced.

**Fix**:
1. Before queueing a job whose subject is a tree other than the one you are about to work on, decide where the other work happens: finish the queue first, or keep the worktree at the subject's sources until the LAST job of the queue has synced (its out-file prints `crane-remote: <mirror> placed on <host>` and the job's pid then).
2. A base build from a lane's worktree is made in the mirror with a reverse patch (`git diff HEAD <base> > .lane/to-base.patch`, applied by the job, reversed after), never by changing the worktree: the patch is part of what was synced, so the job cannot take a later tree. `git stash` is refused here (the stash stack is shared by every worktree).
3. After a diagnosis build, check the mirror, not the label: grep the mirror's source for one symbol that only the other tree has.
4. A `crane-pool.sh wpt` run does not sync at all. After changing a script the run needs, run a light `crane-remote.sh <mirror> 'ls <the script>'` first.

**Takeaway**: **The mirror is the worktree at the second the job starts. Keep the worktree at the tree a queued build is meant to be until that build has synced, and build any other tree from a patch that travels with the sync.**
