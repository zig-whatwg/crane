# Workflow: A waiter must watch an event that is sure to come - crane-remote deletes the remote log when its follower goes

**Date**: 2026-11-23
**Lesson**: A background waiter must wait for an event that is guaranteed to happen, and it must also exit when the thing it waits for can no longer happen. Waiting for a line to appear in a crane-remote job's remote log is not safe: once the local follower is stopped, the job's log is deleted at its end and the line never comes. Wait on the local follower's exit, a pool queue-wait, or a file the job itself leaves behind, such as the gate's `tmp/gate/*.log`. Give every polling loop a deadline.

**Why**: crane-remote prints a pool job's output when the job ends, through its local follower, and the remote `tmp/crane-remote-<pid>.log` does not outlive the job. A waiter that polls that file for a marker spins forever if the follower was stopped, and an agent waiting for its notification goes idle with it.

**What Happened**: Lane hard1 stopped the local follower of a stale macOS gate (26a672107) but let the remote job finish: it was in its last TSAN step, and killing it mid-sync was unsafe. A background `until ssh ... grep -q "== done" ~/crane-work/hard1-c/tmp/crane-remote-1443.log` was meant to report the end. The job ended about 1:17 PM ET and its log was deleted. The loop's `grep` failed forever on a missing file, and the lane sat idle until the integrator's next message at 6:53 PM ET: about five and a half hours. The gate's own logs (`tmp/gate/test.log`, `verify-tsan.log`) were on the host the whole time.

**Fix**:
1. Wait on what is certain to happen: the local crane-remote follower's exit (run it with `run_in_background`), `crane-pool.sh queue-wait` for a window, or a file the job writes and keeps, such as a gate step's log. Never wait on a file the tooling deletes.
2. Every poll loop also exits when its subject is gone: the remote process is no longer running (`pgrep` on the host), or a deadline passes. Then it prints what it found.
3. Never stop a job's follower and keep waiting on that job. Either let the follower run, or read the job's lasting outputs once.

**Takeaway**: **Wait for an event that is sure to come, and exit when it can no longer come. A crane-remote job's remote log dies with the job when its follower is gone.**
