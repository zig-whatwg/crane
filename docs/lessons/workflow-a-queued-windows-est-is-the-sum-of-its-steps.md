# Workflow: A queued window's --est is the sum of its steps

**Date**: 2026-11-20
**Lesson**: The `--est` you give `crane-pool.sh queue` is what the keeper and the integrator plan the host around. Add up every step the window runs at the runner count it gets, including the fixed-cost steps (lifetime x3 and verify x10 over the identity set). Do not use the A/B step alone.

**Why**: The queue orders other lanes' windows behind yours, and the keeper raises movement alerts against the estimate. An estimate that covers only the A/B makes a healthy window look stalled, and it misleads every lane waiting behind it.

**What Happened**: Lane net3 queued a TARGETED websockets/ A/B (202 files) with `--est 35`, sized for the A/B. The window also ran bug-finding, rerun, pair, lifetime x3 and verify x10 over 226 files (139 identity + 87 changed) at 8 runners: verify alone took ~70 minutes, ~7 minutes a run. At 95 minutes the integrator asked what was wrong; tmpl1's and maj4's windows were waiting behind it. Cutting the verify then would have needed a new window, which the keeper's build gap would have put behind maj4's build.

**Fix**: Estimate each step from the last window that ran it (its log has each step's START/END), and sum them. The identity set's lifetime and verify cost the same whatever the A/B's size. When the FULL window already verified the identity set at a nearly identical tip, leave it out of a targeted window's verify list, and say so in the note.

**Takeaway**: **A window's estimate is the sum of all its steps, fixed-cost ones included; size the verify list to what changed since the last verify.**
