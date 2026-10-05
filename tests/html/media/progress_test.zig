//! Timers never run script, and cancellation detaches their owner before clear.
const std = @import("std");
const testing = std.testing;
const media = @import("html_core").media;
const Timer = struct {
    state: *State,
    const State = struct {
        callback: ?*const fn (?*anyopaque) void = null,
        context: ?*anyopaque = null,
        delay: u64 = 0,
        clear_succeeds: bool = true,
        unavailable: bool = false,
        fn fire(self: *@This()) void {
            const callback = self.callback.?;
            const context = self.context;
            self.callback = null;
            self.context = null;
            callback(context);
        }
    };
    pub fn setTimeout(self: @This(), ms: u64, callback: *const fn (?*anyopaque) void, context: ?*anyopaque) u64 {
        if (self.state.unavailable) return 0;
        self.state.callback = callback;
        self.state.context = context;
        self.state.delay = ms;
        return 1;
    }
    pub fn clearTimeout(self: @This(), _: u64) bool {
        if (!self.state.clear_succeeds) return false;
        self.state.callback = null;
        self.state.context = null;
        return true;
    }
};
fn count(context: *anyopaque) void {
    const value: *u32 = @ptrCast(@alignCast(context));
    value.* += 1;
}
test "media deadline fires once and frees its callback ticket" {
    var timer: Timer.State = .{};
    var calls: u32 = 0;
    var deadline: media.Deadline(Timer) = .{};
    defer deadline.cancel();
    try deadline.start(testing.allocator, .{ .state = &timer }, 350, count, &calls);
    try testing.expectEqual(@as(u64, 350), timer.delay);
    timer.fire();
    try testing.expectEqual(@as(u32, 1), calls);
    try testing.expect(!deadline.pending());
}
test "a late media timer callback never reaches its cancelled owner" {
    var timer: Timer.State = .{ .clear_succeeds = false };
    var calls: u32 = 0;
    const deadline = try testing.allocator.create(media.Deadline(Timer));
    deadline.* = .{};
    try deadline.start(testing.allocator, .{ .state = &timer }, 3000, count, &calls);
    deadline.cancel();
    testing.allocator.destroy(deadline);
    timer.fire();
    try testing.expectEqual(@as(u32, 0), calls);
}
test "media deadline frees failed and successfully cancelled tickets" {
    var timer: Timer.State = .{ .unavailable = true };
    var calls: u32 = 0;
    var deadline: media.Deadline(Timer) = .{};
    try testing.expectError(error.TimerUnavailable, deadline.start(testing.allocator, .{ .state = &timer }, 350, count, &calls));
    try testing.expect(!deadline.pending());
    timer.unavailable = false;
    try deadline.start(testing.allocator, .{ .state = &timer }, 350, count, &calls);
    deadline.cancel();
    deadline.cancel();
    try testing.expect(timer.context == null);
    try testing.expectEqual(@as(u32, 0), calls);
}
test "progress coalesces bytes and stalled fires at most once between data" {
    var progress: media.Progress = .{};
    try testing.expect(!progress.takeProgress());
    progress.received();
    progress.received();
    try testing.expect(progress.takeProgress());
    try testing.expect(!progress.takeProgress());
    try testing.expect(progress.takeStalled());
    try testing.expect(!progress.takeStalled());
    progress.received();
    try testing.expect(progress.takeProgress());
    try testing.expect(progress.takeStalled());
    progress.reset();
    try testing.expect(!progress.takeProgress());
}
