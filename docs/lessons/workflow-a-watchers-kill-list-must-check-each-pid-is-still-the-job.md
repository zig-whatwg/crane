# Workflow: A notice watcher's kill list must check that each pid is still the job

**Date**: 2026-11-07
**Lesson**: A lane's CLOSING NOTICE watcher kills the pids it recorded for its jobs on the noticed host; a pid left on the list after its job ended can belong to anything once the OS reuses it, so the watcher must confirm the pid's command before every kill and drop a pid the moment its job ends.

**Why**: The watcher (tmp/scratch/<lane>/watch.sh, from the shared template) reads `<host> <pid>` lines and kills each pid's process tree on the noticed host through `crane-pool.sh on`. Nothing tied the number to the job: a finished job's pid stayed on the list until someone edited the file, and macOS reuses pids. The kill runs `kill -TERM` on the pid and every child `pgrep -P` finds, so a reused pid would take a stranger's process tree with it - another lane's gate, a window's runner.

**What Happened**: Lane perf2's batch 3 recorded its window 1 script (pid 29788 on chat.local). The window ended at 03:56 UTC. At 04:02 a CLOSING NOTICE for chat.local (coi2's window) fired the watcher, which still listed 29788 and sent the kill. `ps -p 29788` on chat.local showed no process, so nothing was hit - by luck, not by design. The integrator made the check a rule for every lane's brief.

**Fix**:
1. Record a command substring with each pid: `<host> <pid> <substring>` (the job script and its argument, e.g. `gate-pre.sh 73f991ffd98`).
2. Before every kill, read `ps -o command= -p <pid>` on that host (through `crane-pool.sh on <mirror>`) and kill only when it still contains the substring. A pid with no substring recorded, or one whose command no longer matches, is skipped and reported.
3. Remove a job's line when the job ends - in the same step that reads its result.
4. Edit a running watcher atomically: write the new script beside it, `bash -n` it, `mv` it into place, then restart the watcher (bash reads a running script as it goes).

**Takeaway**: **A pid is a job only while it runs: a kill list records what each pid was, and every kill first checks that it still is.**
