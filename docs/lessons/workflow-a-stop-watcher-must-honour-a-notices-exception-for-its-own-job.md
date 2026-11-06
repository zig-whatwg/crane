# Workflow: A STOP watcher must honour a notice's EXCEPTION for its own job - and its kill outlives the watcher

**Date**: 2026-11-06
**Lesson**: A CLOSING NOTICE for chat.local made an exception for lane loadpath1's running PRE gate ("EXCEPTION: loadpath1's RUNNING PRE gate (job 47344) keeps running to its end"). The lane's watcher read only the notice's header host, as it was written to, and within its 20 s poll killed every listed job on that host, the exempt gate included.

**Why**: The watcher matched the host in the header and nothing else. A notice's body can spare a job by name, and the watcher had no way to read that. Its kill also runs as its own ssh command. Killing the watcher script a few seconds later, once the lane read the integrator's message, did not stop the kill already sent: the gate died after the watcher did (RR_EXIT=143, 26 minutes into it, at its zig build test step).

**What Happened**: The lane read the integrator's message ("your RUNNING PRE gate is EXEMPT: don't let your watcher stop it") and killed the watcher at once. The STOP file was already there, and the in-flight `crane-pool.sh on ... kill` took the gate's tree anyway. The gate was rerun on chat2 at the next tip.

**Fix**: tmp/loadpath1/watch-closing.sh:
1. A notice whose text holds "EXCEPTION: <lane>" kills nothing automatically: it sets STOP, so the lane starts nothing new, and logs the jobs it would have killed; the lane stops the non-exempt ones by hand.
2. An `exempt-pids` file lists pids the watcher never kills.
3. Restart the watcher after editing its script: bash reads a running script as it goes (edit-running-scripts-atomically).

**Takeaway**: **A watcher that kills on a notice must parse the notice's exceptions for its own jobs before it kills anything, and once it has sent a kill, killing the watcher does not take the kill back: read every notice's EXCEPTION line in the watcher, not in the lane.**
