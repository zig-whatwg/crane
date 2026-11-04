# Workflow: A closing notice stops only the jobs on its host, and a job's whole process tree

**Date**: 2026-11-04
**Lesson**: The STOP watcher that lanes copy from one another (tmp/<lane>/watch-closing.sh) checks
whether any of its mirrors is on the noticed host, then kills EVERY job listed in remote-pids,
wherever it runs. And `crane-pool.sh on <mirror> 'kill <job pid>'` kills only the job's wrapper:
the script the job ran keeps going on the host, now outside its build slot.

**Why**: The watcher decides "fire" per mirror but kills per file. Once a lane has mirrors on two
hosts (a pinned one for a chat.local-only build, the usual one on chat2), a notice for one host stops
the other host's work too. The job pid that crane-remote prints belongs to the remote wrapper
(`bash -s -- <mirror> <cmd>`). Its child (the gate script) and that script's children (`zig build`,
the test launcher) are not in the kill. When the wrapper dies, crane-remote's cleanup releases the
build slot, but the build keeps compiling on the host.

**What Happened**: Lane sweepq1 had mirror sweepq1 on chat2 (its PRE gate, about to run
`zig build test`) and sweepq1-rel pinned to chat.local (a release build, already finished). The 19:42
chat.local CLOSING NOTICE fired the watcher because of sweepq1-rel, and the watcher killed the chat2
gate's job pid 59609. The lane's local crane-remote reported the job ended, but `pgrep` on chat2
found the gate script (59611) still running, with its `zig build test` maker, a `zig test` compile
and a test launcher with three test processes: a full test build holding no slot on a 2-slot,
memory-bound host. They were stopped by exact pids (the tree under 59611), and the gate's remaining
steps were queued again under a slot.

**Fix**:
1. In the watcher's kill loop, look up each listed mirror's host (`crane-pool.sh where <m>`) and kill
   only the jobs whose host the notice names; log the others as kept.
2. To stop a job, stop its whole tree on the host, by exact pids (never a broad `pkill -f`):
   ```bash
   crane-pool.sh on <mirror> 'tree() { echo $1; for c in $(pgrep -P $1); do tree $c; done; };
     pids=$(tree <script pid>); kill $pids'
   ```
   Then check with `pgrep -fl` for the mirror's cache path that nothing is left.
3. Drop a mirror from the watcher's list once its work is done. Otherwise every notice for its
   pinned host fires the watcher again.

**Takeaway**: **A notice is about one host: stop only that host's jobs, and stop a job's whole
process tree there. Killing the wrapper's pid leaves the build running without its slot.**
