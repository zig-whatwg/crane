# Workflow: The first copy into a new mirror takes minutes - the worktree must not change until the job prints its pid

**Date**: 2026-11-16
**Lesson**: `crane-remote.sh` copies the worktree for as long as the copy takes - minutes for a new mirror (up to eleven on chat2.local, five on server1, each read from the "placed" line to the job's start) - and a commit, a `git reset` or an edit made in that time lands in the mirror file by file, so the job builds a tree no commit holds.

**Why**: The copy is one rsync pass over the worktree, started when the job gets its slot ("placed on <host>") and finished when the out-file prints `crane-remote: job pid N on <host>`. Each file is read at the moment rsync reaches it. Nothing compares the result with a commit: the mirror has no `.git`. The lesson "a pool job builds the worktree as it is when the job starts" covers a job that waits in a queue; this is the same hazard inside one job, and "the job was placed, so it has my tree" is false until the pid line.

**What Happened**: Lane wrap2 launched its first test job into a new mirror at 1:03 AM ET ("placed ... waited 3s") and, taking the copy for done, applied, committed, reset and re-applied the next change in the same worktree. The mirror's job file is stamped 1:14 AM ET. The mirror got the test file of the later commit and the source file of the earlier one; the build failed with "no member named 'map_shrink_floor'", which said nothing about the change under test. The handoff already said the copy had finished "before the two commits" - an inference from the launch time, written as a fact. The run was void, and stopping it cost a second mistake (a pattern kill on a shared host).

**Fix**:
1. Launch through a wrapper that refuses a worktree with uncommitted tracked changes and keeps a marker file from the launch until the out-file prints the job's pid line or the job ends (lane wrap2's `go.sh`: `COPYING-<label>`). No edit, commit, reset, merge or checkout while a marker exists - on a closed host that is until the job is placed.
2. Send the commit's identity with the copy: before the launch, write `shasum -a 256` of every file that differs from main into the lane's untracked script directory (it is copied too), and make every mirror-side script check it first and exit 2 on a mismatch.
3. Write what a job built from what the mirror shows, not from when it was launched.
4. `tmp/` is not copied and not cleaned: a log of an earlier run is still in the mirror. Read a step's result from the job's own output or check the log's time.

**Takeaway**: **A job has your tree when it prints its pid, not when it is placed. Lock the worktree until then, and let the job prove the mirror is the commit before it builds.**
