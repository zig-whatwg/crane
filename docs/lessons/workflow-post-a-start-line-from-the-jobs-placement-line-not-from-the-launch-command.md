# Workflow: Post a START line from the job's placement line, not from the launch command

**Date**: 2026-11-17
**Lesson**: A launch command that waits for the pool's "job pid" line and then posts START must post only when that line was seen; one that posts after its wait timed out records a job on a host that the job is not on.

**Why**: `crane-remote.sh` places a build job only when its host has a free build slot. Until then the launcher waits on the Mac ("no room for <mirror> yet ...; queued") and nothing of the job exists on the host. `tmp/plans/held-files.md` is what the integrator and the other lanes read to know what occupies a host, so a START line there is a claim about the host, not about the launcher.

**What Happened**: Lane vm1 launched a build job for mirror vm1-c2 (pinned to chat2.local) at 6:04 AM ET in one command: start the launcher in the background, loop up to 120 s for "crane-remote: job pid" in the job's out-file, then `post.sh START ...`. Both of chat2.local's build slots were held by two other lanes' jobs. The loop ended at its bound, the command went on, and held-files.md got "START (vm1, 6:06 AM ET, chat2.local): UNTIMED build job in mirror vm1-c2 ..." for a job that was queued on the Mac. The command's exit status was 0. The out-file said "queued"; reading it one minute later showed the line was false, and a CORRECTION note followed. That launch never got a slot: it was withdrawn at 6:12 AM ET, queued again at 6:15 AM ET and placed at 6:20 AM ET, when its START line was posted by a waiter that had seen the pid line.

**Fix**:
1. Launch and post in separate steps. After the launch, wait for one of the job's terminal placement states in its out-file: `crane-remote: job pid` (placed) or `^\[run-job [0-9:]+\] rc=` (the launcher ended without placing it).
2. Post START only in the branch that saw the pid line, and put the pid in the line. In the other branch print "NOT PLACED" and post nothing:
   ```bash
   until grep -qE 'crane-remote: job pid|^\[run-job [0-9:]+\] rc=' "$out"; do sleep 15; done
   if grep -q 'crane-remote: job pid' "$out"; then post.sh START <host> "PLACED NOW ($(grep -o 'job pid [0-9]*' "$out" | head -1)) ..."; else echo "NOT PLACED"; fi
   ```
3. A line already posted wrongly is corrected with a NOTE line that names it by its time; held-files.md is appended to, never edited.
4. A queued launch locks the worktree until it is placed (the copy is made at placement: lesson "A pool job builds the worktree as it is when the job starts"). To use the worktree sooner, end your own waiting launcher by its exact local pid (a launch that is still queued is a local process only - `pool_place_build` in tmp/remote/pool-lib.sh waits on the Mac - and it gives up nothing of anyone else's when no other ticket waits), then check that its ticket in `tmp/remote/pool/build-q/` and its lock in `tmp/remote/pool/locks/` are gone before you edit anything.

**Takeaway**: **A bounded wait has two ends, and only one of them is the event. Post what happened from the line that says it happened, never from the fact that the wait is over.**
