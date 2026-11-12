# Workflow: A run started in the background ignores INT - stop it with TERM

**Date**: 2026-11-12
**Lesson**: A command a non-interactive shell starts with `&` has SIGINT (and SIGQUIT) ignored from birth, and bash cannot trap a signal that was ignored on entry, so `kill -INT` never reaches a backgrounded `crane-pool.sh wpt` run's cancel trap: stop such a run, and write every watcher, with `kill -TERM`.

**Why**: POSIX makes an asynchronous list in a shell without job control ignore SIGINT and SIGQUIT. A script that starts `crane-pool.sh wpt ... &` (or `( ... ) &` from `zsh -c`, which is how an agent launches a long pool run beside its other work) hands the run that ignored disposition. bash then refuses `trap ... INT` for it ("signals ignored upon entry to the shell cannot be trapped or reset"), so the run's `trap 'cancel_run 130' INT` - the step that kills its detached process tree on the pool host - is never armed. `trap 'cancel_run 143' TERM` is: TERM is not ignored.

**What Happened**: Lane sw2 b1 cancelled its own item 0b window run on server1 to fix its instrumentation. `kill -INT` to the local crane-pool.sh changed nothing: the remote sweep's 36 processes and 32 runners kept going. `kill -TERM` to the same pid stopped it at once (exit 143; `pgrep` on the host found nothing left). The CLOSING NOTICE watchers lanes copy (tmp/quick1/watch.sh and its copies) stopped local runs with `kill -INT`, so a lane whose run had been launched in the background would have kept running into another lane's timed window.

**Fix**: Watchers send `kill -TERM` to their local `crane-pool.sh wpt` runs (tmp/sw2/watch.sh; quick1's watchers; crane-pool.sh's header now says so). To cancel a pool run by hand, send TERM to the local crane-pool.sh, then confirm on the host that its tree is gone.

**Takeaway**: **Never rely on INT to stop something a script started in the background: it was born ignoring INT. Use TERM, and check the remote tree is gone.**
