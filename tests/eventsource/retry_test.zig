//! Timer cancellation must free its callback without touching a dead source.
const std = @import("std");
const Retry = @import("eventsource").Retry(Timer);

const Timer = struct {
    state: *State,
    const State = struct {
        callback: ?*const fn (?*anyopaque) void = null,
        context: ?*anyopaque = null,
        delay: u64 = 0,
        clear_succeeds: bool = true,
        calls: usize = 0,
        fn fire(self: *@This()) void {
            const callback = self.callback orelse return;
            self.callback = null;
            callback(self.context);
        }
    };
    pub fn setTimeout(self: Timer, delay: u64, callback: *const fn (?*anyopaque) void, context: ?*anyopaque) u64 {
        self.state.delay = delay;
        self.state.callback = callback;
        self.state.context = context;
        return 1;
    }
    pub fn clearTimeout(self: Timer, _: u64) bool {
        if (!self.state.clear_succeeds) return false;
        const found = self.state.callback != null;
        self.state.callback = null;
        return found;
    }
};

fn reconnect(context: *anyopaque) void {
    const state: *Timer.State = @ptrCast(@alignCast(context));
    state.calls += 1;
}

test "retry clear releases its callback allocation exactly once" {
    var state: Timer.State = .{};
    var retry: Retry = .{};
    try retry.start(std.testing.allocator, .{ .state = &state }, 23, reconnect, &state);
    try std.testing.expect(state.callback != null);
    try std.testing.expectEqual(@as(u64, 23), state.delay);
    retry.cancel();
    retry.cancel();
    try std.testing.expect(state.callback == null);
    try std.testing.expectEqual(@as(usize, 0), state.calls);
}

test "retry callback releases itself and calls reconnect once" {
    var state: Timer.State = .{};
    var retry: Retry = .{};
    try retry.start(std.testing.allocator, .{ .state = &state }, 0, reconnect, &state);
    state.fire();
    retry.cancel();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
}

test "unsuccessful clear detaches the source until the late callback frees itself" {
    var state: Timer.State = .{ .clear_succeeds = false };
    {
        const retry = try std.testing.allocator.create(Retry);
        defer std.testing.allocator.destroy(retry);
        retry.* = .{};
        try retry.start(std.testing.allocator, .{ .state = &state }, 10, reconnect, &state);
        try std.testing.expect(state.callback != null);
        retry.cancel();
    }
    state.fire();
    try std.testing.expectEqual(@as(usize, 0), state.calls);
}
