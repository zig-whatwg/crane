//! NativeTimerManager's clock (lane detplat1): a manager its owner gives a
//! clock reads every deadline against it, so a Browser's virtual clock
//! (platform.BrowserClock) - not real time - decides when its timers come
//! due, as Chromium's MOCK_TIME does for delayed tasks. A manager given none
//! reads the process's monotonic clock, as before.

const std = @import("std");
const runtime = @import("runtime");
const NativeTimerManager = runtime.native_timer.NativeTimerManager;
const testing = std.testing;

/// A clock that moves only when the test moves it.
const ManualClock = struct {
    ns: u64 = 5 * std.time.ns_per_s,

    fn now(context: ?*anyopaque) callconv(.c) u64 {
        const self: *ManualClock = @ptrCast(@alignCast(context.?));
        return self.ns;
    }

    fn timerClock(self: *ManualClock) runtime.native_timer.Clock {
        return .{ .context = self, .monotonic_now = now };
    }
};

const Fired = struct {
    order: [8]u8 = undefined,
    count: usize = 0,

    fn record(self: *Fired, tag: u8) void {
        self.order[self.count] = tag;
        self.count += 1;
    }
};

var fired: Fired = .{};

fn tagged(comptime tag: u8) fn (?*anyopaque) void {
    return struct {
        fn f(_: ?*anyopaque) void {
            fired.record(tag);
        }
    }.f;
}

test "a manager given a clock comes due on that clock, not on real time" {
    fired = .{};
    var manual: ManualClock = .{};
    var mgr = try NativeTimerManager.initWithClock(testing.allocator, manual.timerClock());
    defer mgr.deinit();
    const start = manual.ns;

    _ = mgr.setTimeout(30, tagged('c'), null);
    _ = mgr.setTimeout(10, tagged('a'), null);
    _ = mgr.setTimeout(20, tagged('b'), null);
    try testing.expectEqual(@as(?i128, start + 10 * std.time.ns_per_ms), mgr.nextDeadlineNs());
    try testing.expectEqual(@as(?u64, 10), mgr.getNextTimerDeadline());

    // Real time passes; the manager's clock does not: nothing is due.
    std.Thread.yield() catch {};
    try testing.expect(!mgr.poll());
    try testing.expectEqual(@as(usize, 0), fired.count);

    // One nanosecond short: still not due.
    manual.ns = start + 10 * std.time.ns_per_ms - 1;
    try testing.expect(!mgr.poll());
    // Moved to the exact deadline: the first fires, alone.
    manual.ns = start + 10 * std.time.ns_per_ms;
    try testing.expect(mgr.poll());
    try testing.expectEqualSlices(u8, "a", fired.order[0..fired.count]);
    // The 20 ms timer (id 3) has 10 ms left on the manager's clock.
    try testing.expectEqual(@as(?u64, 10), mgr.remainingMs(3));

    // Past both others at once: they fire in deadline order.
    manual.ns = start + 1 * std.time.ns_per_s;
    try testing.expect(mgr.poll());
    try testing.expectEqualSlices(u8, "abc", fired.order[0..fired.count]);
    try testing.expectEqual(@as(?i128, null), mgr.nextDeadlineNs());
}

test "a manager given no clock reads the process's monotonic clock" {
    fired = .{};
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    const before = mgr.nowNs();
    _ = mgr.setTimeout(0, tagged('z'), null);
    const due = mgr.nextDeadlineNs() orelse return error.NoTimer;
    try testing.expect(due >= before and due <= mgr.nowNs());
    try testing.expect(mgr.poll());
    try testing.expectEqualSlices(u8, "z", fired.order[0..fired.count]);
}
