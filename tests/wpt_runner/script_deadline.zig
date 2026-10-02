//! A run's ceiling, enforced on script that will not return.
//!
//! Every run of a test file - one global, one variant: one test URL - has a
//! ceiling (config.Timeout: 10 s, or 60 s for `timeout=long`), counted from the
//! run's start, as wptrunner counts its per-URL timeout. The runner checks it
//! between event-loop turns (wpt_browser.waitForCompletion). Synchronous script
//! - a script the parser runs, a timer callback - holds the thread past it, and
//! nothing on that thread can stop it: three dom/nodes/NodeList-static-length-
//! getter-tampered-indexOf-*.html files ran until the supervisor's 150 s stall
//! kill, losing every result.
//!
//! This runs on a thread of its own. Once a run is past its ceiling by
//! `slack_ms` and the owner has not disarmed it, it aborts the agent's running
//! script (engine.abortRunningScript, HTML 8.1.4.5 "abort a running script")
//! - and again every `repeat_ms`, for scripts that start after, until the owner
//! disarms it. The slack leaves a run that is merely waiting time to reach its
//! own ceiling check, which ends it the ordinary way. The owner then lets the
//! agent run script again (engine.resumeScripts) so the harness can report what
//! ran, and records the run as TIMEOUT: it reached its ceiling.
//!
//! The abort itself is a callback, so this file is std-only and tested here;
//! the runner passes the engine's.

const std = @import("std");
const clock = @import("clock");

pub const ScriptDeadline = struct {
    pub const State = enum(u8) {
        /// No run is armed.
        idle,
        /// A run is armed and has not been aborted.
        armed,
        /// The thread is inside `abort` right now.
        aborting,
        /// The run has been aborted at least once.
        aborted,
    };

    /// Aborts the script running in `target` (the agent). Called on this
    /// struct's thread: it must be safe from any thread.
    abort: *const fn (target: ?*anyopaque) void,
    /// How far past the ceiling a run that has not disarmed is aborted.
    slack_ms: u64 = 1_000,
    /// How often an aborted run that is still armed is aborted again.
    repeat_ms: u64 = 1_000,
    /// How often the thread looks. The tests shorten it.
    poll_ms: u64 = 20,

    state: std.atomic.Value(State) = .init(.idle),
    /// The armed run's ceiling, in clock.monotonicMillis.
    deadline_ms: std.atomic.Value(i64) = .init(0),
    /// The armed run's agent, as an address.
    target: std.atomic.Value(usize) = .init(0),
    /// Aborts made in the armed run.
    aborts: std.atomic.Value(u32) = .init(0),
    /// When the thread last aborted. The thread's alone.
    last_abort_ms: i64 = 0,

    done: std.atomic.Value(bool) = .init(false),
    thread: ?std.Thread = null,

    pub fn start(self: *ScriptDeadline) !void {
        self.thread = try std.Thread.spawn(.{}, loop, .{self});
    }

    /// Stop the thread and join it. Disarm first.
    pub fn stop(self: *ScriptDeadline) void {
        self.done.store(true, .release);
        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    /// Watch a run whose ceiling is `deadline_ms` (clock.monotonicMillis), in
    /// the agent `target`. Replaces any run still armed.
    pub fn arm(self: *ScriptDeadline, target: ?*anyopaque, deadline_ms: i64) void {
        _ = self.disarm();
        self.target.store(@intFromPtr(target), .release);
        self.deadline_ms.store(deadline_ms, .release);
        self.aborts.store(0, .release);
        self.state.store(.armed, .release);
    }

    /// Stop watching the run, and say how many times its script was aborted.
    /// Nonzero: the agent may still be aborting, and the owner must resume it
    /// before it runs script again. Waits out an abort in progress, so that
    /// no abort lands after this returns.
    pub fn disarm(self: *ScriptDeadline) u32 {
        while (true) {
            const s = self.state.load(.acquire);
            switch (s) {
                .idle => return 0,
                .armed, .aborted => {
                    if (self.state.cmpxchgStrong(s, .idle, .acq_rel, .acquire) == null) {
                        return self.aborts.load(.acquire);
                    }
                },
                .aborting => std.atomic.spinLoopHint(),
            }
        }
    }

    /// Whether the armed run's script has been aborted. For the owner, between
    /// the steps of a run: past this, nothing in the run completes normally.
    pub fn abortedThisRun(self: *const ScriptDeadline) bool {
        return self.aborts.load(.acquire) > 0;
    }

    fn loop(self: *ScriptDeadline) void {
        while (!self.done.load(.acquire)) {
            clock.sleep(self.poll_ms * std.time.ns_per_ms);
            const now = clock.monotonicMillis();
            switch (self.state.load(.acquire)) {
                .armed => {
                    const due = self.deadline_ms.load(.acquire) + @as(i64, @intCast(self.slack_ms));
                    if (now >= due) self.fire(.armed, now);
                },
                .aborted => {
                    if (now >= self.last_abort_ms + @as(i64, @intCast(self.repeat_ms))) self.fire(.aborted, now);
                },
                .idle, .aborting => {},
            }
        }
    }

    fn fire(self: *ScriptDeadline, from: State, now: i64) void {
        // Claim the abort first: a disarm that wins this race means the run
        // ended in time, and its agent must not be aborted after it.
        if (self.state.cmpxchgStrong(from, .aborting, .acq_rel, .acquire) != null) return;
        self.abort(@ptrFromInt(self.target.load(.acquire)));
        _ = self.aborts.fetchAdd(1, .acq_rel);
        self.last_abort_ms = now;
        self.state.store(.aborted, .release);
    }
};

// ============================================================================
// Tests
// ============================================================================

const Seen = struct {
    var calls: std.atomic.Value(u32) = .init(0);
    var last_target: std.atomic.Value(usize) = .init(0);
    var hold_ms: u64 = 0;

    fn abort(target: ?*anyopaque) void {
        last_target.store(@intFromPtr(target), .release);
        if (hold_ms > 0) clock.sleep(hold_ms * std.time.ns_per_ms);
        _ = calls.fetchAdd(1, .acq_rel);
    }

    fn reset() void {
        calls.store(0, .release);
        last_target.store(0, .release);
        hold_ms = 0;
    }
};

var agent_stand_in: u8 = 0;

test "a run still in script past its ceiling and slack is aborted, then again until disarmed" {
    Seen.reset();
    var d: ScriptDeadline = .{ .abort = Seen.abort, .slack_ms = 30, .repeat_ms = 60, .poll_ms = 2 };
    try d.start();
    defer d.stop();

    d.arm(&agent_stand_in, clock.monotonicMillis() + 1_000);
    clock.sleep(20 * std.time.ns_per_ms);
    // Before the ceiling: nothing.
    try std.testing.expectEqual(@as(u32, 0), Seen.calls.load(.acquire));
    try std.testing.expect(!d.abortedThisRun());

    // Past ceiling + slack (1,030 ms), and past repeats every 60 ms after.
    clock.sleep(1_500 * std.time.ns_per_ms);
    const n = d.disarm();
    try std.testing.expect(n >= 2);
    try std.testing.expectEqual(n, Seen.calls.load(.acquire));
    try std.testing.expectEqual(@intFromPtr(&agent_stand_in), Seen.last_target.load(.acquire));

    // Disarmed: no more.
    clock.sleep(150 * std.time.ns_per_ms);
    try std.testing.expectEqual(n, Seen.calls.load(.acquire));
}

// The margins below are wide on purpose: on a loaded machine a 30 ms sleep has
// been seen to take 119 ms, and a margin that a late wake-up can cross makes
// the test measure the scheduler.

test "a run disarmed before its ceiling is never aborted" {
    Seen.reset();
    var d: ScriptDeadline = .{ .abort = Seen.abort, .slack_ms = 10, .repeat_ms = 20, .poll_ms = 2 };
    try d.start();
    defer d.stop();

    d.arm(&agent_stand_in, clock.monotonicMillis() + 2_000);
    clock.sleep(30 * std.time.ns_per_ms);
    try std.testing.expectEqual(@as(u32, 0), d.disarm());
    clock.sleep(200 * std.time.ns_per_ms);
    try std.testing.expectEqual(@as(u32, 0), Seen.calls.load(.acquire));
}

test "a run that waits past its ceiling inside the slack is not aborted" {
    // The owner's own ceiling check ends a run that is waiting, not in script,
    // within one event-loop poll: the slack is for it.
    Seen.reset();
    var d: ScriptDeadline = .{ .abort = Seen.abort, .slack_ms = 2_000, .poll_ms = 2 };
    try d.start();
    defer d.stop();

    d.arm(&agent_stand_in, clock.monotonicMillis() + 20);
    clock.sleep(80 * std.time.ns_per_ms);
    try std.testing.expectEqual(@as(u32, 0), d.disarm());
    try std.testing.expectEqual(@as(u32, 0), Seen.calls.load(.acquire));
}

test "a disarm during an abort waits for it, and reports it" {
    Seen.reset();
    Seen.hold_ms = 1_500;
    var d: ScriptDeadline = .{ .abort = Seen.abort, .slack_ms = 0, .repeat_ms = 10_000, .poll_ms = 2 };
    try d.start();
    defer d.stop();

    d.arm(&agent_stand_in, clock.monotonicMillis());
    // Let the thread enter the abort (it holds it 1.5 s).
    clock.sleep(100 * std.time.ns_per_ms);
    try std.testing.expectEqual(ScriptDeadline.State.aborting, d.state.load(.acquire));
    // The disarm returns only once the abort has, and counts it: the owner
    // resumes the agent after the abort, never before.
    try std.testing.expectEqual(@as(u32, 1), d.disarm());
    try std.testing.expectEqual(@as(u32, 1), Seen.calls.load(.acquire));
}

test "arming a new run resets its count" {
    Seen.reset();
    var d: ScriptDeadline = .{ .abort = Seen.abort, .slack_ms = 0, .repeat_ms = 10_000, .poll_ms = 2 };
    try d.start();
    defer d.stop();

    d.arm(&agent_stand_in, clock.monotonicMillis());
    clock.sleep(500 * std.time.ns_per_ms);
    try std.testing.expect(d.abortedThisRun());
    d.arm(&agent_stand_in, clock.monotonicMillis() + 10_000);
    try std.testing.expect(!d.abortedThisRun());
    try std.testing.expectEqual(@as(u32, 0), d.disarm());
}
