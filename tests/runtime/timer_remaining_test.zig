//! NativeTimerManager.remainingMs (lane bfcache-b): the wait a pending timer
//! still has, which a suspension keeps instead of storing a due time per
//! timer (the back/forward cache; WebKit's SuspendableTimer saves its
//! next-fire interval the same way).

const std = @import("std");
const runtime = @import("runtime");
const NativeTimerManager = runtime.native_timer.NativeTimerManager;
const testing = std.testing;

var fired: u32 = 0;

fn count(_: ?*anyopaque) void {
    fired += 1;
}

test "remainingMs: a pending timer's wait, 0 past due, null once cancelled or fired" {
    fired = 0;
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    // Pending: what is left of its wait, rounded up, never more.
    const later = mgr.setTimeout(10_000, count, null);
    const left = mgr.remainingMs(later) orelse return error.NoWait;
    try testing.expect(left > 9_000 and left <= 10_000);
    // Past due, not yet fired: 0.
    const due = mgr.setTimeout(0, count, null);
    try testing.expectEqual(@as(?u64, 0), mgr.remainingMs(due));
    // Fired: gone.
    try testing.expect(mgr.poll());
    try testing.expectEqual(@as(u32, 1), fired);
    try testing.expectEqual(@as(?u64, null), mgr.remainingMs(due));
    // Cancelled: gone.
    try testing.expect(mgr.clearTimeout(later));
    try testing.expectEqual(@as(?u64, null), mgr.remainingMs(later));
    // Never this manager's.
    try testing.expectEqual(@as(?u64, null), mgr.remainingMs(12345));
    try testing.expectEqual(@as(?u64, null), mgr.remainingMs(0));
}

test "remainingMs through the timer interface" {
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    const timer = mgr.timerInterface();
    const id = timer.setTimeout(5_000, count, null);
    const left = timer.remainingMs(id) orelse return error.NoWait;
    try testing.expect(left > 4_000 and left <= 5_000);
    try testing.expect(timer.clearTimeout(id));
    try testing.expectEqual(@as(?u64, null), timer.remainingMs(id));
}
