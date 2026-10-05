//! Timers whose loop ends: an owned timer's user_data is dropped.
//!
//! A task deferred to a timer frees what it carries when it runs. A timer
//! manager that ends with the timer still armed frees its entry and never
//! calls it, so the data went with nothing (docs/lessons, "A task queued on a
//! loop that never runs again leaks its data"). `setTimeoutOwned` gives the
//! timer a destructor for its data, which the manager's end runs - once, and
//! only for a timer that never fired and was never cleared.

const std = @import("std");
const runtime = @import("runtime");
const NativeTimerManager = runtime.native_timer.NativeTimerManager;
const testing = std.testing;

const Payload = struct {
    fired: u32 = 0,
    dropped: u32 = 0,

    fn fire(data: ?*anyopaque) void {
        const self: *Payload = @ptrCast(@alignCast(data.?));
        self.fired += 1;
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Payload = @ptrCast(@alignCast(data.?));
        self.dropped += 1;
    }
};

test "the manager's end drops an owned timer's data that never fired" {
    var unfired: Payload = .{};
    var plain: Payload = .{};
    const mgr = try NativeTimerManager.init(testing.allocator);
    const timers = mgr.timerInterface();
    try testing.expect(timers.setTimeoutOwned(60_000, Payload.fire, &unfired, Payload.drop) != 0);
    // A plain timer's data stays its armer's: nothing is called for it.
    try testing.expect(timers.setTimeout(60_000, Payload.fire, &plain) != 0);
    mgr.deinit();
    try testing.expectEqual(@as(u32, 1), unfired.dropped);
    try testing.expectEqual(@as(u32, 0), unfired.fired);
    try testing.expectEqual(@as(u32, 0), plain.dropped + plain.fired);
}

test "an owned timer that fired, or that a clearTimeout removed, is not dropped" {
    var fired: Payload = .{};
    var cleared: Payload = .{};
    const mgr = try NativeTimerManager.init(testing.allocator);
    const timers = mgr.timerInterface();
    try testing.expect(timers.setTimeoutOwned(0, Payload.fire, &fired, Payload.drop) != 0);
    const id = timers.setTimeoutOwned(60_000, Payload.fire, &cleared, Payload.drop);
    try testing.expect(id != 0);
    try testing.expect(mgr.poll());
    // A successful clearTimeout hands the data back to the caller.
    try testing.expect(timers.clearTimeout(id));
    mgr.deinit();
    try testing.expectEqual(@as(u32, 1), fired.fired);
    try testing.expectEqual(@as(u32, 0), fired.dropped);
    try testing.expectEqual(@as(u32, 0), cleared.fired + cleared.dropped);
}

test "a timer interface without owned timers arms none" {
    const NoOwned = struct {
        fn set(_: *anyopaque, _: u64, _: runtime.TimerCallback, _: ?*anyopaque) runtime.TimerId {
            return 1;
        }
        fn clear(_: *anyopaque, _: runtime.TimerId) bool {
            return false;
        }
    };
    var ctx: u8 = 0;
    const timers: runtime.TimerInterface = .{
        .ctx = &ctx,
        .vtable = &.{ .setTimeout = NoOwned.set, .clearTimeout = NoOwned.clear },
    };
    var payload: Payload = .{};
    // It could not promise the drop: 0, and the caller keeps its data.
    try testing.expectEqual(@as(runtime.TimerId, 0), timers.setTimeoutOwned(0, Payload.fire, &payload, Payload.drop));
}
