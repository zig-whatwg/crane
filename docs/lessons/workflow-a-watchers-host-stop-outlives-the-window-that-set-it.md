# Workflow: A watcher's host STOP outlives the window that set it - clear it at GAP OPEN

**Date**: 2026-11-10
**Lesson**: The closing-notice watcher writes `~/crane-work/<mirror>-bins/STOP-<host>` on the host a notice names, and nothing removes it when the window ends: the lane's next job on that host refuses to start until the lane deletes it.

**Why**: The STOP file is how a running gate script learns, between its steps, that it must stop. The watcher writes it for any notice on a host the lane's mirror is on - also another lane's window, when the lane has no job there. GAP OPEN is a held-files line, not an event on the host, so the file stays.

**What Happened**: Lane nd1 batch 1 had no job on chat.local when nd2's perf window closed it (12:11 UTC). The watcher wrote STOP-chat.local into nd1-bins there and exited, as written. After GAP OPEN (12:26) the lane's POST-A/B TSAN verify (crane-remote, chat.local) printed "STOP present" and ended with rc 3 at once.

**Fix**: When you resume on a GAP OPEN line, remove the STOP files the watcher wrote for that host (`crane-pool.sh on <mirror> 'rm -f ~/crane-work/<mirror>-bins/STOP-<host>'`, after checking that the host's window really ended), keep the local record of the notice, and re-arm the watcher. A job that ends in seconds with rc 3 means STOP, not a failure.

**Takeaway**: **A host STOP the watcher writes stays after the window ends: delete it when you resume on GAP OPEN, before the next job on that host.**
