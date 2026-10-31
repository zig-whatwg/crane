# Testing: A runner finds its snapshot from its working directory, so run another build's runner from its own root

**Date**: 2026-10-31
**Lesson**: A wpt_runner binary restores the V8 snapshot it finds from the CURRENT directory (`zig-out/bin/whatwg_snapshot.bin` first), not the one beside its executable, so a frozen runner started from a lane's mirror runs on the lane's snapshot - or on none.

**Why**: `browser.Process` searches `DEFAULT_SNAPSHOT_PATHS` relative to the working directory (src/browser/process.zig). The snapshot's stamp checks only the external-reference COUNT (snapshot_loader.splitStamp), so another build's snapshot with the same count is accepted even when its table differs, and V8 then wires callbacks by index to whatever sits there. A different count is refused, and the runner falls back to the next candidate and finally to no snapshot. Both outcomes are silent.

**What Happened**: Lane flaky1's first `wpt_runner --repeat=N --repeat-with=<frozen main runner>` spawned the base runner from the supervisor's directory - the lane's mirror - with relative paths. Its smoke run passed on both sides, which proved nothing: by the search order the base side restored the lane's snapshot (the lane's binding tables were main's, so the counts matched) - found by reading process.zig while planning the A/B, not by any failure. The integrator's own pairs never hit this because they `cd ~/crane-frozen/main-<sha>` before running `./zig-out/bin/wpt_runner`.

**Fix**: `repeat.runnerRoot` names a runner's root (`<root>` for `<root>/zig-out/bin/<exe>`), the `--repeat-with` children spawn there (std.process.spawn's `.cwd`), and the series passes every path absolute so both runners read and write the same files.

**Takeaway**: **A runner binary is not self-contained: its snapshot comes from the directory it runs in. Run another build's runner from that build's root, and pass it absolute paths - never from the directory of the build you are comparing it with.**
