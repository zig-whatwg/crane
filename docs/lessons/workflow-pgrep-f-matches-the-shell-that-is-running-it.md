# Workflow: `pgrep -f` matches the shell that is running it

**Date**: 2026-09-22
**Lesson**: `until ! pgrep -f wpt_runner_frozen; do sleep 30; done` can never
exit: `pgrep -f` matches the FULL command line of every process, and the
loop's own shell has "wpt_runner_frozen" in its command line.

**What Happened**: an agent wrote seven of these, sleeps from 30 to 120s, each
started because the previous one "had not finished yet". Its sweep had been
done for hours, its journals were final, its four commits were on its branch.
It reported nothing, was stopped, and its work was merged from its commit
messages. Then the command written to reap those loops -
`grep "[u]ntil ! pgrep"` - matched ITS OWN shell's command line and killed
the session's command mid-run. Same trap, minutes apart, from the other side.

**Fix**: match on the process name (`pgrep -x name`), or build the pattern at
runtime so the joined string is not in your own command line
(`pat='until ! pgrep -f wpt_runner_'; pat="${pat}frozen"`), and always
exclude `$$`. Better: wait on the artefact - a sweep is done when its journal
stops changing, a build when its output has an exit line.

**Takeaway**: **Wait on what the process WRITES, not on whether a string is
in the process table - the string is in yours too.**

**2026-09-25**: the runtime-built pattern is NOT enough. Two waiters written
exactly as above (`pat=...; pat="${pat}fr_"`, excluding `$$`) never exited -
16 and 12 hours after their runs finished - and the user found them in
/tasks. Wait on the artefact with a bound: `until [ "$(wc -l < journal.jsonl)"
-ge N ] || [ $SECONDS -gt 7200 ]; do sleep 30; done`. The same cleanup found
214 orphaned `wpt serve` multiprocessing workers (PPID 1, cwd `tests/wpt`,
up to three days old) left by servers killed with `lsof ... | xargs kill`:
kill a server's children with it, and sweep `ps -eo pid,ppid,command | awk
'$2==1 && /multiprocessing/'` when done.
