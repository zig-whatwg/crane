//! Each timer is a task of its own: the hook an event loop gives
//! `pollEach` - its microtask checkpoint - runs after every callback, not
//! once after the batch (HTML 8.1.7.3: a microtask checkpoint follows each
//! task; "run steps after a timeout" queues one task per timer).

const std = @import("std");
const runtime = @import("runtime");
const NativeTimerManager = runtime.native_timer.NativeTimerManager;
const testing = std.testing;

/// The order callbacks and checkpoints ran in: 'a', 'b' for the timers, '|'
/// for the hook.
const Trace = struct {
    buffer: [16]u8 = undefined,
    len: usize = 0,

    fn push(self: *Trace, c: u8) void {
        self.buffer[self.len] = c;
        self.len += 1;
    }

    fn text(self: *const Trace) []const u8 {
        return self.buffer[0..self.len];
    }

    fn checkpoint(context: *anyopaque) void {
        const self: *Trace = @ptrCast(@alignCast(context));
        self.push('|');
    }
};

const Fire = struct {
    trace: *Trace,
    mark: u8,

    fn run(data: ?*anyopaque) void {
        const self: *Fire = @ptrCast(@alignCast(data.?));
        self.trace.push(self.mark);
    }
};

test "pollEach runs the event loop's hook after every timer callback" {
    var trace: Trace = .{};
    var a: Fire = .{ .trace = &trace, .mark = 'a' };
    var b: Fire = .{ .trace = &trace, .mark = 'b' };
    const mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    const timers = mgr.timerInterface();
    try testing.expect(timers.setTimeout(0, Fire.run, &a) != 0);
    try testing.expect(timers.setTimeout(0, Fire.run, &b) != 0);
    try testing.expect(mgr.pollEach(.{ .context = &trace, .run = Trace.checkpoint }));
    try testing.expectEqualStrings("a|b|", trace.text());
}

test "pollBlockingEach runs the hook after every callback too; poll runs none" {
    var trace: Trace = .{};
    var a: Fire = .{ .trace = &trace, .mark = 'a' };
    var b: Fire = .{ .trace = &trace, .mark = 'b' };
    const mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    const timers = mgr.timerInterface();
    _ = timers.setTimeout(0, Fire.run, &a);
    _ = timers.setTimeout(0, Fire.run, &b);
    try testing.expect(mgr.pollBlockingEach(5, .{ .context = &trace, .run = Trace.checkpoint }));
    try testing.expectEqualStrings("a|b|", trace.text());

    // The plain poll is the old batch: no hook.
    _ = timers.setTimeout(0, Fire.run, &a);
    try testing.expect(mgr.poll());
    try testing.expectEqualStrings("a|b|a", trace.text());
}
