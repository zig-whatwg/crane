# Testing: Replay a suite from the launcher's "replay:" line plus the gate's timeout flags, and read the tally, not the exit status

**Date**: 2026-11-17
**Lesson**: To run one suite again as the gate ran it, take the launcher's own `replay:` line and add the gate's `--timeout=` and `--slow=` flags from the step's "failed command" line; never run the "failed command" line as it stands, because its `--listen=-` makes the launcher run nothing and exit 0.

**Why**: `zig build test` starts each suite's launcher under the build runner's protocol (`--listen=-`, `--launch-seed=digest`, zig's own `--seed=`). Outside the build runner nothing answers that protocol. The launcher's `replay:` line is the standalone form, but it carries only the launch seed and the batch size: the timeout and the slow-test list are the build's, and the launcher's default timeout is 60 s, not the gate's 300 s.

**What Happened**: Lane vm1's macOS gate met the listed page_retention flake in tests-html (first run fail, alone pass pass). To learn whether it repeats with the gate's seed, the suite was replayed on the same host from the gate's cached binaries. The first launch used the `replay:` line as printed: six tests the build marks `--slow` timed out at 60 s (`FAIL 6`, "first run: timeout ... alone: timeout timeout"), which says nothing about the tree. The second launch ran the step's "failed command" line: it ended in one second with exit status 0 and the tally `PASS 0 SKIP 0 FAIL 0 ... NOT-RUN 2893`. Only the tally showed that nothing had run. The third launch - the "failed command" line without `--listen=-` and `--launch-seed=digest`, with `--seed=` set to the launch seed the tally printed - ran the suite as the gate had: `2893 tests, seed 0x91f7d001501c9efc, shuffled, batch 1 -> 2893 processes, 8 jobs, timeout 300 s`, `PASS 2890 SKIP 3 FAIL 0 FLAKY 0 NOT-RUN 0`.

**Fix**:
1. Build the replay command from the step's "failed command" line: remove `--listen=-` and `--launch-seed=digest`, and replace zig's `--seed=<short>` with the launch seed from the tally (`seed 0x...`). Keep `--timeout=`, every `--slow=`, `--batch=` and `--name=`; point `--out=` and `--timings=` at a file of your own.
2. Before believing a replay, read its first line (tests, processes, jobs, timeout) against the gate's and its tally's `NOT-RUN`: a replay is a result only when `NOT-RUN 0` and the timeout is the gate's.
3. At `--batch=1` each test is a process of its own, so the seed sets only the launch order: a failure that does not repeat in a replay did not depend on what ran before it in its process. Say that to the flake's owner instead of "no reproducer".

**Takeaway**: **A launcher that ran nothing exits 0. Read `NOT-RUN` and the timeout on the replay's own lines before you read anything else.**
