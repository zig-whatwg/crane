//! The V8 adapter's own event loop (`V8EventLoop.runOnceBlocking`, the loop
//! of a standalone runtime) waits through a timer's last sub-millisecond: it
//! does not turn without a wait until the timer is due (lane ev2; the
//! queue's "From lane flk2" entry).
//!
//! The loop counted the time to its next timer in whole milliseconds,
//! rounded down, and took "under a millisecond" for "nothing to wait for":
//! it waited for all but the last fraction of a millisecond, then turned -
//! a microtask checkpoint, V8's platform pump and a timer poll each time -
//! until the timer was due. Lane flk2 measured the same rule in the window
//! and worker loops at 510 turns and 0.85 ms of the loop thread's CPU for
//! every 3 ms timer on server1, and a busy host's scheduler then ran that
//! thread late (tests/html/rep2_window_wake_test.zig). Every browser's loop
//! waits for its next delayed task to the exact remaining delay: Chromium's
//! pump sleeps on its event for `next_work_info.remaining_delay()`
//! (base/message_loop/message_pump_default.cc, MessagePumpDefault::Run).
//!
//! A count, never a bound in milliseconds: how soon a woken thread runs is
//! the host's (docs/lessons/
//! testing-a-lateness-bound-in-milliseconds-measures-the-hosts-scheduler.md).

const std = @import("std");
const test_process = @import("test_process.zig");
const v8 = @import("v8");
const runtime = @import("runtime");

/// The test's own agent, ended with the test (test_process.TestAgent): a
/// turn performs a microtask checkpoint, which needs an entered context.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {}

/// A chain of timers of `delay_ms`, each armed by the one before's
/// callback: `remaining` more after the first.
const Chain = struct {
    timers: runtime.TimerInterface,
    remaining: usize,
    delay_ms: u64 = 1,
    fired: usize = 0,

    fn arm(self: *Chain) !void {
        if (self.timers.setTimeout(self.delay_ms, fire, self) == 0) return error.TimerNotArmed;
    }

    fn fire(data: ?*anyopaque) void {
        const self: *Chain = @ptrCast(@alignCast(data.?));
        self.fired += 1;
        if (self.remaining == 0) return;
        self.remaining -= 1;
        self.arm() catch {};
    }
};

test "the adapter's loop waits through a timer's last sub-millisecond: it does not turn without a wait until the timer is due" {
    defer test_agent.close();
    const isolate = try test_agent.open(.{});
    var loop = try v8.V8EventLoop.init(isolate, std.testing.allocator);
    defer loop.deinit();
    const mgr = loop.timer_manager orelse return error.NoTimers;

    // Forty 1 ms timers: each is under a millisecond away from the moment
    // it is armed, so the whole of its delay is "the last sub-millisecond"
    // - on any host, however long its sleeps really take. (Forty 3 ms
    // timers showed the same on server1, 176,325 polls, and nothing on
    // chat2.local, where a 1 ms sleep takes long enough that two of them
    // reach a 3 ms deadline.)
    const count = 40;
    var chain: Chain = .{ .timers = loop.timerInterface().?, .remaining = count - 1 };
    try chain.arm();
    const polls_before = mgr.probe.polls;
    // The caller's bound is far past every deadline: only a timer's
    // deadline ends a wait sooner than the backend's 1 ms slice.
    var turns: usize = 0;
    while (chain.fired < count) : (turns += 1) {
        if (turns > 1_000_000) return error.ChainNeverEnded;
        _ = loop.runOnceBlocking(10_000);
    }
    const polls = mgr.probe.polls - polls_before;
    // Every turn polls its timers once, and a second time after a wait
    // (native_timer pollBlockingEachNs). A loop that WAITS for a 1 ms timer
    // makes one wait to its deadline, and one more turn if the wait ended a
    // moment early: two turns, four polls, for each timer. The bound allows
    // ten turns a timer.
    const poll_bound = count * 10 * 2;
    if (polls > poll_bound) {
        std.log.warn("{d} timer polls in {d} turns for forty 1 ms timers (at most {d} when the loop waits for each)", .{ polls, turns, poll_bound });
        return error.LoopTurnsWithoutWaiting;
    }
    try std.testing.expectEqual(@as(usize, count), chain.fired);
}

test "the adapter's loop still does not wait when its caller asks for a turn that does not block" {
    defer test_agent.close();
    const isolate = try test_agent.open(.{});
    var loop = try v8.V8EventLoop.init(isolate, std.testing.allocator);
    defer loop.deinit();
    const mgr = loop.timer_manager orelse return error.NoTimers;

    // Ten seconds away - never due in this test, however late its thread
    // runs: a turn bounded at 0 returns at once, its timer still armed,
    // however many times it is asked.
    var chain: Chain = .{ .timers = loop.timerInterface().?, .remaining = 0, .delay_ms = 10_000 };
    try chain.arm();
    const polls_before = mgr.probe.polls;
    for (0..3) |_| _ = loop.runOnceBlocking(0);
    try std.testing.expectEqual(@as(usize, 0), chain.fired);
    try std.testing.expectEqual(@as(u64, 3), mgr.probe.polls - polls_before);
    try std.testing.expect(loop.hasPendingWork());
}
