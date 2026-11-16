# Testing: When a suite gains rows, compare a round with its control over the rows both rounds have

**Date**: 2026-11-15

**Lesson**: A perf round's same-window comparison with the previous round's binary is taken over the workloads both rounds measure; rows new this round are reported apart, beside that figure.

**Why**: New rows have no control reading, so folding them into the geometric mean moves the "change since last round" figure by whatever the new rows happen to cost, not by anything that changed.

**What Happened**: Perf round 9 added five rows (three worker rows, fetch over loopback with gzip and Brotli bodies). Over all 50 shared-window rows, round 9's time read 0.979 of round 8's binary; over the 45 rows round 8 also has, 0.990. The five new rows were all faster (0.83-0.93), so the wider figure overstated the round's speed-up by about 1%.

**Fix**: Round 9's note states the 45-row figure and lists the new rows separately (lane perf9, tools/perf_bench/report.zig; main f50c9b17190).

**Takeaway**: **Compare like with like: a round's change is measured over the rows its control also ran; new rows are reported beside it, never inside it.**
