# Workflow: A waiter on a crane-remote job's log must also end when the log is renamed

**Date**: 2026-11-19
**Lesson**: When a job ends, crane-remote prints the job's log in the mirror (`tmp/crane-remote-<pid>.log`) and renames it to `.log.printed`. A waiter on the pool host that loops `until grep -q <marker> <that .log>` never sees the marker if the job ended between two of its checks. It then loops on a missing file for good, holding an ssh session open and leaving a process on the host.

**Why**: `crane-remote.sh` keeps the log after printing it: `cat "$job_log"; mv -f "$job_log" "$job_log.printed"`. It is pruned after three days. A `grep` on the old name fails the same way whether the marker has not come yet or the file is gone, so the loop cannot tell the two apart.

**What Happened**: Lane maj2 waited on server1 for its Linux gate (`until grep -qaE "GATE STEPS|GATE FAILED|^rc=" .../crane-remote-82489.log; do sleep 60; done`). The gate ended green at 1:34 PM ET, and the local go log had its `rc=0`, but the remote loop was still running 25 minutes later (pid 125651) on a file that no longer existed. It was killed by its exact pid.

**Fix**:
1. Wait on the LOCAL log first: the go/crane-remote caller's own output gets the job's whole log and an `rc=` line when the job ends.
2. To catch a step inside a long job (a freeze before its tests), wait remotely, but end on the renamed file too: `until grep -qaE "<marker>" "$L" 2>/dev/null || [ -e "$L.printed" ]; do sleep 60; done`, then read `$L.printed` if `$L` is gone.
3. Before you report, check the pool hosts for your own waiter processes (`pgrep -af <log name>`) and kill them by exact pid.

**Takeaway**: **A remote waiter on a crane-remote job log must also stop when `<log>.printed` appears; otherwise it outlives the job forever.**
