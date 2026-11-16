# Workflow: Copy a lane's tmp/ files out before removing its worktree

**Date**: 2026-11-15

**Lesson**: Before `git worktree remove` at a merge, copy every file the lane's report names under its worktree's `tmp/` into the main checkout's `tmp/plans/`.

**Why**: `tmp/` is ignored, and `git worktree remove` deletes ignored files with the tree without a warning. A lane's report often points at proposals, lists or evidence it kept there for the integrator.

**What Happened**: Lane quick2's merge report named two worklist proposals in its worktree (`tmp/quick2/scope-propose.txt`, 29 @scope files; `tmp/quick2/pe-candidates.txt`, 43 pointer and touch files). The integrator removed the worktree as the first cleanup step, then went to copy the lists: both were gone, and the server1 mirror that held the lane's journals had been deleted in the same step.

**Fix**: The lists are queued to be regenerated with a short run on main's runner. The merge cleanup checklist now starts with copying the report's named files out.

**Takeaway**: **Read the report's file list before cleaning up: a worktree's ignored files go with it.**
