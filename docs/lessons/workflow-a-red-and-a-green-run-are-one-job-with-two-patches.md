# Workflow: A red and a green run are one job with two patches, so the worktree stays free

**Date**: 2026-11-15
**Lesson**: A pool job builds whatever the worktree holds when its slot comes, so prove red and green in ONE job that carries two patches - synced tree to the step's green tree, green tree to the red commit - instead of holding the worktree still for a job per tree.

**Why**: crane-remote.sh syncs the worktree when the job is placed (lesson workflow-a-queued-remote-job-builds-the-mirror-as-its-slot-finds-it.md). A lane agent has one worktree and no `git stash`, and a red run needs the tree of an OLDER commit than the one being edited. Each "wait for the job pid line before the next edit" costs the minutes the queue takes, twice per step.

**What Happened**: Lane nm2's first red run was submitted at the red commit and the sources of the fix were re-applied while the job was still syncing to server1 (a slow first sync: 15 minutes): the mirror held a mix of both trees and the job had to be stopped. The next jobs took the patches with them: `.nm2/redgreen.sh` applies `GREEN` (`git diff -R -- src tests`: worktree back to what is staged), then the red patch (`git diff --cached -R -- src tests`: staged back to HEAD, the red commit), runs the red filters and expects a failure, reverses the red patch, runs the green set, and reverses `GREEN`. `git apply` works in a mirror with no `.git`. Steps a and d of the batch were proven that way while the worktree already held the next step's edits.

**Fix**:
1. Commit the red tests. Stage the step's sources; leave later work unstaged.
2. `git diff -R -- src tests > .lane/to-green.patch` and `git diff --cached -R -- src tests > .lane/to-red.patch` (both apply to the worktree as the sync will copy it: check with `git apply --check`).
3. One job: apply green, apply red, run the red filters (must fail), reverse red, run the green set (must pass), reverse green. Exit 0 only for fail-then-pass.
4. Do not edit `src/` or `tests/` between submitting the job and its "job pid" line: the patches were cut from the tree as it was.

**Takeaway**: **Carry the trees to the job as patches against whatever gets synced; one job then proves red and green, and the worktree is free again at the "job pid" line.**
