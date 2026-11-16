# Workflow: A pgrep waiter matches its own command line

**Date**: 2026-10-31
**Status** (2026-11-15, lane dm3): the same trap with `grep` on a job's out-file. `run-job.sh` and `run-wpt.sh` write the whole command as the file's first line, so a wait loop that greps for a marker the command itself echoes - `== default pass rc`, `rc=` - matches at once and every wait returns immediately (lane dm3 believed a 60-minute window had its steps racing; lane wrap1 met `rc=` the same day). Anchor the pattern to the start of a line the job prints (`^== default pass rc`, `^\[run-wpt [0-9:]+\] rc=`).
**Lesson**: `while pgrep -f "<the job's command text>"; do sleep N; done` never ends when it runs through a shell whose own command line contains that text - the waiter's zsh -c is a match. Wait on the job's exact pid (`kill -0 <pid>`) or on a file the job writes, never on a pattern of the waiter's own words.

**Why**: The Bash tool runs each command as `zsh -c '<the whole command>'`, so every word of the loop, the pattern included, is on that process's command line; `pgrep -f` matches full command lines.

**What Happened**: Lane flaky4 waited for a crane-remote job with `pgrep -f "crane-remote.sh flaky4 zig build test"`; the loop matched itself and would have waited forever. Stopped and replaced by `while kill -0 <local crane-remote pid>`.

**Fix**: Take the pid when the job starts (crane-remote prints "job pid N"; a local `&` job has `$!`) and wait with `kill -0`, or wait for a marker the job prints into its log (`until grep -q DONE log`).

**Takeaway**: **A waiter must not be able to match itself: wait on a pid or a file, not on text that the wait itself contains.**
