# An END line is the cue to post GAP OPEN - check the pool after every END

**Context:** 2026-11-10. Lane wr1 b8 posted END for its chat.local window part 1 at 01:26 UTC. The integrator was busy with two other lanes and a generation sweep, and never posted GAP OPEN or ran `crane-pool.sh open chat.local`. chat.local sat CLOSED with owner wr1 for about 1 h 35 min, until 03:01. That is the fastest Mac, and buildfix1 had to leave a mirror behind and work on chat2. The same miss happened on 2026-11-08: hosts idle after crash1, flaky5 and wr2's windows ended.

**Lesson:** a window has two closing steps, and the lane can only post the first. END says the owner is done. GAP OPEN and `crane-pool.sh open` are the integrator's, and nothing reminds you of them. The pool's CLOSED flag outlives the work it protected.

**How to apply:** whenever a lane's message or a held-files line says END, in the same turn: (1) `crane-pool.sh status` and confirm the owner has no process left on the host; (2) `crane-pool.sh open <host>` and append GAP OPEN. Before ending any turn, run `crane-pool.sh status` once, and treat any CLOSED host whose owner posted END as an open action item. Related: workflow-decide-a-notices-exceptions-before-posting-it.md.
