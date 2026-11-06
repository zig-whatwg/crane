# Workflow: A remote run must outlive its caller's connection, and the caller must find it again

**Date**: 2026-11-06
**Lesson**: Run every pool job detached from the ssh session that started it, keyed by an id the caller chose. Then a dropped connection costs the caller a reconnect, not the job.

**Why**: The integrator's Mac drives the compute pool over ssh, and the Mac is a laptop on Wi-Fi. The user moves between rooms, and a handoff between access points can drop every open ssh connection. Two kinds of pool work met a drop differently:
- `crane-remote.sh` builds already survived it (2026-10-05): the remote helper ignores SIGHUP and SIGPIPE, and the job writes to a log. But the caller got ssh's exit status 255, not the job's status, and nothing on the Mac knew where to find the job again. A lane then had to read the log by hand and wait for a pid.
- `crane-pool.sh wpt` runs were the ssh session's own children (`exec ssh ... exec bash -c "$cmd"`), streaming to the caller. A drop killed the run unless its command happened to use `nohup`. This is why windows had been written as one `nohup` host script (workflow-a-sleeping-mac-starts-no-next-job-run-a-window-as-one-host-script.md).

**What Happened**: The user pointed out the Wi-Fi handoffs (2026-11-06). The Mac reaches chat.local by its IPv6 link-local address on the Wi-Fi interface (`fe80::...%en0`). Its ssh config had no keepalive tuning, so the defaults applied: TCPKeepAlive yes and no ServerAlive probes.

**Fix** (tmp/remote, installed atomically, each step tested by killing the user's `sshd-session` on the host mid-run, which is what a drop looks like from the host):
1. **The caller names the job.** It makes an id before it starts anything: `<UTC time>-<pid>-<random>`.
   - `crane-remote.sh` passes the id to the remote helper. The helper writes a record, `tmp/crane-remote-job-<id>` (the job's pid, its own pid, and the log), and after the job, `<record>.rc`.
   - `crane-pool.sh wpt` starts the run detached: `( trap '' HUP; bash -c CMD ) < /dev/null > log 2>&1 &`, with all three fds redirected so the session can close. The run writes `tmp/crane-pool-run-<id>.log`, then `.rc`. A `.started` marker made before the launch makes a retried start idempotent.
2. **On ssh's 255, reattach, never re-run.**
   - `crane-remote.sh` polls the record every 15 s for up to 24 h. It sees DONE (prints the log, exits with the job's status), RUNNING, GONE (no status: killed) or NOJOB (never started: the caller may run it again).
   - `crane-pool.sh wpt` follows the log by byte offset. The local side `tee`s what it receives into a copy and, after a drop, asks the host for the bytes from that copy's size on. Nothing prints twice or goes missing (test: 25 lines, cut at line 8, all 25 exactly once, exit status 5).
3. **Cancelling stays deliberate.** INT or TERM to the local `crane-pool.sh` kills the run's process tree on the host (exact pids, found by pgrep). The follower runs in the background under `wait`, because bash runs a trap only after the foreground command ends: the first version took a full run's length to cancel. A crane-remote job still stops only with a kill on the host.
4. **The ssh config rides out a short outage.** For chat.local and chat2.local: ServerAliveInterval 15, ServerAliveCountMax 8, TCPKeepAlive no, ConnectTimeout 15, ConnectionAttempts 3. Copies (rsync, scp) retry up to six times.
5. **Waiters loop short checks.** A waiter is `until ssh ... 'test -e X'; do sleep 30; done`, never one long ssh session, and it reads ssh's 255 as "the connection dropped, check again", never as the job ending.

**Takeaway**: **A job's life must not depend on the connection that started it, and its caller must be able to find it again: name the job before starting it, record its status on the host, and turn ssh's 255 into a reattach - resuming output at the byte where it stopped - never a re-run or a failure.**
