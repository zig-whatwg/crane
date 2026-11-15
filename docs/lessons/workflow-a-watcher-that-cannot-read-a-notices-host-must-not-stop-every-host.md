# Workflow: A watcher that cannot read a notice's host must not stop jobs on every host

**Date**: 2026-11-14
**Lesson**: A closing-notice watcher that reads "no host found" as "the notice names every host" kills jobs on hosts the notice never closed; a notice whose header has words before its parenthesis ("CLOSING NOTICE + WINDOW GO (integrator, 03:47 UTC, chat.local)") is exactly such a line.

**Why**: Lane watchers (copied from nd2 b4's watch.sh) take the host with `sed 's/.*CLOSING NOTICE ([^)]*, \([a-z0-9.]*\)).*/\1/p'`, which needs "(" right after "CLOSING NOTICE ". The integrator's combined notice-and-go line puts "+ WINDOW GO" between them, so the pattern matched nothing, `hosts` was empty, and the watcher's `[ -z "$hosts" ] ||` test treated every host as named. The default of an unreadable input was the most destructive answer, not the safe one (AGENTS.md "Memory": a gate's default is the safe answer).

**What Happened**: 2026-11-14 03:47 UTC, lane rep1 b1: the integrator closed chat.local for quick1's 4-minute perf window. rep1's watcher killed rep1's own PRE-A/B gate on server1 (freeze step, about 1 minute in) and wrote STOP-server1 in its bins. Nothing of another lane was touched; the gate was restarted after the fix.

**Fix**:
1. Allow any text between "CLOSING NOTICE" and the parenthesis: `sed -n 's/.*CLOSING NOTICE[^(]*([^)]*, \([a-z0-9.]*\)).*/\1/p'`.
2. Test the pattern on every notice shape in tmp/plans/held-files.md before arming the watcher (`grep -E '^CLOSING NOTICE|\): CLOSING NOTICE' tmp/plans/held-files.md | sed -n '<pattern>'` must print a host for every line).
3. Better still, when the host cannot be read, stop nothing: write a STOP-review file and notify the agent, which reads the notice itself.

**Takeaway**: **An unparsable notice must stop nothing and alert the agent; never let "no host found" mean "every host".**
