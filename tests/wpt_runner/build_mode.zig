//! How the WPT runner is built: the optimize mode of each part of it.
//!
//! build.zig asks `runnerModes` and `zig build test` pins its answers here
//! (std-only, so the harness tests run it).
//!
//! A compilation has ONE LLVM pipeline, its root module's: Zig optimizes every
//! module it compiles at the root's level (Debug: none; any release mode: the
//! O3 pipeline), whatever mode a module was created with. What a module's own
//! mode still decides is its Zig semantics - `builtin.mode`, which Crane's
//! diagnostics key on, and safety - and the -O level and sanitizer of C/C++
//! sources attached to it. So the runner has three parts with a mode each.

const std = @import("std");

const Mode = std.builtin.OptimizeMode;

pub const RunnerModes = struct {
    /// The runner's root module (tests/wpt_runner/main.zig). It decides the
    /// LLVM pipeline for all of the runner's Zig, std's mode, and the -O level
    /// of v8_wrapper.cpp, which the root compiles.
    root: Mode,
    /// Crane's own modules in the runner's graph: their `builtin.mode`. They
    /// keep -Doptimize's, so a default runner keeps every Debug-only check
    /// (the refcount ledger, the isolate cleanup validation) while LLVM
    /// optimizes their code at the root's level.
    crane_modules: Mode,
    /// The C libraries the runner links: libcurl, mbedTLS, zlib, nghttp2.
    c_libraries: Mode,
    /// The C sanitizer for v8_wrapper.cpp and the C libraries (libcurl's own
    /// sources excepted: build.zig turns it off there in every mode). `.full`
    /// in the safe modes, as in Debug: the same checks as `.trap` (ReleaseSafe's
    /// default), but a failed one names the check and the source line and
    /// panics with a stack trace instead of dying on a bare SIGTRAP. Null
    /// leaves Zig's default (off in ReleaseFast and ReleaseSmall).
    sanitize_c: ?std.zig.SanitizeC,

    /// Whether the runner needs C libraries of its own: the ones every other
    /// artifact links are built with -Doptimize's mode.
    pub fn ownCLibraries(self: RunnerModes) bool {
        return self.c_libraries != self.crane_modules;
    }
};

/// `runner_option`: -Dwpt-runner-optimize, if given. `optimize`: -Doptimize's
/// value (Debug when not given). `optimize_given`: whether -Doptimize (or
/// --release) was passed.
///
/// The runner is ReleaseSafe unless asked otherwise (the user, 2026-10-11).
/// -Dwpt-runner-optimize sets the runner's mode alone; an explicit -Doptimize
/// sets it with everything else's (`-Doptimize=Debug` builds the Debug runner
/// a diagnosis may want).
pub fn runnerModes(runner_option: ?Mode, optimize: Mode, optimize_given: bool) RunnerModes {
    const root: Mode = runner_option orelse if (optimize_given) optimize else .ReleaseSafe;
    return .{
        .root = root,
        .crane_modules = optimize,
        .c_libraries = root,
        .sanitize_c = switch (root) {
            .Debug, .ReleaseSafe => .full,
            .ReleaseFast, .ReleaseSmall => null,
        },
    };
}

const testing = std.testing;

test "the default runner is ReleaseSafe, its C libraries too, and Crane's modules keep Debug" {
    // Pins the DEFAULT, not just the explicit cases: `zig build wpt-runner`
    // with no options is what the gate and every lane build.
    const modes = runnerModes(null, .Debug, false);
    try testing.expectEqual(Mode.ReleaseSafe, modes.root);
    try testing.expectEqual(Mode.ReleaseSafe, modes.c_libraries);
    try testing.expectEqual(Mode.Debug, modes.crane_modules);
    try testing.expect(modes.ownCLibraries());
}

test "the safe modes keep the full C sanitizer; the fast ones leave Zig's default" {
    try testing.expectEqual(@as(?std.zig.SanitizeC, .full), runnerModes(null, .Debug, false).sanitize_c);
    try testing.expectEqual(@as(?std.zig.SanitizeC, .full), runnerModes(.Debug, .Debug, false).sanitize_c);
    try testing.expectEqual(@as(?std.zig.SanitizeC, null), runnerModes(.ReleaseFast, .Debug, false).sanitize_c);
}

test "-Doptimize=Debug builds a Debug runner on the shared libraries" {
    const modes = runnerModes(null, .Debug, true);
    try testing.expectEqual(Mode.Debug, modes.root);
    try testing.expectEqual(Mode.Debug, modes.c_libraries);
    try testing.expect(!modes.ownCLibraries());
}

test "-Dwpt-runner-optimize decides the runner alone, over -Doptimize" {
    const debug_runner = runnerModes(.Debug, .Debug, false);
    try testing.expectEqual(Mode.Debug, debug_runner.root);
    try testing.expect(!debug_runner.ownCLibraries());

    const fast_runner = runnerModes(.ReleaseFast, .ReleaseSafe, true);
    try testing.expectEqual(Mode.ReleaseFast, fast_runner.root);
    try testing.expectEqual(Mode.ReleaseSafe, fast_runner.crane_modules);
    try testing.expect(fast_runner.ownCLibraries());
}

test "an explicit release -Doptimize builds everything in that mode" {
    const modes = runnerModes(null, .ReleaseFast, true);
    try testing.expectEqual(Mode.ReleaseFast, modes.root);
    try testing.expectEqual(Mode.ReleaseFast, modes.crane_modules);
    try testing.expect(!modes.ownCLibraries());
}
