//! The timer backend's blocking poll waits to its next timer's deadline
//! exactly, in nanoseconds, within the caller's bound and the backend's
//! 1 ms slice (lane ev2).
//!
//! It counted the time to the next timer in whole milliseconds, rounded
//! down, so a timer due in under a millisecond read as "due in 0": the poll
//! did not wait, found nothing due, and returned - and its caller, the V8
//! adapter's loop, turned without a wait until the timer was due
//! (tests/v8/ev2_adapter_loop_timer_wait_test.zig counts those turns).

const std = @import("std");
const runtime = @import("runtime");
const NativeTimerManager = runtime.native_timer.NativeTimerManager;
const testing = std.testing;

fn fire(data: ?*anyopaque) void {
    const fired: *bool = @ptrCast(@alignCast(data.?));
    fired.* = true;
}

test "a blocking poll bounded at a millisecond fires a timer due in under one: it waits to the deadline" {
    const mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    var fired = false;
    // A 1 ms timer reads as due in 0 whole milliseconds the moment it is
    // armed; its deadline is still almost a millisecond away.
    try testing.expect(mgr.setTimeout(1, fire, &fired) != 0);
    // One call, bounded at a millisecond: it waits the rest, then fires.
    // A poll fires only what is due, so firing says the wait reached the
    // deadline (the clock is the process's monotonic one).
    try testing.expect(mgr.pollBlockingEach(1, null));
    try testing.expect(fired);
    try testing.expectEqual(@as(usize, 0), mgr.getActiveTimerCount());
}

test "a blocking poll with a bound of 0 does not wait" {
    const mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    var fired = false;
    // Ten seconds away: never due in this test, however late its thread runs.
    try testing.expect(mgr.setTimeout(10_000, fire, &fired) != 0);
    const polls_before = mgr.probe.polls;
    try testing.expect(!mgr.pollBlockingEach(0, null));
    try testing.expect(!mgr.pollBlockingEachNs(0, null));
    // One poll each, and no wait: the timer is still armed.
    try testing.expectEqual(@as(u64, 2), mgr.probe.polls - polls_before);
    try testing.expect(!fired);
    try testing.expectEqual(@as(usize, 1), mgr.getActiveTimerCount());
}

test "a blocking poll bounded in nanoseconds waits its bound, not for a timer past it: it polls before and after and fires nothing" {
    const mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    var fired = false;
    try testing.expect(mgr.setTimeout(10_000, fire, &fired) != 0);
    const polls_before = mgr.probe.polls;
    // 50 microseconds, then the backend's whole slice, then a bound far past
    // the slice: each call polls, waits (its bound, or the 1 ms slice) and
    // polls again. The timer is ten seconds away.
    try testing.expect(!mgr.pollBlockingEachNs(50 * std.time.ns_per_us, null));
    try testing.expect(!mgr.pollBlockingEachNs(std.time.ns_per_ms, null));
    try testing.expect(!mgr.pollBlockingEachNs(std.math.maxInt(u64), null));
    try testing.expectEqual(@as(u64, 6), mgr.probe.polls - polls_before);
    try testing.expect(!fired);
    try testing.expectEqual(@as(usize, 1), mgr.getActiveTimerCount());
}

test "a blocking poll in nanoseconds fires what is due at once, and a timer due in under a millisecond after waiting for it" {
    const mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    var first = false;
    var second = false;
    // Due at once: fired by the poll before any wait.
    try testing.expect(mgr.setTimeout(0, fire, &first) != 0);
    const polls_before = mgr.probe.polls;
    try testing.expect(mgr.pollBlockingEachNs(std.time.ns_per_ms, null));
    try testing.expect(first);
    try testing.expectEqual(@as(u64, 1), mgr.probe.polls - polls_before);
    // Due in a millisecond, the bound two: one call waits to the deadline.
    try testing.expect(mgr.setTimeout(1, fire, &second) != 0);
    try testing.expect(mgr.pollBlockingEachNs(2 * std.time.ns_per_ms, null));
    try testing.expect(second);
    try testing.expectEqual(@as(usize, 0), mgr.getActiveTimerCount());
}
