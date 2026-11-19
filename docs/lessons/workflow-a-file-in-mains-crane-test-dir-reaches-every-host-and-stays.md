# Workflow: A file in main's tests/wpt/crane/ reaches every host and stays there

**Date**: 2026-11-19
**Lesson**: Every lane's crane-remote job copies the MAIN checkout's tests/wpt/crane/ to its host's shared WPT tree additively, so an untracked lane-only file put there - even for minutes - spreads to every pool host through other lanes' jobs and is never deleted by a later sync.

**Why**: crane-remote rsyncs `$main_root/tests/wpt/crane/` to `<host>:crane-work/main/tests/wpt/crane/` with `rsync -a` and no `--delete` (Crane tests are pushed additively, so one lane's job never removes another's). Every lane's job does it, on whatever host it lands.

**What Happened**: Lane net2 put six copies of a lane-only diagnostic page (crane/net2-diag-abort-close-*.html, never to be committed) in the main checkout's tests/wpt/crane/ for about half an hour, then deleted them there. By then other lanes' jobs had pushed them to chat.local and server1; a window script's crane-list pattern (`^net2-`) picked them up, and removing the stale copies from chat.local fell inside another lane's timed cost window.

**Fix**:
1. Keep a lane-only page out of the main checkout: keep it in tmp/<lane>/ and push it to the one host that runs it (`crane-pool.sh on <mirror> 'echo <base64> | base64 -d > ~/crane-work/main/tests/wpt/crane/<file>'`).
2. Give it a prefix the window lists exclude (`grep -v '^<lane>-diag-'`), and record every host it was put on in the handoff.
3. Remove it from each host the moment the run that needed it ends - while that host is still yours (an open host or your own window), never inside another lane's timed window.

**Takeaway**: **The main checkout's crane/ directory is a broadcast: anything placed there lands on every host and stays. Lane-only pages go to one host by hand, and come off it the same day.**
