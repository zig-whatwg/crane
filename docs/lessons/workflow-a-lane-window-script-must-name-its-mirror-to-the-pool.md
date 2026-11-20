# Workflow: A lane's window script must name its mirror to the pool

**Date**: 2026-11-20
**Lesson**: A lane's own window script, run over plain ssh, must export `CRANE_POOL_MIRROR=<its mirror>` before it `cd`s into the WPT tree. Without it `crane-measure.sh` reads the mirror from the working directory, and the shared WPT tree's path (`~/crane-work/main/tests/wpt`) names "main", so a FULL sweep waits for the lane's own window to end.

**Why**: `crane-measure.sh` lets a full run (5,000 files or more) join the host's full-run slot only while the host is open, or closed for a timed window whose owner is the run's own mirror (`fullrun_join`). It takes the mirror from `CRANE_POOL_MIRROR`, which `crane-pool.sh` exports, and otherwise from `$PWD` under `~/crane-work/`. A lane window script runs each sweep from inside the WPT tree. The frozen runner's `tests/wpt` resolves to the shared tree, so the run reads as "main" against a window owned by "maj1-l". A targeted run under 5,000 files never asks, which is why a targeted A/B on the same host and tree ran at once.

**What Happened**: Lane maj1's combined FULL A/B (longhands + batch 3 against generation 233) started at 8:18 PM ET in main's window, closed for "maj1-l". `window.sh` passed its load gate and printed `AB START (13675 files, 32 runners)`. The production sweep then waited, silently in the window log, for the window "maj1-l" to end, until the integrator re-closed the host as "main" at 4:15 AM ET: eight hours of a closed host. The lane's waiter checked only for the window's done marker, so nothing showed that the sweep had never started. The same window script had run full sweeps before, under windows whose owner and working directory happened to agree.

**Fix**:
1. In every lane window script (`.maj1/window.sh`, `.maj1/tgtsub.sh` and their copies), before the first `cd` into the WPT tree:
   ```bash
   # crane-measure reads the run's mirror from CRANE_POOL_MIRROR, else from $PWD - the shared WPT
   # tree's path names "main". This window's owner is this mirror.
   export CRANE_POOL_MIRROR=${CRANE_POOL_MIRROR:-$(basename "$root")}
   ```
2. After launching a detached window, check within a few minutes that its first sweep is making progress (its journal grows, or `crane-measure` printed that it holds the full-run slot), not only that the script is alive. A line like `the host is closed for a timed window ...` in the sweep log means it is waiting.
3. The integrator's side: `crane-measure.sh`'s fallback can resolve a run's mirror from the runner it was given (`~/crane-work/<mirror>-bins/...`) before the working directory.

**Takeaway**: **A window script outside crane-pool.sh exports CRANE_POOL_MIRROR, and a launched window is checked for a moving sweep, not just a live process.**
