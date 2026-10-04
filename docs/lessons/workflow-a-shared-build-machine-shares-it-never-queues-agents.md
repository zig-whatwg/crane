# Workflow: A shared build machine shares, it never queues agents behind each other

**Date**: 2026-10-04
**Status (2026-10-04, same day)**: corrected - WPT runs must stay at NORMAL QoS. Running them at utility QoS made CPU-heavy files near their 10 s timeout time out (wasm/core/f32.wast.js: OK 5,027 subtests in 8.0 s at normal QoS, TIMEOUT with 3,559 at 10.2 s at utility), which corrupted a main sweep and the lanes' A/Bs for three hours. Only builds run at utility. A second calibration with the load at normal QoS (load average 10-12) gave the same timers/hr-time results as the exclusive runs.
**Lesson**: Every agent's job on chat.local starts at once with a share of the machine; timing-critical runs get priority, not exclusivity.

**Why**: The scheduler made timing-critical runs (timers x3) take chat exclusively: they stopped every new WPT chunk from starting and waited for all running chunks to finish before running. Builds queued for one of four slots too. With three lanes and Codex all in their final A/B sweeps, Codex's timers stage sat waiting for a drain on a machine whose load average was about 4 of 14 cores. The user: no agent may wait for another agent's work.

**What Happened**: `crane-exclusive.sh run` posted a reservation that `crane-measure.sh` honoured by handing out no tokens, then waited for the tokens in use to reach zero. Sweeps took tokens all-or-nothing in FIFO order, so any job could wait behind a sweep's chunk; builds waited for a free slot.

**Fix**:
1. `crane-measure.sh run/sweep` starts at once with a fair share of the general pool (11 of 14 tokens divided by the live jobs, at least 1; an overflow token instead of waiting when every token is held), rewrites `--parallel=` to the share, and runs at NORMAL QoS (see Status).
2. `crane-exclusive.sh run` is a priority run: three reserved tokens, normal QoS, no drain, no pause, no wpt-serve restart.
3. crane-remote runs up to five jobs at once; the zig shim caps each build's `-j` at 5 root compiles divided by the live builds, so memory stays bounded instead of jobs queueing.
4. wpt serve, which leaks handler threads over a long life, is restarted only when it has leaked and no runner token is held.
Calibrated before the switch (~/crane-calib-priority): under a 10-runner utility-QoS WPT load, timers x3 (15 OK, 1 TIMEOUT, 34 passed) and hr-time (10 OK, 3 TIMEOUT, 65 passed) matched the exclusive runs exactly.

**Takeaway**: **Share the machine, never queue agents behind each other - and measure every class of run under the new sharing before trusting it: the timing runs were calibrated, the sweeps were not, and a QoS clamp quietly turned heavy files into TIMEOUTs.**
