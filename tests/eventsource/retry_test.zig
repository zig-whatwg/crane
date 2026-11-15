//! Timer cancellation must free its callback without touching a dead source.
const std = @import("std");
const Retry = @import("eventsource").Retry(Timer);

const Timer = struct {
    state: *State,
    const State = struct {
        callback: ?*const fn (?*anyopaque) void = null,
        context: ?*anyopaque = null,
        /// What the timer runs for an owned timer still armed at its end; null for a plain one.
        drop: ?*const fn (?*anyopaque) void = null,
        delay: u64 = 0,
        clear_succeeds: bool = true,
        calls: usize = 0,
        clears: usize = 0,
        fn fire(self: *@This()) void {
            const callback = self.callback orelse return;
            self.callback = null;
            callback(self.context);
        }
        /// The timer manager's end with the timer armed, as NativeTimerManager.deinit ends: an owned
        /// timer's data is dropped, a plain one's is left to whoever armed it, and nothing fires again.
        fn end(self: *@This()) void {
            if (self.callback == null) return;
            self.callback = null;
            if (self.drop) |drop| drop(self.context);
        }
    };
    pub fn setTimeout(self: Timer, delay: u64, callback: *const fn (?*anyopaque) void, context: ?*anyopaque) u64 {
        self.state.delay = delay;
        self.state.callback = callback;
        self.state.context = context;
        self.state.drop = null;
        return 1;
    }
    pub fn setTimeoutOwned(self: Timer, delay: u64, callback: *const fn (?*anyopaque) void, context: ?*anyopaque, drop: *const fn (?*anyopaque) void) u64 {
        self.state.delay = delay;
        self.state.callback = callback;
        self.state.context = context;
        self.state.drop = drop;
        return 1;
    }
    pub fn clearTimeout(self: Timer, _: u64) bool {
        self.state.clears += 1;
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

test "the timer's end frees a pending ticket and detaches its owner" {
    // The timer manager ends with the wait pending (its event loop is gone): the callback never runs. The
    // ticket was armed with the plain form and nobody freed it - `cancel` frees only after a successful
    // clear, and an ended timer clears nothing (lane tl1).
    var state: Timer.State = .{};
    var retry: Retry = .{};
    try retry.start(std.testing.allocator, .{ .state = &state }, 600_000, reconnect, &state);
    state.end();
    // The owner lives on - a node can outlive its event loop - and no longer waits.
    try std.testing.expect(retry.ticket == null);
    // Its own end then clears nothing: the timer it would ask is gone.
    retry.cancel();
    try std.testing.expectEqual(@as(usize, 0), state.clears);
    try std.testing.expectEqual(@as(usize, 0), state.calls);
}

test "an owner cancelled before the timer's end leaves nothing for the end to drop" {
    var state: Timer.State = .{};
    var retry: Retry = .{};
    try retry.start(std.testing.allocator, .{ .state = &state }, 600_000, reconnect, &state);
    retry.cancel();
    try std.testing.expectEqual(@as(usize, 1), state.clears);
    state.end();
    try std.testing.expectEqual(@as(usize, 0), state.calls);
}
