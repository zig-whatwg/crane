# Workflow: Red and green in one pool job - swap the base's files in the mirror, not the worktree

**Date**: 2026-11-18
**Lesson**: Prove a new test red at the base inside the pool job itself: ship the base's copies of the changed files with the tree, put them over the mirror's files for the red build, then put the tip's back for the green one.

**Why**: A pool job builds whatever tree its mirror was synced from at placement, and a busy pool can hold a
job in the queue for an hour (lane net2, 2026-11-18: 59 minutes on chat2 behind two other lanes' gates). The
shared stash stack is refused by the guard hook (every worktree shares it), and reverting the worktree's
`src/` to the base until the job is placed blocks every edit for as long as the queue lasts.

**What Happened**: Lane net2 reverted its `src/` changes from a patch so a red run of its new native test would
build at the base, and queued the job. After 10 minutes of queue it cancelled the job, restored the tip, and
made the red half part of the job instead.

**Fix**: `.net2/redgreen.sh <spec> <test-file>` (lane-only script, synced with the tree):
1. In the worktree, `git show HEAD:<file> > .net2/base/<file>` for every changed file, and list the new files in
   `.net2/base.new`.
2. In the job: tar the tip's versions of those files, untar `.net2/base/` over the tree, delete the new files,
   build and run the test (RED), untar the tip back, build and run it again (GREEN).
3. The mirror's next sync (rsync --delete) restores whatever the worktree holds, so nothing of the swap
   outlives the job. One slot, one queue wait, and the worktree stays editable throughout.

**Takeaway**: **The red build belongs in the job, not in the worktree: ship the base's copies with the tree
and swap them in the mirror, so a long queue never freezes your editing.**
