//! Background timers (lane nd2 batch 5): the engine's own housekeeping - a
//! Document dropping its shared attribute blocks 10 s after its parse
//! (dom.attribute_block_cache) - fires as any timer does, when a poll finds
//! it due, but an armed one is not pending work. An event loop decides that
//! it is idle from `getActiveTimerCount`, how long to wait from
//! `getNextTimerDeadline`, and where a virtual clock moves from
//! `nextDeadlineNs` (src/browser/event_loop.zig): none of the three reads a
//! background timer. libuv's unreferenced handle (uv_unref) and Node's
//! `timeout.unref()`.

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

    fn advance(self: *ManualClock, ms: u64) void {
        self.ns += ms * std.time.ns_per_ms;
    }
};

/// What a test's timers did, in order: each timer's data is a `Mark` naming
/// the log and its own tag.
const Log = struct {
    order: [16]u8 = undefined,
    count: usize = 0,
    dropped: [16]u8 = undefined,
    drops: usize = 0,

    fn fired(self: *const Log) []const u8 {
        return self.order[0..self.count];
    }

    fn droppedTags(self: *const Log) []const u8 {
        return self.dropped[0..self.drops];
    }
};

const Mark = struct {
    log: *Log,
    tag: u8,

    fn fire(data: ?*anyopaque) void {
        const self: *Mark = @ptrCast(@alignCast(data.?));
        self.log.order[self.log.count] = self.tag;
        self.log.count += 1;
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Mark = @ptrCast(@alignCast(data.?));
        self.log.dropped[self.log.drops] = self.tag;
        self.log.drops += 1;
    }
};

test "an armed background timer is not pending work: no active count, no deadline to wait for or move a clock to" {
    var log: Log = .{};
    var manual: ManualClock = .{};
    var mgr = try NativeTimerManager.initWithClock(testing.allocator, manual.timerClock());
    defer mgr.deinit();
    const timers = mgr.timerInterface();

    var housekeeping: Mark = .{ .log = &log, .tag = 'h' };
    const id = timers.setBackgroundTimeout(10_000, Mark.fire, &housekeeping, Mark.drop);
    try testing.expect(id != 0);

    // What an event loop asks to decide that it is idle, how long to wait
    // and where to move a virtual clock: nothing.
    try testing.expectEqual(@as(usize, 0), mgr.getActiveTimerCount());
    try testing.expectEqual(@as(usize, 0), mgr.getPendingCount());
    try testing.expectEqual(@as(?u64, null), mgr.getNextTimerDeadline());
    try testing.expectEqual(@as(?i128, null), mgr.nextDeadlineNs());
    try testing.expectEqual(@as(c_int, -1), mgr.getBackendTimeout());
    // It is armed all the same, and says how long it has left.
    try testing.expectEqual(@as(usize, 1), mgr.getBackgroundTimerCount());
    try testing.expectEqual(@as(?u64, 10_000), timers.remainingMs(id));
    try testing.expect(mgr.isConsistent());

    // A page's timer beside it is the only one the loop waits for.
    var page: Mark = .{ .log = &log, .tag = 'p' };
    try testing.expect(timers.setTimeout(30_000, Mark.fire, &page) != 0);
    try testing.expectEqual(@as(usize, 1), mgr.getActiveTimerCount());
    try testing.expectEqual(@as(?u64, 30_000), mgr.getNextTimerDeadline());
    try testing.expectEqual(@as(?i128, manual.ns + 30_000 * std.time.ns_per_ms), mgr.nextDeadlineNs());

    // Not due: a poll fires nothing.
    manual.advance(9_999);
    try testing.expect(!mgr.poll());
    // Due: the next poll fires it, and it is gone. The page's timer stays.
    manual.advance(1);
    try testing.expect(mgr.poll());
    try testing.expectEqualSlices(u8, "h", log.fired());
    try testing.expectEqual(@as(usize, 0), mgr.getBackgroundTimerCount());
    try testing.expectEqual(@as(usize, 1), mgr.getActiveTimerCount());
    try testing.expectEqual(@as(?u64, null), timers.remainingMs(id));
    try testing.expect(!mgr.poll());
    try testing.expect(mgr.isConsistent());
    // The manager's end drops nothing of a timer that fired; the page's
    // plain timer was never the manager's to drop.
    try testing.expectEqual(@as(usize, 0), log.drops);
}

test "one poll fires background and ordinary timers together, in firing order" {
    var log: Log = .{};
    var manual: ManualClock = .{};
    var mgr = try NativeTimerManager.initWithClock(testing.allocator, manual.timerClock());
    defer mgr.deinit();
    const timers = mgr.timerInterface();

    var marks: [6]Mark = undefined;
    for (&marks, "abcdef") |*mark, tag| mark.* = .{ .log = &log, .tag = tag };
    // Deadlines 30, 10, 20, 10, 40 and 20 ms; b and d tie (arming order), as
    // do c and f.
    _ = timers.setBackgroundTimeout(30, Mark.fire, &marks[0], Mark.drop); // a
    _ = timers.setTimeout(10, Mark.fire, &marks[1]); // b
    _ = timers.setBackgroundTimeout(20, Mark.fire, &marks[2], Mark.drop); // c
    _ = timers.setBackgroundTimeout(10, Mark.fire, &marks[3], Mark.drop); // d
    _ = timers.setTimeout(40, Mark.fire, &marks[4]); // e
    _ = timers.setTimeout(20, Mark.fire, &marks[5]); // f
    try testing.expectEqual(@as(usize, 3), mgr.getActiveTimerCount());
    try testing.expectEqual(@as(usize, 3), mgr.getBackgroundTimerCount());
    try testing.expect(mgr.isConsistent());

    manual.advance(35);
    try testing.expect(mgr.poll());
    try testing.expectEqualSlices(u8, "bdcfa", log.fired());
    try testing.expect(mgr.isConsistent());
    manual.advance(5);
    try testing.expect(mgr.poll());
    try testing.expectEqualSlices(u8, "bdcfae", log.fired());
    try testing.expectEqual(@as(usize, 0), mgr.getActiveTimerCount() + mgr.getBackgroundTimerCount());
}

test "a cleared background timer never fires and hands its data back; the manager's end drops one still armed" {
    var log: Log = .{};
    var manual: ManualClock = .{};
    const mgr = try NativeTimerManager.initWithClock(testing.allocator, manual.timerClock());
    const timers = mgr.timerInterface();

    var cleared: Mark = .{ .log = &log, .tag = 'c' };
    var left: Mark = .{ .log = &log, .tag = 'l' };
    var middle: Mark = .{ .log = &log, .tag = 'm' };
    const first = timers.setBackgroundTimeout(10_000, Mark.fire, &cleared, Mark.drop);
    _ = timers.setBackgroundTimeout(20_000, Mark.fire, &left, Mark.drop);
    const third = timers.setBackgroundTimeout(15_000, Mark.fire, &middle, Mark.drop);
    try testing.expect(first != 0 and third != 0);

    // A confirmed clear: the data is the caller's again, nothing is called
    // for it - not at its deadline, not at the manager's end.
    try testing.expect(timers.clearTimeout(first));
    try testing.expect(!timers.clearTimeout(first));
    try testing.expect(mgr.isConsistent());
    try testing.expectEqual(@as(usize, 2), mgr.getBackgroundTimerCount());
    manual.advance(15_000);
    try testing.expect(mgr.poll());
    try testing.expectEqualSlices(u8, "m", log.fired());

    mgr.deinit();
    try testing.expectEqualSlices(u8, "m", log.fired());
    try testing.expectEqualSlices(u8, "l", log.droppedTags());
}

test "a background timer armed by a callback waits for the next poll, as any timer does" {
    const Rearm = struct {
        mgr: *NativeTimerManager,
        rounds: usize = 0,

        fn fire(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.rounds += 1;
            if (self.rounds < 3) _ = self.mgr.setBackgroundTimeout(0, fire, self, drop);
        }

        fn drop(_: ?*anyopaque) void {}
    };
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    var rearm: Rearm = .{ .mgr = mgr };
    try testing.expect(mgr.setBackgroundTimeout(0, Rearm.fire, &rearm, Rearm.drop) != 0);
    try testing.expect(mgr.poll());
    try testing.expectEqual(@as(usize, 1), rearm.rounds);
    try testing.expect(mgr.poll());
    try testing.expect(mgr.poll());
    try testing.expectEqual(@as(usize, 3), rearm.rounds);
    try testing.expect(!mgr.poll());
    try testing.expect(mgr.isConsistent());
}

test "an implementation without background timers arms nothing" {
    const Plain = struct {
        fn set(_: *anyopaque, _: u64, _: runtime.TimerCallback, _: ?*anyopaque) runtime.TimerId {
            return 7;
        }
        fn clear(_: *anyopaque, _: runtime.TimerId) bool {
            return false;
        }
        const vtable: runtime.TimerVTable = .{ .setTimeout = set, .clearTimeout = clear };
    };
    var context: u8 = 0;
    const timers: runtime.TimerInterface = .{ .vtable = &Plain.vtable, .ctx = &context };
    var log: Log = .{};
    var mark: Mark = .{ .log = &log, .tag = 'x' };
    // 0: the caller still owns its data.
    try testing.expectEqual(@as(runtime.TimerId, 0), timers.setBackgroundTimeout(10, Mark.fire, &mark, Mark.drop));
}
