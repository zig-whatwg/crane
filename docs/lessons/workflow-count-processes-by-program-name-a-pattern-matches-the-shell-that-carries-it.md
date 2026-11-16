# Workflow: Count processes by program name - a command-line pattern matches the shell that carries it

**Date**: 2026-11-16
**Lesson**: `pgrep -f '<pattern>' | wc -l` run through ssh counts the remote shell whose own command line holds the pattern, so "is anything of mine still running" and "is the host empty" both read too high.

**Why**: `pgrep -f` and `ps ... | grep` match the whole command line. A check sent as `ssh host '... pgrep -f "glibc2.sh" ...'` runs inside a shell started with that text as its argument, and every wrapper shell around a detached job (`bash -c "( bash script ) > log"`) holds the script's name too. The count is then the job plus its wrappers plus the check itself.

**What Happened**: Lane mem2 checked three times on server1, 2026-11-16, and read 4 copies of a script it had started once, 3 processes of its own after a run had ended, and 2 "other builds or runners" on a host the integrator had just emptied for a timed window. Each time the true answer was 1, 0 and 0: `ps -eo comm` showed one script process, no console, and no `zig`, `wpt_runner` or `gc_bench` at all. A wrong 4 would have meant a timed run with several consoles at once; a wrong 2 would have meant a window that was not quiet.

**Fix**:
1. Count by program name: `ps -eo comm | grep -c '^repl$'`.
2. For a script, match its place in the argument list, not the text anywhere: `ps -eo pid,args | awk '$2 == "bash" && $3 == ".mem2/glibc2.sh"'`.
3. For "does anything run under my mirror", read each process's working directory (`readlink /proc/<pid>/cwd` on Linux).
4. When a count surprises you, list the matches before acting on the number.

**Takeaway**: **A process count taken by command-line pattern over ssh includes the check itself: count by program name or by argument position, and list the matches when the number is not the one you expect.**
