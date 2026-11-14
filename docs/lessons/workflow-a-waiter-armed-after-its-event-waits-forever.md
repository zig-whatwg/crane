# Workflow: A waiter armed after its event waits forever - read the current state before you wait for the change

**Date**: 2026-11-13
**Lesson**: A background command that waits for a NEW line in a log (a host's "GAP OPEN", a job's "rc=") only sees lines written after it started. If the event has already happened, it never fires, and nothing says so: the work chained behind it simply does not start.

**Why**: Lane wrap1 batch 2 ended its A/B window on server1, posted its END line, and chained its next job behind "wait for server1's GAP OPEN line". The integrator answered the END within seconds; its GAP OPEN line was already in the file when the waiter recorded the line it would start reading from. The waiter sat for 39 minutes on an open host. The same batch's watcher for closing notices had the mirror image of the fault: it compared a window's owner label with the mirror names it knew, the integrator wrote the lane's bare name, and the watcher took the lane's own window for another lane's (it was stopped before it acted).

**What Happened**: Found only when another window ended and the lane looked for the job's output. The fix was to stop the waiter, read the host's state (`crane-pool.sh status`: open) and start the job.

**Fix**:
1. Before arming a waiter for a state change, read the state itself (`crane-pool.sh status`, the last notice line for the host). Wait only if the state is still the old one.
2. Give a waiter a deadline that wakes you with "nothing seen", so a missed event costs minutes, not the rest of the window.
3. Match an owner by the lane's name and by every mirror name, and ask the integrator to write the mirror's exact name in a window notice: `crane-pool.sh` compares the owner with the mirror name exactly.

**Takeaway**: **Wait for a change only after reading that it has not happened yet, and never without a deadline.**
