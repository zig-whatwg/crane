# Testing: A CPU target is the resolved CPU, not the model you asked for

**Date**: 2026-11-06
**Lesson**: `-Dcpu=apple_m1` does not compile for Zig's `apple_m1` model as listed: target resolution edits the feature set (it drops `fuse_aes` from every Apple Silicon model), so record what resolution produced, and check a build's model rather than an exact string.

**Why**: `std.zig.system.resolveTargetQuery` adjusts the CPU after taking the model. For `apple_m1` through `apple_m5` it removes `fuse_aes`, a workaround for ziglang/zig#37215 that lives in `std/zig/system.zig`. The same happens to a native build: chat.local's M4 Pro resolves to `apple_m4-fuse_aes`. `Model.toCpu` (the model's own features) and the target a build uses are two different sets.

**What Happened**: Perf round 1 records each release console's CPU target in `zig-out/bin/repl.modes` (`build_mode.zig` `writeCpu`: the model, then `+`/`-` each feature the resolved CPU adds to or lacks from the model's own). The unit tests built CPUs with `Model.toCpu` and expected `apple_m1`. The round's first build session on chat.local compiled the ReleaseSafe console with `-Dcpu=apple_m1`, then stopped at its own freeze check (`grep -qx target_cpu=apple_m1`): the file said `target_cpu=apple_m1-fuse_aes`. The recorder was right and the check was wrong - that is the CPU the code was compiled for. The cost was one rerun; the compile was cached.

**Fix**:
1. `build_mode.zig` has a test that resolves `aarch64-macos` with `-Dcpu=apple_m1` through `resolveTargetQuery` and expects `apple_m1-fuse_aes`. A toolchain that drops the workaround fails there first.
2. Window and freeze scripts check the model and the absence of ` (native)` (`^target_cpu=apple_m1([+-][a-z0-9_]+)*$`). They hold every console of a comparison to one target string, as `perf_bench`'s `PinWrongTarget` does.
3. The drift control's target (round 0 was built with no `-Dcpu`) is measured with the same function on the same host and Zig - a scratch program calling `writeCpu` over `resolveTargetQuery(.{})` - never read from `zig targets`' model name.
4. Test a recorder against the toolchain's own resolution, not only against hand-built inputs.

**Takeaway**: **A target query is a request; the resolved target is what gets compiled. Record the resolved CPU, test the recorder through the toolchain's own resolution, and check a build's model, not an exact feature string.**
