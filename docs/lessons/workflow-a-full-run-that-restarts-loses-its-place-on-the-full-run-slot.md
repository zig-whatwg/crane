# Workflow: A full run that restarts loses its place on the host's one full-run slot

**Date**: 2026-10-29
**Lesson**: A full run that stops gives up the host's full-run slot when it stops. Its relaunch joins as a new waiter and races every run that was already waiting.

**Why**: `crane-measure.sh sweep` holds a host's one full-run slot (rule 16) with a pid file in
`~/crane-fullrun/`. The slot is free the moment the last process of the holding group exits.
Waiting sweeps poll every 15 seconds and take the slot through a `mkdir` mutex. There is no queue,
and nothing is reserved for a run that means to come back. A relaunched run is just one more poller.

**What Happened**: Lane leaks1's full A/B (group leaks1-full2) held chat.local's slot from 10:19
UTC. The generation 194 sweep had been waiting behind it since 10:56. At 11:56 UTC the A/B's sweeps
ended and were relaunched at once:

- Generation 194 joined at 11:56:30.
- The relaunch reached `fullrun_join` at 11:56:46, sixteen seconds late, and waited out the whole
  65-chunk sweep (ended 12:41:54).
- At 12:41:54 it lost the next race too: refcount8's run joined ten seconds after generation 194
  ended.
- Meanwhile the relaunch had been started in the foreground of `crane-pool.sh wpt`, which runs the
  command inside its ssh session. When that connection reset at 12:07, the waiting relaunch died
  with it.

Half a full run's chunks were done, and the lane still lost about 50 minutes before running another
one.

**Fix**:
1. Do not stop a full run that holds the slot just to change it. If a change is unavoidable, start
   the replacement first, in the SAME group. That group is the `--pair` id crane-pool passes as
   `CRANE_POOL_PAIR`, or the label without its last `-part`. Members of one group run together, so
   the replacement joins at once, and the slot never frees when you stop the old run.
2. Launch every full run detached, in a tmux session on the host:
   `crane-pool.sh wpt <mirror> --full --pair <id> 'tmux new-session -d -s <name> "export PATH=$PATH ...; bash <script>"'`.
   Wait for it with one local background command that checks a done file. A run in the ssh
   foreground ends when the connection does.
3. Give a run that must not share the slot with another lane a group of its own. Set
   `CRANE_POOL_PAIR` explicitly in the tmux command. Under `--pair generation`, every lane that
   passes the pair through gets the same group, `generation`, and would start alongside the others.
4. `crane-measure` keeps every chunk that ended with rc 0 when a sweep resumes, so a resumed run
   loses only its place in the slot, never its done chunks.

**Takeaway**: **The full-run slot is held by live processes, not by a reservation. Stopping a run
gives the slot to the next poller, so start any replacement in the same group before stopping the
old run, and run it in tmux so a dropped connection cannot stop it.**
