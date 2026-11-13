# Workflow: A queued pool build copies the worktree when it is placed, not when it is queued

**Date**: 2026-11-11
**Lesson**: `crane-remote.sh` copies the worktree to the host only once a build slot is free. A base build queued from the lane's own worktree builds whatever that worktree holds by then, so build a base from a clean worktree of its own.

**Why**: crane-remote claims a slot first and then runs `rsync -a --delete` of the worktree's git top level to the mirror (crane-remote.sh, after "placed on"). While every slot is busy, the job waits on the Mac with nothing copied. The mirror has no `.git` either, so a script on the host cannot check which commit it was handed.

**What Happened**: Lane nd2 batch 3 queued the shared base's release console (fe2043efb6e, the merge point) from its own worktree as its first step, as the brief asked ("build in the pool before changing anything"). Every macOS slot was busy and both other hosts were closed for timed windows, so the job waited. Meanwhile the lane committed its red tests and began the implementation in the same worktree. The job would have built the tip and frozen it as the base. The build script's guard (`git rev-parse HEAD` against the base SHA) could not catch it: on the mirror there is no repository, so it would have refused every run, including a correct one. The queued job was cancelled before it was placed. The base was then built from a detached worktree at fe2043efb6e (`git worktree add --detach .claude/worktrees/nd2-base fe2043efb6e`, run crane-remote from there with the lane's macOS mirror, so the cache is shared), and that worktree was removed once the binaries were frozen.

**Fix**:
1. A build that must be of a fixed commit (a base, a frozen generation) runs from a worktree checked out at that commit, never from a worktree that is being edited.
2. Reuse the lane's mirror name for it: the mirror's cache serves both trees, and the next tip build resyncs the mirror.
3. Write the commit into the frozen directory's README on the Mac side; the host cannot read it from the tree.
4. Remove the extra worktree as soon as its binaries are frozen.

**Takeaway**: **A queued crane-remote job builds the worktree as it is when a slot frees, not as it was when you queued it: build a fixed commit from a clean worktree of its own.**
