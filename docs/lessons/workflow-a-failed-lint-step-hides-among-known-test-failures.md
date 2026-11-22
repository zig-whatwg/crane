# Workflow: A failed lint step hides among known test failures - account for every failed step

**Date**: 2026-11-22
**Lesson**: When a gate already fails for known reasons, account for every failed STEP in its Build Summary, and read every "above the baseline" line, before calling the rest green.

**Why**: `zig build test` reports a ratchet's breach as a failed step (`run exe lint_impls_boundary failure`) with its findings in the step's stderr, not as an `error: '<test name>' failed:` line. A summary filtered for failing test names shows the known failures and nothing else, so a new lint breach reads as "only the known failures".

**What Happened**: Lane tpw's gate of the IntersectionObserver change printed 15 known CDP-phase test failures and "Build Summary: 678/682 steps succeeded (3 failed)". The report said "lints at baseline". One of the three failed steps was lint-impls' unchecked-state-reads ratchet ("2 key(s) above the baseline": two `getState(State).own._internal` reads), and the change was merged into cdp/main with it. The next targeted run's log showed the breach; the fix (InternalStateAccessor.get) followed with a correction to the integrator.

**Fix**: In every gate summary, grep the log for `above the baseline`, `failure` and the failed-step count, and match the count against the failing test steps you can name; a step you cannot name is a new failure.

**Takeaway**: **"N steps failed" must be N named steps: a known test failure never accounts for a failed lint step.**
