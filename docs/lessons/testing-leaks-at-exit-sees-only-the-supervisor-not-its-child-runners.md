# Testing: leaks --atExit sees only the supervisor, not its child runners

**Date**: 2026-10-25
**Lesson**: `leaks --atExit -- ./zig-out/bin/wpt_runner --parallel=1 ...` inspects only the supervisor process; the pages run in child processes it never sees, so "0 leaks" from that command proves nothing about the pages.

**Why**: `tests/wpt_runner/options.zig` `wantsSupervisor()` is `supervise or parallel != null`. Any `--parallel`, including `=1`, makes the runner a supervisor that spawns child runners for the shards. `leaks` attaches to the process it launched and reports at its exit.

**What Happened**: Lane pageretention1's leak check over 260 files with `--parallel=1` reported 0 leaks at a 13.6 MB peak. The peak alone gave it away: one page process climbs far higher. Re-run in-process (no `--parallel`, no `--supervise`), the same 260 files reported 0 leaks at a 229.9 MB peak, which is a real result. Earlier lanes' leak lines that used `--parallel=1` (abortsig1, unwrapped1) may have had the same blind spot. Codex rows 117 and 119 already ran it in-process (Q105, Q179: "NO --parallel or --supervise").

**Fix**:
1. Run the runner directly under leaks, in one process: `leaks --atExit -- ./zig-out/bin/wpt_runner --from-file=<list> --wpt-root=tests/wpt --output=<dir>`, with no `--parallel` and no `--supervise`.
2. Sanity-check the peak footprint in the leaks summary: a supervisor-only run shows a few MB.
3. Prove the detector first with a positive control (a deliberate leak) when the result is the evidence for a merge.

**Takeaway**: **A leak check is only as good as the process it watches: run the WPT runner in-process under `leaks`, and read the peak footprint before trusting "0 leaks".**
