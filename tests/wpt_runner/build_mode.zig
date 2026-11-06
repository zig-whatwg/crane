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

/// The allocator the runner's process allocates from.
pub const RunnerAllocator = enum {
    /// runner_allocator.Fast / Traced (std.heap.DebugAllocator, safety on):
    /// every leak and every double free reported, which the sweeps and the
    /// gates read. Every runner but the release runner.
    debug,
    /// The allocator a release build of Crane gives its host: libc's malloc,
    /// std.heap.c_allocator - what src/lib_exports.zig's createBrowser passes,
    /// thread-safe for the runner's worker and service-worker threads. No
    /// detection at all: the release runner is for timing only.
    production,
};

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
    allocator: RunnerAllocator = .debug,

    /// Whether the runner needs C libraries of its own: the ones every other
    /// artifact links are built with -Doptimize's mode.
    pub fn ownCLibraries(self: RunnerModes) bool {
        return self.c_libraries != self.crane_modules;
    }

    /// Whether the runner needs a module graph of its own: its C libraries
    /// differ from its Crane modules' mode, or its Crane modules from the
    /// shared graph's (`optimize`, -Doptimize's mode).
    pub fn ownGraph(self: RunnerModes, optimize: Mode) bool {
        return self.ownCLibraries() or self.crane_modules != optimize;
    }
};

/// Which release build of Crane: `-Dwpt-runner-release` (ReleaseSafe, the
/// build every comparison's headline times) or `-Dwpt-runner-release-fast`
/// (ReleaseFast, the column beside it).
pub const Release = enum { safe, fast };

/// The runner (and the console, and gc_bench) as a release build of Crane
/// runs - every part in the release mode, so Crane's modules leave Debug and
/// its Debug-only checks (the refcount ledger, the isolate cleanup
/// validation) are gone; the C code at the mode's own sanitizer default; and
/// the production allocator. The build to time and measure beside a
/// browser's official release, never one to sweep or gate with: it reports
/// no leak and no double free.
///
/// - `.safe` (the user, 2026-11-04: "recompile with ReleaseSafe then re-run
///   the comparison to Chrome"): ReleaseSafe throughout, the C code at
///   ReleaseSafe's `.trap`, not the correctness runner's `.full`.
/// - `.fast` (the user, 2026-11-05, "yes": perf round 0 also times a
///   ReleaseFast Crane, an extra column beside the ReleaseSafe build, which
///   stays the headline): only the mode differs - ReleaseFast throughout
///   (no runtime safety in Crane's modules), and no C sanitizer at all, named
///   `.off` rather than left to Zig's default so the build says what it is.
pub fn releaseRunner(release: Release) RunnerModes {
    const mode: Mode = switch (release) {
        .safe => .ReleaseSafe,
        .fast => .ReleaseFast,
    };
    return .{
        .root = mode,
        .crane_modules = mode,
        .c_libraries = mode,
        .sanitize_c = switch (release) {
            .safe => .trap,
            .fast => .off,
        },
        .allocator = .production,
    };
}

/// `-Dwpt-runner-release`'s build.
pub const release_runner: RunnerModes = releaseRunner(.safe);

/// `-Dwpt-runner-release` and `-Dwpt-runner-release-fast`: the release build
/// they name, or none. Both at once name two builds, which build.zig refuses
/// rather than choosing one.
pub fn releaseOption(release: bool, release_fast: bool) error{TwoReleaseBuilds}!?Release {
    if (release and release_fast) return error.TwoReleaseBuilds;
    if (release_fast) return .fast;
    if (release) return .safe;
    return null;
}

/// `modes` as a Crane pin's build identity names them (tools/perf_bench, the
/// journal's `engine.optimize`): "root ReleaseSafe, Crane modules
/// ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap, libc malloc".
/// build.zig installs it beside a release console (zig-out/bin/repl.modes),
/// so the pin is written from what was built.
pub fn describe(buf: []u8, modes: RunnerModes) error{NoSpaceLeft}![]const u8 {
    return std.fmt.bufPrint(buf, "root {s}, Crane modules {s}, C libraries {s}, sanitize_c {s}, {s}", .{
        modeName(modes.root),
        modeName(modes.crane_modules),
        modeName(modes.c_libraries),
        if (modes.sanitize_c) |s| @tagName(s) else "default",
        switch (modes.allocator) {
            .production => "libc malloc",
            .debug => "the leak-checking allocator",
        },
    });
}

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

/// The console's modes (tools/repl.zig, Crane's headless browser).
/// `release`: -Dwpt-runner-release or -Dwpt-runner-release-fast
/// (`releaseOption`), which make the console Crane's release build - the one
/// the performance suite times beside the browsers' official releases
/// (tools/perf_bench, docs/performance.md; the user, 2026-11-04: Crane is
/// timed in its release build) - `releaseRunner`'s modes exactly, winning
/// over -Drepl-optimize as they win over -Dwpt-runner-optimize. Otherwise
/// the runner's rule (`runnerModes`).
pub fn consoleModes(release: ?Release, console_option: ?Mode, optimize: Mode, optimize_given: bool) RunnerModes {
    if (release) |r| return releaseRunner(r);
    return runnerModes(console_option, optimize, optimize_given);
}

/// A mode's name as `-Doptimize` spells it, for the runner's banner
/// (`wpt_runner: ReleaseSafe build (Crane modules Debug, C libraries
/// ReleaseSafe)`, as AGENTS.md documents it). Zig 0.17 renamed the
/// OptimizeMode tags to debug, safe, fast and small, so @tagName no longer
/// gives these names. Takes any OptimizeMode-shaped enum: the runner's build
/// options module declares a copy of the type of its own.
pub fn displayName(comptime mode: anytype) []const u8 {
    return switch (@field(Mode, @tagName(mode))) {
        .debug => "Debug",
        .safe => "ReleaseSafe",
        .fast => "ReleaseFast",
        .small => "ReleaseSmall",
    };
}

/// `displayName` of a mode known only at run time (build.zig's).
fn modeName(mode: Mode) []const u8 {
    return switch (mode) {
        .debug => "Debug",
        .safe => "ReleaseSafe",
        .fast => "ReleaseFast",
        .small => "ReleaseSmall",
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

test "the banner names each mode as -Doptimize spells it" {
    // AGENTS.md documents the runner's banner as `wpt_runner: ReleaseSafe build
    // (Crane modules Debug, C libraries ReleaseSafe)`. Zig 0.17 renamed the
    // OptimizeMode tags (debug, safe, fast, small), so @tagName no longer
    // gives these names.
    try testing.expectEqualStrings("Debug", displayName(.debug));
    try testing.expectEqualStrings("ReleaseSafe", displayName(.safe));
    try testing.expectEqualStrings("ReleaseFast", displayName(.fast));
    try testing.expectEqualStrings("ReleaseSmall", displayName(.small));
}

test "the release runner is ReleaseSafe throughout, at ReleaseSafe's own C sanitizer, with the production allocator" {
    // -Dwpt-runner-release (the user, 2026-11-04: "recompile with ReleaseSafe
    // then re-run the comparison to Chrome"): the runner as a release build of
    // Crane would run, to time and measure beside Chrome for Testing, an
    // official release build. Crane's modules leave Debug (no refcount ledger,
    // no isolate cleanup validation), the C code takes ReleaseSafe's default
    // sanitizer (.trap, not the correctness runner's .full), and the allocator
    // is the one a host's release build gets. Never for sweeps or gates: it
    // detects no leak and no double free.
    const modes = release_runner;
    try testing.expectEqual(Mode.ReleaseSafe, modes.root);
    try testing.expectEqual(Mode.ReleaseSafe, modes.crane_modules);
    try testing.expectEqual(Mode.ReleaseSafe, modes.c_libraries);
    try testing.expectEqual(@as(?std.zig.SanitizeC, .trap), modes.sanitize_c);
    try testing.expectEqual(RunnerAllocator.production, modes.allocator);
    // Its Crane modules are not the shared graph's (built in -Doptimize's mode).
    try testing.expect(modes.ownGraph(.Debug));
}

test "with -Dwpt-runner-release the console is the release build: release_runner's modes exactly" {
    // The performance suite times Crane's headless browser, the console
    // (tools/perf_bench, docs/performance.md), beside the browsers' official
    // releases - in the release build (the user, 2026-11-04), never the
    // correctness modes: every part ReleaseSafe, its C libraries too, the C
    // code at ReleaseSafe's .trap, and libc's malloc, which the console
    // already allocates from.
    const modes = consoleModes(.safe, null, .Debug, false);
    try testing.expectEqual(release_runner.root, modes.root);
    try testing.expectEqual(release_runner.crane_modules, modes.crane_modules);
    try testing.expectEqual(release_runner.c_libraries, modes.c_libraries);
    try testing.expectEqual(release_runner.sanitize_c, modes.sanitize_c);
    try testing.expectEqual(RunnerAllocator.production, modes.allocator);
    // It wins over -Drepl-optimize, as -Dwpt-runner-release wins over
    // -Dwpt-runner-optimize.
    try testing.expectEqual(Mode.ReleaseSafe, consoleModes(.safe, .Debug, .Debug, false).root);
    // Its Crane modules and C libraries are not the shared graph's: a graph
    // of its own, whose C libraries are built at its root's sanitizer - the
    // root links no full UBSan runtime (.trap), so C built with .full would
    // not link (docs/lessons/workflow-a-release-root-over-debug-c-libraries-
    // must-link-the-full-sanitizer-runtime.md).
    try testing.expect(modes.ownGraph(.Debug));
}

test "without -Dwpt-runner-release the console keeps the runner's rule" {
    const plain = consoleModes(null, null, .Debug, false);
    const runner = runnerModes(null, .Debug, false);
    try testing.expectEqual(runner.root, plain.root);
    try testing.expectEqual(runner.crane_modules, plain.crane_modules);
    try testing.expectEqual(runner.sanitize_c, plain.sanitize_c);
    try testing.expectEqual(Mode.Debug, consoleModes(null, .Debug, .Debug, false).root);
}

test "with -Dwpt-runner-release-fast the console is the release build in ReleaseFast: no C sanitizer, libc malloc" {
    // The user, 2026-11-05 ("yes"): perf round 0 also times a ReleaseFast
    // Crane, a column beside the ReleaseSafe release build (the headline).
    // Every part ReleaseFast - the root (the LLVM pipeline and v8_wrapper.cpp),
    // Crane's modules (their builtin.mode: no runtime safety) and the C
    // libraries - with no C sanitizer at all, and the production allocator.
    const modes = consoleModes(.fast, null, .Debug, false);
    try testing.expectEqual(Mode.ReleaseFast, modes.root);
    try testing.expectEqual(Mode.ReleaseFast, modes.crane_modules);
    try testing.expectEqual(Mode.ReleaseFast, modes.c_libraries);
    // Off, not null (Zig's default): the build names it, and the C libraries
    // a ReleaseFast root links are built without one too.
    try testing.expectEqual(@as(?std.zig.SanitizeC, .off), modes.sanitize_c);
    try testing.expectEqual(RunnerAllocator.production, modes.allocator);
    try testing.expect(modes.ownGraph(.Debug));
    // It wins over -Drepl-optimize, as the ReleaseSafe release build does.
    try testing.expectEqual(Mode.ReleaseFast, consoleModes(.fast, .Debug, .Debug, false).root);
}

test "the two release builds differ only in their optimize mode and its C sanitizer" {
    // "Only the optimize mode differs from -Dwpt-runner-release": the same
    // allocator, a graph of its own in both, every part in one mode, and the
    // sanitizer each mode's own (.trap for ReleaseSafe, off for ReleaseFast).
    const safe = releaseRunner(.safe);
    const fast = releaseRunner(.fast);
    try testing.expectEqual(safe.allocator, fast.allocator);
    try testing.expectEqual(safe.ownGraph(.Debug), fast.ownGraph(.Debug));
    for ([_]RunnerModes{ safe, fast }) |m| {
        try testing.expectEqual(m.root, m.crane_modules);
        try testing.expectEqual(m.root, m.c_libraries);
    }
    try testing.expectEqual(Mode.ReleaseSafe, safe.root);
    try testing.expectEqual(Mode.ReleaseFast, fast.root);
    // release_runner is the ReleaseSafe one, as -Dwpt-runner-release builds it.
    try testing.expectEqual(release_runner.root, safe.root);
    try testing.expectEqual(release_runner.sanitize_c, safe.sanitize_c);
}

test "the release options name one release build, or none" {
    try testing.expectEqual(@as(?Release, null), try releaseOption(false, false));
    try testing.expectEqual(@as(?Release, .safe), try releaseOption(true, false));
    try testing.expectEqual(@as(?Release, .fast), try releaseOption(false, true));
    // Both given name two builds: build.zig refuses, never picks one.
    try testing.expectError(error.TwoReleaseBuilds, releaseOption(true, true));
}

test "a release build's modes, as a pin's build identity names them" {
    // The journal's build identity (tools/perf_bench, a Crane pin's
    // `optimize`) is written from this, so it names exactly what was built.
    var buf: [160]u8 = undefined;
    try testing.expectEqualStrings(
        "root ReleaseSafe, Crane modules ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap, libc malloc",
        try describe(&buf, releaseRunner(.safe)),
    );
    try testing.expectEqualStrings(
        "root ReleaseFast, Crane modules ReleaseFast, C libraries ReleaseFast, sanitize_c off, libc malloc",
        try describe(&buf, releaseRunner(.fast)),
    );
}

test "every other runner keeps the leak- and double-free-detecting allocator" {
    // Pins the DEFAULT: the sweeps and the gates read "leaked:" and "Double
    // free detected", which only the debug allocator reports.
    try testing.expectEqual(RunnerAllocator.debug, runnerModes(null, .Debug, false).allocator);
    try testing.expectEqual(RunnerAllocator.debug, runnerModes(.Debug, .Debug, false).allocator);
    try testing.expectEqual(RunnerAllocator.debug, runnerModes(.ReleaseFast, .Debug, false).allocator);
    try testing.expectEqual(RunnerAllocator.debug, runnerModes(null, .ReleaseFast, true).allocator);
}

test "a runner has a module graph of its own when its Crane modules or C libraries differ from the shared graph" {
    // The default: Debug Crane modules, ReleaseSafe C libraries.
    try testing.expect(runnerModes(null, .Debug, false).ownGraph(.Debug));
    // -Doptimize=Debug and an explicit release -Doptimize share the graph built in that mode.
    try testing.expect(!runnerModes(null, .Debug, true).ownGraph(.Debug));
    try testing.expect(!runnerModes(null, .ReleaseFast, true).ownGraph(.ReleaseFast));
}
