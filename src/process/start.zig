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
    /// The install lock: held by the process start from `begin` to `finish`
    /// (or to the `end` of a start that failed), and by a test start
    /// (`installForTest`) while it installs - so the two never install at
    /// once. Every registry checks for an entry and then appends, and every
    /// slot compares and then writes: two writers inside that window both
    /// write (the many-Browsers variant's busy Browser started the process on
    /// its thread while a test's startHooksForTest() ran the same installs,
    /// and attribute_change_steps overflowed - lane testfix2's
    /// om1_preferred_sheets crash). Taken once, uncontended, by a production
    /// start. NO DEADLOCK: neither holder waits for the other while it holds
    /// it - the start's steps (platform, engine, curl, installHooks, the UA
    /// sheets) never wait on a test thread, a test start only installs, and
    /// a waiter holds nothing either needs (it blocks before it takes
    /// anything; a test's override, which holds the busy Browser, is never
    /// made inside a test start). The thread that holds it may take it
    /// again (`installs_holder`): tests/v8's test_process.start() claims the
    /// start (`begin`) and then runs startHooksForTest() - a test start - on
    /// the same thread, which a plain lock would make wait on itself forever
    /// (lane hookfreeze2's first gate hung every tests-v8 process that way).
    installs: std.Io.Mutex = .init,
    /// The thread holding `installs` (0: none) - only ever compared with
    /// the caller's own id, so a stale read is never this thread's.
    installs_holder: std.atomic.Value(std.Thread.Id) = .init(0),
    test_installing: std.atomic.Value(u32) = .init(0),
    test_overrides: std.atomic.Value(u32) = .init(0),
    /// Set by the Crane test runner before its first test, read by the test
    /// thread's overrides (`observeOverridesForTest`).
    test_override_observer: ?OverrideObserver = null,

    /// Take the install lock - or nothing, when this thread holds it
    /// already: true when this call took it (and its caller gives it back).
    fn lockInstalls(self: *Start) bool {
        const me = std.Thread.getCurrentId();
        if (self.installs_holder.load(.acquire) == me) return false;
        std.Io.Threaded.mutexLockUncancelable(&self.installs);
        self.installs_holder.store(me, .release);
        return true;
    }

    fn unlockInstalls(self: *Start) void {
        self.installs_holder.store(0, .release);
        std.Io.Threaded.mutexUnlock(&self.installs);
    }

    fn begin(self: *Start) bool {
        if (self.word.cmpxchgStrong(.{}, .{ .phase = .starting }, .acq_rel, .acquire) != null) return false;
        // A test start installing now on another thread finishes first;
        // none starts until `finish` (or a failed start's `end`). A start
        // claimed inside this thread's own test start would give the lock
        // back at `finish` while that test start still installs.
        if (!self.lockInstalls()) std.debug.panic("the process start was begun inside a test start (installForTest) on the same thread", .{});
        return true;
    }

    fn finish(self: *Start, has_snapshot: bool) void {
        std.debug.assert(self.word.load(.acquire).phase == .starting);
        self.word.store(.{ .phase = .running, .has_snapshot = has_snapshot }, .release);
        self.unlockInstalls();
    }

    fn end(self: *Start) void {
        const before = self.word.swap(.{ .phase = .ended }, .acq_rel);
        // A start that failed mid-install (crane.Process.init's error paths
        // end it from .starting) gives the lock back; a finished one gave it
        // back in `finish`.
        if (endReleasesInstalls(before.phase)) self.unlockInstalls();
    }

    fn installForTest(self: *Start, comptime install: fn () void) void {
        // Inside this thread's own process start (tests/v8 test_process.start)
        // or test start, the lock is already this thread's.
        const took = self.lockInstalls();
        defer if (took) self.unlockInstalls();
        _ = self.test_installing.fetchAdd(1, .acq_rel);
        defer _ = self.test_installing.fetchSub(1, .acq_rel);
        install();
    }
};

/// Whether `end` from `phase` gives the install lock back: only a start that
/// never finished holds it.
fn endReleasesInstalls(phase: Phase) bool {
    return phase == .starting;
}

// process-wide: crane.Process's start-up phase; every hook slot (Hook(T), hook.zig) is written only while it is .starting
var state: Start = .{};

/// The current start-up state.
pub fn get() State {
    return state.word.load(.acquire);
}

/// Claim the start: not_started -> starting. False when another caller has
/// claimed it (or it has run); that caller finishes it.
pub fn begin() bool {
    return state.begin();
}

/// starting -> running: every hook is installed.
pub fn finish(has_snapshot: bool) void {
    state.finish(has_snapshot);
}

/// running -> ended, or starting -> ended for a start that failed.
pub fn end() void {
    state.end();
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
/// start installed changes nothing. Never at once with the process start
/// (the install lock, `Start.installs`): a test start waits for a start
/// under way on another thread, and the start waits for it.
pub fn installForTest(comptime install: fn () void) void {
    if (!builtin.is_test) @compileError("installForTest is for tests; a host starts crane.Process");
    state.installForTest(install);
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

test "a start that fails mid-install gives the install lock back; a finished one gave it back already" {
    // On a Start of the test's own: the process's is left alone.
    for ([_]Phase{ .not_started, .starting, .running, .ended }) |phase| {
        try std.testing.expectEqual(phase == .starting, endReleasesInstalls(phase));
    }
    var failed: Start = .{};
    try std.testing.expect(failed.begin());
    try std.testing.expect(!failed.installs.tryLock());
    failed.end(); // crane.Process.init's error path
    try std.testing.expect(failed.installs.tryLock());
    std.Io.Threaded.mutexUnlock(&failed.installs);

    var finished: Start = .{};
    try std.testing.expect(finished.begin());
    finished.finish(false);
    try std.testing.expect(finished.installs.tryLock());
    std.Io.Threaded.mutexUnlock(&finished.installs);
    finished.end(); // Process.deinit: nothing to give back
    try std.testing.expect(finished.installs.tryLock());
    std.Io.Threaded.mutexUnlock(&finished.installs);
}

test "the process start's own test start, on its thread, does not wait on itself (tests/v8 test_process.start: begin, then startHooksForTest)" {
    // tests/v8/test_process.zig's start() claims the start (begin) and then
    // runs startHooksForTest() - installForTest - on the same thread: the
    // install lock it already holds. Run on a thread of its own, so a wait
    // on itself shows as a bounded timeout, not a hung test.
    const Own = struct {
        var start: Start = .{};
        var installed: std.atomic.Value(bool) = .init(false);
        var done: std.atomic.Value(bool) = .init(false);
        fn install() void {
            installed.store(true, .release);
        }
        fn run() void {
            if (!start.begin()) return;
            start.installForTest(install);
            start.finish(false);
            done.store(true, .release);
        }
    };
    const thread = try std.Thread.spawn(.{}, Own.run, .{});
    var spins: u32 = 0;
    while (!Own.done.load(.acquire) and spins < 2_000_000) : (spins += 1) std.Thread.yield() catch {};
    if (!Own.done.load(.acquire)) {
        // Left blocked on its own lock: the process's exit ends it.
        thread.detach();
        return error.TestStartWaitedOnItsOwnProcessStart;
    }
    thread.join();
    try std.testing.expect(Own.installed.load(.acquire));
    // And the lock is free after the start finished.
    try std.testing.expect(Own.start.installs.tryLock());
    std.Io.Threaded.mutexUnlock(&Own.start.installs);
}

test "ending the process leaves the install lock free from every phase" {
    // Not started: nothing to give back.
    var never: Start = .{};
    never.end();
    try std.testing.expect(never.installs.tryLock());
    std.Io.Threaded.mutexUnlock(&never.installs);
    // Starting: a start that failed mid-install gives it back.
    var failed: Start = .{};
    try std.testing.expect(failed.begin());
    failed.end();
    try std.testing.expect(failed.installs.tryLock());
    std.Io.Threaded.mutexUnlock(&failed.installs);
    // Running: finish gave it back; end gives nothing back twice.
    var running: Start = .{};
    try std.testing.expect(running.begin());
    running.finish(false);
    running.end();
    try std.testing.expect(running.installs.tryLock());
    std.Io.Threaded.mutexUnlock(&running.installs);
    // Ended: ending again gives nothing back.
    running.end();
    try std.testing.expect(running.installs.tryLock());
    std.Io.Threaded.mutexUnlock(&running.installs);
}

test "a test start waits for a process start under way, holding nothing it needs, and then goes in" {
    const Order = struct {
        var start: Start = .{};
        var started_finishing: std.atomic.Value(bool) = .init(false);
        var test_start_ran: std.atomic.Value(bool) = .init(false);
        var ran_after_finish: bool = false;
        fn install() void {
            ran_after_finish = started_finishing.load(.acquire);
            test_start_ran.store(true, .release);
        }
        fn testStart() void {
            start.installForTest(install);
        }
    };
    try std.testing.expect(Order.start.begin());
    const thread = try std.Thread.spawn(.{}, Order.testStart, .{});
    // The test start is blocked on the start's lock: it has not run.
    var spins: u32 = 0;
    while (spins < 100_000) : (spins += 1) std.Thread.yield() catch {};
    try std.testing.expect(!Order.test_start_ran.load(.acquire));
    Order.started_finishing.store(true, .release);
    Order.start.finish(false);
    thread.join();
    try std.testing.expect(Order.test_start_ran.load(.acquire));
    try std.testing.expect(Order.ran_after_finish);
}

test "a test start and the process start never install at once: a list both install into keeps one copy of each entry" {
    // The many-Browsers variant's crash (lane testfix2, om1_preferred_sheets):
    // the busy Browser's first iteration started the process on its thread
    // while the test's startHooksForTest() re-ran the same installs on the
    // test thread. Each registry checks for its entry, then appends: two
    // writers in that window both append, and attribute_change_steps
    // overflowed its 32 entries. Here the test start stops between its check
    // and its append, and the process start begins meanwhile.
    //
    // It begins the start of this test binary's process (once; finished
    // here): only where nothing has.
    if (get().phase != .not_started) return error.SkipZigTest;
    const hook = @import("hook.zig");
    const Race = struct {
        var list: hook.Hook(hook.List(u32, 8)) = .init(.empty);
        var test_start_checked: std.atomic.Value(bool) = .init(false);
        var process_start_beginning: std.atomic.Value(bool) = .init(false);
        var process_start_installed: std.atomic.Value(bool) = .init(false);

        /// The test start's install: check, let the process start begin and
        /// install if it can (a bounded wait: it cannot while the two
        /// exclude each other), append.
        fn testStartInstall() void {
            const entries = list.installing();
            if (entries.contains(7)) return;
            test_start_checked.store(true, .release);
            while (!process_start_beginning.load(.acquire)) std.Thread.yield() catch {};
            var spins: u32 = 0;
            while (!process_start_installed.load(.acquire) and spins < 200_000) : (spins += 1) {
                std.Thread.yield() catch {};
            }
            entries.append(7);
        }

        fn testStart() void {
            installForTest(testStartInstall);
        }

        /// The process start's install, as crane.Process makes it.
        fn processStartInstall() void {
            const entries = list.installing();
            if (!entries.contains(7)) entries.append(7);
            process_start_installed.store(true, .release);
        }
    };
    const thread = try std.Thread.spawn(.{}, Race.testStart, .{});
    while (!Race.test_start_checked.load(.acquire)) std.Thread.yield() catch {};
    // The process start, while the test start is between its check and its
    // append.
    Race.process_start_beginning.store(true, .release);
    if (!begin()) {
        thread.join();
        return error.SkipZigTest;
    }
    Race.processStartInstall();
    finish(false);
    thread.join();
    try std.testing.expectEqualSlices(u32, &.{7}, Race.list.read().slice());
}
