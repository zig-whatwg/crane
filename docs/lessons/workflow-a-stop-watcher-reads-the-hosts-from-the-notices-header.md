# Workflow: A STOP watcher reads the host from the CLOSING NOTICE's header, never its body

**Date**: 2026-10-30
**Lesson**: A lane's STOP watcher must take the closed host from the notice's own header - `CLOSING NOTICE (liaison, <time>, rule 16, chat2.local):` - because the body names hosts that are NOT affected ("chat.local is NOT affected", "chat.local was not affected"), and a watcher that matches any host in the line stops work on the wrong host.

**Why**: Timed windows are per host (rule 16, 2026-10-28). The liaison's notices close one host and, for the others' benefit, say which hosts stay open. A grep for every `chat*.local` in the line sees both.

**What Happened**: Lane refcount9 copied refcount8's watcher (tmp/scratch/refcount8-scripts/watch.sh), which collected every host the notice line named and stopped the lane's work on each that its mirror was on. At the 23:41 UTC CLOSING NOTICE for chat2.local, whose body ended "chat.local is NOT affected", it killed the lane's own chat.local build of its base and audit runners (`killed-by-path`, `stopped on chat.local`). Nothing of the lane ran on chat2. The build had to be relaunched; the lane posted the cause beside its "nothing on chat2" line. The same watcher, re-armed, also fires on the lane's OWN window's notice - expected, and handled by clearing STOP before the series.

**Fix**: Parse the header: `sed -nE 's/^(CLOSING NOTICE \([^)]*\)).*/\1/p'`, take the first host in it; only when the header names none, the first host in the text. Self-test the parser against the last notices in tmp/plans/held-files.md before arming (tmp/scratch/refcount9-scripts/watch.sh does both).

**Takeaway**: **A notice names the host it closes in its header and the hosts it spares in its body: match the header, and test the parser on real notices before trusting it with kills.**
