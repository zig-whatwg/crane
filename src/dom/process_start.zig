//! The process's start-up, as src/dom's hook modules see it.
//!
//! docs/instances.md: a hook - a function table the owning impl installs so
//! that code which may not name the impl can reach a step - is the same for
//! every instance and never changes. So it is process-wide and written once,
//! by `crane.Process` (src/browser/process.zig) while the process starts and
//! before any Browser exists: never lazily by its first owner (a lazily
//! installed hook made a page's result depend on which pages ran before it -
//! docs/lessons/architecture-a-threadlocal-hook-installed-by-the-first-owner.md),
//! and never per thread (a threadlocal installed on one thread is null on the
//! next - docs/lessons/architecture-a-threadlocal-is-per-thread-not-per-instance-or-tab.md).
//!
//! A hook slot is a `dom.Hook(T)` (hook.zig): its every write asks `writerOf`
//! - while the process starts, and never after, in every build mode. A test
//! installs through the sanctioned test start (`installForTest`, which the
//! generated `process_hooks.startHooksForTest()` runs its installs through) or
//! writes into its own scoped override of a slot (`Hook.overrideForTest`),
//! each counted here until it is restored: the test runner's digest checks
//! `outstandingOverrides()` is 0 after every test (Chromium's
//! ScopedFeatureList and base::TestSuite's check that a test left the
//! FeatureList as it found it; WebKit freezes its process-wide WTF::Config
//! after start-up - tmp/plans/hookfreeze-design.md). The registration lists
//! not yet converted (class P-res) still call `assertInstalling()`, which
//! lets a test write any time.
//!
//! Blink's CoreInitializer is the same shape: "Initialize must be called once
//! by singleton ModulesInitializer", installing function pointers into core
//! before any frame exists (third_party/blink/renderer/core/core_initializer.h).

const std = @import("std");
const builtin = @import("builtin");

pub const Phase = enum(u8) {
    /// Nothing has started the process.
    not_started,
    /// `crane.Process` is starting it: the engine, then every hook.
    starting,
    /// Started; hooks are read-only from here on.
    running,
    /// `crane.Process.deinit` ran. The engine cannot start again (V8 cannot
    /// initialize its platform twice).
    ended,
};

/// What `crane.Process` records about its start, in one word.
pub const State = packed struct(u16) {
    phase: Phase = .not_started,
    /// The engine was started with a snapshot that agents can be made from.
    has_snapshot: bool = false,
    _unused: u7 = 0,
};

/// The process's start-up record: the state word, and a test build's hook
/// bookkeeping (hook.zig) - the test starts installing now
/// (`installForTest`) and the overrides not yet restored
/// (`outstandingOverrides`), both unused outside tests.
const Start = struct {
    word: std.atomic.Value(State) = .init(.{}),
    test_installing: std.atomic.Value(u32) = .init(0),
    test_overrides: std.atomic.Value(u32) = .init(0),
};

// process-wide: crane.Process's start-up phase; src/dom hooks are written only while it is .starting
var state: Start = .{};

/// The current start-up state.
pub fn get() State {
    return state.word.load(.acquire);
}

/// Claim the start: not_started -> starting. False when another caller has
/// claimed it (or it has run); that caller finishes it.
pub fn begin() bool {
    return state.word.cmpxchgStrong(.{}, .{ .phase = .starting }, .acq_rel, .acquire) == null;
}

/// starting -> running: every hook is installed.
pub fn finish(has_snapshot: bool) void {
    std.debug.assert(get().phase == .starting);
    state.word.store(.{ .phase = .running, .has_snapshot = has_snapshot }, .release);
}

/// running -> ended.
pub fn end() void {
    state.word.store(.{ .phase = .ended }, .release);
}

/// Wait until a start another caller claimed has finished (or ended).
pub fn waitUntilStarted() Phase {
    while (true) {
        const phase = get().phase;
        if (phase != .starting) return phase;
        std.Thread.yield() catch std.atomic.spinLoopHint();
    }
}

/// The registration lists not yet converted to `Hook(T)` (class P-res)
/// assert this in their installs: hooks are written while the process
/// starts and never after. A lazy install left anywhere - an impl's `init`,
/// a consumer making a throwaway owner - fails here, at its first run,
/// instead of making results depend on what ran before. Tests are exempt
/// (a `Hook(T)` slot is not: `writerOf`).
pub fn assertInstalling() void {
    if (builtin.is_test) return;
    if (get().phase != .starting) {
        @panic("a src/dom hook was installed outside process start-up: hooks are installed once, by crane.Process (docs/instances.md)");
    }
}

/// Who may write a hook slot now.
pub const Writer = enum {
    /// The process start: `crane.Process` while the phase is `.starting`,
    /// or, in a test, the sanctioned test start (`installForTest`).
    start,
    /// A test, into its own override of the slot (`Hook.overrideForTest`).
    test_override,
    /// Nobody: the write is a bug - an install after start, a lazy install,
    /// or a test writing a slot it does not override.
    refused,
};

/// Who may write a slot, given the start-up phase, whether a test start is
/// installing (`installForTest`), whether a test overrides that slot, and
/// whether this is a test build. Outside tests only the start, and only
/// while `.starting`: in every build mode, since the check is one load per
/// install.
pub fn writerOf(phase: Phase, test_installing: bool, overridden: bool, is_test: bool) Writer {
    if (phase == .starting) return .start;
    if (!is_test) return .refused;
    if (test_installing) return .start;
    if (overridden) return .test_override;
    return .refused;
}

/// Who may write a slot now (`writerOf` for this process).
pub fn writer(overridden: bool) Writer {
    return writerOf(get().phase, state.test_installing.load(.acquire) > 0, overridden, builtin.is_test);
}

/// A write `writerOf` refused: never recovered from.
pub fn refuseWrite(slot_type: []const u8) noreturn {
    if (builtin.is_test) std.debug.panic(
        "a hook ({s}) was written outside process start-up: a test installs hooks through process_hooks.startHooksForTest() (process_start.installForTest) and swaps one with overrideForTest (src/dom/hook.zig)",
        .{slot_type},
    );
    std.debug.panic(
        "a hook ({s}) was installed outside process start-up: hooks are installed once, by crane.Process (docs/instances.md)",
        .{slot_type},
    );
}

/// The sanctioned test start: runs `install` - a set of `installHooks` -
/// with hooks writable, whatever the phase. A unit test with no Browser
/// installs the hooks it needs this way (the generated
/// `process_hooks.startHooksForTest()`); installing again what the process
/// start installed changes nothing.
pub fn installForTest(comptime install: fn () void) void {
    if (!builtin.is_test) @compileError("installForTest is for tests; a host starts crane.Process");
    _ = state.test_installing.fetchAdd(1, .acq_rel);
    defer _ = state.test_installing.fetchSub(1, .acq_rel);
    install();
}

/// Hook overrides made and not yet restored (`Hook.overrideForTest`): 0
/// after every test, which the test runner's digest checks. Always 0
/// outside tests.
pub fn outstandingOverrides() u32 {
    return state.test_overrides.load(.acquire);
}

/// hook.zig: an override was made.
pub fn overrideMade() void {
    _ = state.test_overrides.fetchAdd(1, .acq_rel);
}

/// hook.zig: an override was restored.
pub fn overrideRestored() void {
    const before = state.test_overrides.fetchSub(1, .acq_rel);
    std.debug.assert(before > 0);
}

test "the state is one word and starts not started" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(State));
    const initial: State = .{};
    try std.testing.expectEqual(Phase.not_started, initial.phase);
    try std.testing.expect(!initial.has_snapshot);
}

test "only the start writes a hook outside tests, and only while starting" {
    for (std.enums.values(Phase)) |phase| {
        for ([_]bool{ false, true }) |test_installing| {
            for ([_]bool{ false, true }) |overridden| {
                const expected: Writer = if (phase == .starting) .start else .refused;
                try std.testing.expectEqual(expected, writerOf(phase, test_installing, overridden, false));
            }
        }
    }
}

test "a test writes a hook through the start, a test start, or its own override - nothing else" {
    for (std.enums.values(Phase)) |phase| {
        // The process start, and the sanctioned test start, install.
        try std.testing.expectEqual(if (phase == .starting) Writer.start else Writer.refused, writerOf(phase, false, false, true));
        try std.testing.expectEqual(Writer.start, writerOf(phase, true, false, true));
        try std.testing.expectEqual(Writer.start, writerOf(phase, true, true, true));
        // A test writes into the slot it overrides; a start under way still
        // installs (under the override: hook.zig).
        try std.testing.expectEqual(if (phase == .starting) Writer.start else Writer.test_override, writerOf(phase, false, true, true));
    }
    // After start, a raw install - a test that swaps a hook it does not
    // override - is refused.
    try std.testing.expectEqual(Writer.refused, writerOf(.running, false, false, true));
    try std.testing.expectEqual(Writer.refused, writerOf(.not_started, false, false, true));
    try std.testing.expectEqual(Writer.refused, writerOf(.ended, false, false, true));
}

test "a test start makes hooks writable only while it runs" {
    const Probe = struct {
        var seen: ?Writer = null;
        fn install() void {
            seen = writer(false);
        }
    };
    installForTest(Probe.install);
    try std.testing.expectEqual(Writer.start, Probe.seen.?);
    if (get().phase != .starting) try std.testing.expectEqual(Writer.refused, writer(false));
}
