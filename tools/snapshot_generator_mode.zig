//! The optimize mode of the V8 snapshot generator: one fixed mode, whatever
//! -Doptimize says.
//!
//! The generator (src/runtime/engines/v8/snapshot_generator.zig) is a
//! build-time tool that runs once per build and writes
//! zig-out/bin/whatwg_snapshot.bin. Every artifact that starts a Browser
//! restores that file - the WPT runner, gc_bench, the console - whatever mode
//! each of them is built in: the blob is a function of the source, not of the
//! optimizer (V8 names each callback by its index in the external reference
//! table, and every registration takes the next index, repeats included -
//! docs/lessons/architecture-a-snapshot-s-external-reference-table-must-not-
//! depend-on-the-optimizer.md; its build stamp refuses a blob made against
//! another count). So the generator's own mode buys nothing but its build
//! time, and building it with -Doptimize made a ReleaseSafe build pay a
//! second optimized compile of Crane before anything could use the snapshot
//! (the user, 2026-11-04: a ReleaseSafe console "sat at compile exe
//! snapshot_generator safe native").
//!
//! Debug is the fixed mode (lane console3, chat2, 2026-11-04): its compile
//! took 3 min over a warm Debug cache against 16 min (13 GB) for a
//! ReleaseSafe one, and its run 0.20 s against 0.13 s. A default build (no
//! -Doptimize) already builds it in Debug, so the generator a warm Debug
//! cache holds is the one every mode uses, and its blob is the same whatever
//! -Doptimize says (6472fd2f..., over Debug and over ReleaseSafe modules,
//! and main's). It is also the precise one: a ReleaseSafe generator's blob
//! differs in 46,048 of its 2,645,688 bytes - same size, same 11,539-entry
//! reference table - because V8 names a callback the optimizer folded into
//! another (ICF) by the first index of their shared address
//! (external-reference-encoder.cc), where the Debug generator names every
//! callback by its own. `-Dsnapshot-generator-optimize` builds another for a
//! diagnosis.
//!
//! std-only, so `zig build test` pins it (tools-snapshot_generator_mode).

const std = @import("std");

const Mode = std.builtin.OptimizeMode;

/// The generator's root module mode. `option`: -Dsnapshot-generator-optimize,
/// if given. -Doptimize does not enter into it.
pub fn snapshotGeneratorMode(option: ?Mode) Mode {
    return option orelse .Debug;
}

/// The C sanitizer the generator's root asks for: the C libraries it links
/// are -Doptimize's - Debug-built by default, with the full sanitizer - so a
/// ReleaseSafe generator over them links the full UBSan runtime they call
/// into (the WPT runner's rule, tests/wpt_runner/build_mode.zig
/// RunnerModes.sanitize_c). Null leaves Zig's default: full in Debug, which
/// keeps the default generator the one a warm cache already holds, and none
/// in the fast modes.
pub fn sanitizeC(mode: Mode) ?std.zig.SanitizeC {
    return switch (mode) {
        .ReleaseSafe => .full,
        .Debug, .ReleaseFast, .ReleaseSmall => null,
    };
}

const testing = std.testing;

test "the snapshot generator is a Debug build unless asked otherwise" {
    // Pins the DEFAULT: `zig build repl-exe`, `zig build wpt-runner` and
    // `zig build test` all run the generator, with no option.
    try testing.expectEqual(Mode.Debug, snapshotGeneratorMode(null));
}

test "-Dsnapshot-generator-optimize builds another generator for a diagnosis" {
    try testing.expectEqual(Mode.ReleaseSafe, snapshotGeneratorMode(.ReleaseSafe));
    try testing.expectEqual(Mode.ReleaseFast, snapshotGeneratorMode(.ReleaseFast));
    try testing.expectEqual(Mode.Debug, snapshotGeneratorMode(.Debug));
}

test "a ReleaseSafe generator links the full UBSan runtime its Debug-built C libraries call; Debug keeps Zig's default" {
    // The first -Dsnapshot-generator-optimize=ReleaseSafe build missed
    // ___ubsan_handle_* from libbrotli at link time (lane console3,
    // 2026-11-04), as the first ReleaseSafe console had.
    try testing.expectEqual(@as(?std.zig.SanitizeC, .full), sanitizeC(.ReleaseSafe));
    try testing.expectEqual(@as(?std.zig.SanitizeC, null), sanitizeC(.Debug));
    try testing.expectEqual(@as(?std.zig.SanitizeC, null), sanitizeC(.ReleaseFast));
}
