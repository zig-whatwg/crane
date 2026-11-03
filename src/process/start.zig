//! The process's start-up, as every layer's hook slots see it (the `process`
//! module's `start`; src/dom re-exports it as `dom.process_start`).
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
//! A hook slot is a `Hook(T)` (hook.zig): its every write asks `writerOf`
//! - while the process starts, and never after, in every build mode. A test
//! installs through the sanctioned test start (`installForTest`, which the
//! generated `process_hooks.startHooksForTest()` runs its installs through) or
//! writes into its own scoped override of a slot (`Hook.overrideForTest`),
//! each counted here until it is restored: the test runner's digest checks
//! `outstandingOverrides()` is 0 after every test (Chromium's
//! ScopedFeatureList and base::TestSuite's check that a test left the
//! FeatureList as it found it; WebKit freezes its process-wide WTF::Config
//! after start-up - tmp/plans/hookfreeze-design.md). Every hook slot and
//! registration list is a `Hook(T)` (lane hookfreeze2 converted the last,
//! class P-res, and retired `assertInstalling`, which let a test write any
//! slot at any time).
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
    /// Set by the Crane test runner before its first test, read by the test
    /// thread's overrides (`observeOverridesForTest`).
    test_override_observer: ?OverrideObserver = null,
};

// process-wide: crane.Process's start-up phase; every hook slot (Hook(T), hook.zig) is written only while it is .starting
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
        "a hook ({s}) was written outside process start-up: a test installs hooks through process_hooks.startHooksForTest() (process.start.installForTest) and swaps one with overrideForTest (src/process/hook.zig)",
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

/// Told when the process's overrides go from none to one and back: the
/// many-Browsers variant's test runner holds its busy Browser between two
/// iterations from a test's first override to its last restore. An override
/// is a statement about the whole process - every Browser in it reads the
/// slot - so while one is outstanding nothing else runs there: the busy
/// Browser neither reads a slot the test thread writes (a data race,
/// ThreadSanitizer) nor runs on a test's fake hook. Its iteration holds
/// nothing between iterations, so holding it there takes nothing from it.
pub const OverrideObserver = struct {
    ctx: ?*anyopaque = null,
    /// Before the first outstanding override's write.
    first_made: *const fn (ctx: ?*anyopaque) void,
    /// After the last outstanding override's restore.
    last_restored: *const fn (ctx: ?*anyopaque) void,
};

/// Install the override observer (null: none), returning the one there
/// was. The Crane test runner's, once, before its first test.
pub fn observeOverridesForTest(observer: ?OverrideObserver) ?OverrideObserver {
    if (!builtin.is_test) @compileError("observeOverridesForTest is for the Crane test runner");
    const previous = state.test_override_observer;
    state.test_override_observer = observer;
    return previous;
}

/// hook.zig: an override is about to be made.
pub fn overrideMade() void {
    if (state.test_overrides.fetchAdd(1, .acq_rel) == 0) {
        if (state.test_override_observer) |observer| observer.first_made(observer.ctx);
    }
}

/// hook.zig: an override was restored.
pub fn overrideRestored() void {
    const before = state.test_overrides.fetchSub(1, .acq_rel);
    std.debug.assert(before > 0);
    if (before == 1) {
        if (state.test_override_observer) |observer| observer.last_restored(observer.ctx);
    }
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
