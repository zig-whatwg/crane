# Workflow: A stop watcher must skip the notice that closes the host for its own window

**Date**: 2026-11-12
**Lesson**: A CLOSING NOTICE whose window belongs to your own mirror (`... closes for <lane>'s A/B (owner <lane>-l ...)`) is the go-ahead for your job, not a stop: a watcher that skips only the notices your lane WROTE kills your own window.

**Why**: The integrator writes the CLOSING NOTICE for every window, including yours, and names the owner inside it: "CLOSING NOTICE (integrator, 01:46 UTC, server1): server1 closes for cssprop1 b1's FULL A/B (owner cssprop1-l, ~20 min)". It lands in held-files.md seconds before (or after) the WINDOW GO, while your window's first jobs start.

**What Happened**: Lane cssprop1's watcher (tmp/cssprop1/watch.sh) filtered notices with `grep -v "(cssprop1"` - the author field - so the integrator's notice for cssprop1's own FULL A/B passed through. It set STOP-server1 and killed every pid on server1 whose command named the mirror, after the brief's pid check: the remote crane-pool bash, the output follower (the local launcher ended rc 137), and the `crane-measure.sh sweep` of the tip side (rc 143 at 22 s). window.sh survived, logged abcmp's FileNotFoundError and went on into the bug-finding sweep on a window with no A/B.

**Fix**:
1. Skip a notice whose text names your own mirror as its owner (`grep -v "owner <lane>-"`), as well as one your lane wrote.
2. Make the window script end itself when a step's journal does not hold every file of its list (count distinct paths against the list), instead of running the later steps on nothing.
3. Before relaunching, stop the rest of the broken run by exact pids and check with pgrep that none is left; post a held-files line saying what the earlier END was.

**Takeaway**: **The owner of a notice is in its text, not its header: a watcher matches "not mine" on both, and every window step checks its input is complete before it runs.**
