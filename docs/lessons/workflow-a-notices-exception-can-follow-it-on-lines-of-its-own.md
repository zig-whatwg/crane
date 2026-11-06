# Workflow: A notice's EXCEPTION can follow it on lines of its own - wait, then read every line after the notice

**Date**: 2026-11-06
**Lesson**: A CLOSING NOTICE and the EXCEPTION that spares a running job are not always one line: the integrator wrote the notice, then each exception on a line of its own. A watcher that acts on the notice line alone kills the exempt job before its exception is written.

**Why**: Lane perf2's watcher (batch 2) carried the exemption path from the batch before - it read `EXCEPTION:` text, but only from the notice's own line, and it acted within its 20 s poll of `tmp/plans/held-files.md`. The 16:20 notice for chat.local was followed by two `EXCEPTION:` lines, one of them "perf2's running console build (pids 71461/71538, ...) keeps running to its end". The watcher had already fired: it wrote STOP and killed the build's tree, five minutes into it.

A second trap came with the STOP file: the watcher touched `~/crane-work/<mirror>-bins/STOP` on the closed host, and a mirror's `-bins` follow it to the next host it runs on (newer files win). A STOP written for chat.local would then have stopped the same lane's jobs on chat2, which the notice did not close.

**What Happened**: The build was restarted. chat.local was closed, so it had to go to chat2, under a new mirror name: a mirror whose home host is inside another lane's window cannot move, because moving it copies it on that host. About 20 minutes of the batch were lost, plus a cold cache on chat2.

**Fix** (tmp/scratch/perf2b2/watch.sh):
1. On a new notice line, sleep about 20 s, then re-read EVERY line written since the watcher started: the notice lines and every line that begins with `EXCEPTION`. Match the exceptions against the pids in `remote-pids` (`<host> <pid>`) before killing anything.
2. Write a host-named STOP (`STOP-<host>`), and have every script check `STOP` and `STOP-$(hostname -s).local`. A STOP then stops jobs only on the host the notice closed, even after the `-bins` follow the mirror.
3. Re-arm the watcher every time it exits.

**Takeaway**: **A notice and its exceptions are a block, not a line: wait a moment after a notice and read every line written since, and name STOP files after their host so they cannot follow a mirror to a host that is still open.**
