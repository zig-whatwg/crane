# Workflow: A sleeping Mac starts no next job - run a window as one host script

**Date**: 2026-11-04
**Lesson**: A timed window whose steps are chained from the Mac - job 1, read the result, start job 2 - stops between jobs whenever the Mac sleeps: the host finishes the running job and then sits idle and closed to everyone else until the Mac wakes.

**Why**: The pool's jobs run on the hosts and survive a dropped connection (crane-remote's helper ignores SIGPIPE), so the work in flight is safe. But everything that STARTS work - the lane's next crane-remote call, the background command waiting for a job's end, the closing-notice watcher - runs on the Mac. With the Mac asleep, none of it runs; the ssh sessions drop when it sleeps ("Connection to chat2.local closed by remote host", "client_loop: send disconnect: Broken pipe"), and the waits return only after it wakes.

**What Happened**: Lane onebin2's measurement window held chat2.local closed for it. Job 1 ended on chat2 at 08:48 UTC. The integrator's Mac was in Low Power Sleep on battery from 08:19 to 12:15 UTC (pmset log), so the lane's wait returned at 12:16, and job 2 started at 12:18: chat2 sat idle and closed for three and a half hours. Nothing on chat2 hung.

**Fix**:
1. Write the window's WHOLE plan as one host-side script, with its decisions inside it (a step that depends on an earlier one's result reads that result itself), and start it as one job: the host then works through the plan whether or not the Mac is awake.
2. Give the script an end line in its results file (`=== window done ...`), and wait on that through `crane-pool.sh on <mirror>`, so a late wake still finds the right state at once.
3. Before a long window, check the Mac will stay awake (on power, or `caffeinate -s` for the window's length), and say in the window's START line when the plan has a step that waits on the Mac.

**Takeaway**: **The host keeps working while the Mac sleeps, but only on what it was already given: give a timed window its whole plan in one job.**

**2026-11-06, again (lane perf1)**: one host script is not enough when it is started by `crane-pool.sh wpt`. That job's script is a child of the ssh session, unlike crane-remote's helper. The Mac slept on battery from 06:44 to 10:19 UTC; the session's "Connection reset by peer" killed window.sh (pid 90231) with SIGHUP. Its two A/B sweeps, background subshells, finished at 06:58. The steps after them (comparison, timers, leaks, the perf window) never started, and chat.local sat closed and idle for 3.5 hours. The fix: start the window's script with `nohup bash <script> > <log> 2>&1 < /dev/null &` from `crane-pool.sh on <mirror>`, so it is re-parented to launchd and outlives any connection, and wait on its end line in the log with a retrying `crane-pool.sh on` loop (tmp/plans/perf1-scripts/resume.sh and resume-wait.sh). A finished step's results stay on the host: resume from them, never rerun.
