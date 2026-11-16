# Workflow: A second run that names the worklist restarts wpt serve under the first

**Date**: 2026-11-15
**Lesson**: Inside your own closed window, `crane-pool.sh wpt` gives a FULL run a fresh `wpt serve`, and it takes any command that names the 0.1 worklist for a full run. A second such command, started while another run of yours is going, stops the server under that run.

**Why**: tmp/remote/crane-pool.sh restarts the host's `wpt serve` before a full run in the mirror's own window (the browsers' way: wptrunner starts its servers per run). "Full" is `--full` or a command whose text names the worklist file. The rule assumes the window's owner starts one run at a time.

**What Happened**: In lane flk1's window on server1 the targeted A/B was running its verify step when I started an extra run beside it, whose command built its list with `grep ... tests/wpt_0_1_worklist.txt`. crane-pool printed "a fresh wpt serve for this window run" and restarted the server. For about a second every connection was refused: seven `curl error 7 ... ConnectionRefused` lines in the verify log, one run of a Crane test ended ERROR, and verify said UNSTABLE for a test that was stable. The restart was mine, the "flake" was mine, and it cost a rerun inside a 15-minute window. I then cancelled the extra run at the window's end and deleted its directory with the rest of the window's output before reading what it had already journalled, so its partial counts were lost and the question it was to answer needed a window extension.

**Fix**:
1. One run at a time through `crane-pool.sh wpt` in your own window, or pass `CRANE_FRESH_SERVE=0` for every run after the first.
2. Build lists from the worklist in a script file, so the command line does not name it; say `--full` when you mean a full run.
3. A `ConnectionRefused` burst in a WPT log is the server going away: check `ps -o lstart` of `wpt.py serve` against the log's time before reading it as the engine's.
4. When a run is cancelled, read its journals before deleting its directory: a partial tally is still data.

**Takeaway**: **A window's tooling assumes one run at a time: a second run can change the fixture under the first. Before starting anything beside a run of your own, ask what the launcher does at start - and never delete a cancelled run's output unread.**
