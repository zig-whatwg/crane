# Workflow: Killing a pool job's pid leaves its script running

**Date**: 2026-11-03
**Status** (2026-11-16, lane wrap2): the Fix's `pgrep -f '<script> <its args>'` is for FINDING the pids, on a host other lanes use: print what it matches, check each line is yours (its mirror's name or cache path in the command line), then signal those pids by number. Lane wrap2 piped such a pattern straight into kill on chat2.local and could not show afterwards what it had matched (nothing foreign, by the host's state - but that was luck plus a narrow label). An orphan whose command line does not carry the mirror's path is not yours to guess at.
**Lesson**: The pid crane-remote.sh prints ("job pid N") is the subshell that evaluates the command; killing it stops nothing that command started as a process of its own - a measurement script went on to its next `zig build`.

**Why**: The job is `( trap - PIPE; eval "$cmd" ) &`. When `$cmd` is `bash some-script.sh`, the script is a child process of that subshell, and SIGTERM to the subshell does not reach it: the script is orphaned and keeps running, and so does the `zig build` it is waiting on, its build runner and the test processes under it. Likewise a `crane-pool.sh on <mirror> 'until ...; do sleep; done'` wait keeps looping on the host after its local ssh is stopped.

**What Happened**: Lane onebin1 was asked to stop a measurement series on chat.local. `kill <job pid>` returned "killed"; pgrep then showed the build still running, and seconds later the script started the series' next step (c) on a host at load 29. Two stale wait loops of the same lane were also still on the host after their local tasks were stopped.

**Fix**: Kill the script's pid first (`pgrep -f '<script> <its args>'`), then every pid that carries the job's unique path (its own `--cache-dir`, e.g. `pgrep -f onebin1-m-dirs`), then check with pgrep that none is left; kill a remote wait loop by its pid too. Never a broad pkill (docs: kill exact pids only). A job meant to be stoppable checks a STOP file between its steps.

**Takeaway**: **"killed" from the job pid is not "stopped": find the job's script and its children by their own command lines, kill those exact pids, and confirm with pgrep.**
