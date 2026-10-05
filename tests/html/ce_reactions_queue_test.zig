//! HTML 4.13.6 queue contracts, without starting an engine or changing globals.
const std = @import("std");
const testing = std.testing;
const Reactions = @import("html_core").custom_element_reactions.Reactions;

const Payload = struct {
    value: u32,
    dropped: *usize,

    pub fn deinit(self: *Payload) void {
        self.dropped.* += 1;
    }
};
const State = Reactions(u32, Payload);

const Log = struct {
    values: [64]u32 = undefined,
    len: usize = 0,
    state: *State,
    dropped: *usize,
    nest_on: ?u32 = null,
    backup_on: ?u32 = null,

    fn record(self: *Log, _: u32, payload: *Payload) void {
        self.values[self.len] = payload.value;
        self.len += 1;
        if (self.nest_on == payload.value) {
            self.nest_on = null;
            self.state.begin();
            _ = self.state.enqueue(2, .{ .value = 20, .dropped = self.dropped }) catch unreachable;
            // The same element's older reaction precedes the new one even
            // though the element occurs in another element queue.
            _ = self.state.enqueue(1, .{ .value = 30, .dropped = self.dropped }) catch unreachable;
            self.state.end(self, record);
            self.values[self.len] = 40;
            self.len += 1;
        }
        if (self.backup_on == payload.value) {
            self.backup_on = null;
            const scheduled = self.state.enqueue(2, .{ .value = 50, .dropped = self.dropped }) catch unreachable;
            std.debug.assert(!scheduled);
        }
    }
};

test "CE queues: empty brackets need no allocation even at deep nesting" {
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    var state = State.init(failing.allocator());
    defer state.deinit();
    var dropped: usize = 0;
    var log = Log{ .state = &state, .dropped = &dropped };
    for (0..128) |_| state.begin();
    for (0..128) |_| state.end(&log, Log.record);
    try testing.expectEqual(@as(usize, 0), log.len);
    try testing.expectEqual(@as(usize, 0), dropped);
    try testing.expect(!state.processing_backup);
}

test "CE queues: inner bracket drains before outer and each payload drops once" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var dropped: usize = 0;
    var log = Log{ .state = &state, .dropped = &dropped };
    state.begin();
    try testing.expect(!try state.enqueue(1, .{ .value = 1, .dropped = &dropped }));
    state.begin();
    try testing.expect(!try state.enqueue(2, .{ .value = 2, .dropped = &dropped }));
    state.end(&log, Log.record);
    try testing.expectEqualSlices(u32, &.{2}, log.values[0..log.len]);
    state.end(&log, Log.record);
    try testing.expectEqualSlices(u32, &.{ 2, 1 }, log.values[0..log.len]);
    try testing.expectEqual(@as(usize, 2), dropped);
}

test "CE queues: per-element FIFO survives nested invocation of the same element" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var dropped: usize = 0;
    var log = Log{ .state = &state, .dropped = &dropped, .nest_on = 1 };
    state.begin();
    _ = try state.enqueue(1, .{ .value = 1, .dropped = &dropped });
    _ = try state.enqueue(1, .{ .value = 10, .dropped = &dropped });
    state.end(&log, Log.record);
    try testing.expectEqualSlices(u32, &.{ 1, 20, 10, 30, 40 }, log.values[0..log.len]);
    try testing.expectEqual(@as(usize, 4), dropped);
}

test "CE queues: backup schedules once and waits for explicit microtask invocation" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var dropped: usize = 0;
    var log = Log{ .state = &state, .dropped = &dropped, .backup_on = 1 };
    try testing.expect(try state.enqueue(1, .{ .value = 1, .dropped = &dropped }));
    try testing.expect(!try state.enqueue(1, .{ .value = 2, .dropped = &dropped }));
    try testing.expect(state.processing_backup);
    try testing.expectEqual(@as(usize, 0), log.len);
    try testing.expectEqual(@as(usize, 0), dropped);
    state.invokeBackup(&log, Log.record);
    try testing.expectEqualSlices(u32, &.{ 1, 2, 50 }, log.values[0..log.len]);
    try testing.expect(!state.processing_backup);
    try testing.expectEqual(@as(usize, 3), dropped);
    try testing.expect(try state.enqueue(2, .{ .value = 3, .dropped = &dropped }));
    state.invokeBackup(&log, Log.record);
    try testing.expectEqual(@as(usize, 4), dropped);
}

test "CE queues: clearing one element releases its pending data without running it" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var dropped: usize = 0;
    var log = Log{ .state = &state, .dropped = &dropped };
    state.begin();
    _ = try state.enqueue(1, .{ .value = 1, .dropped = &dropped });
    _ = try state.enqueue(2, .{ .value = 2, .dropped = &dropped });
    _ = try state.enqueue(1, .{ .value = 3, .dropped = &dropped });
    state.clearElement(1);
    state.clearElement(1);
    try testing.expectEqual(@as(usize, 2), dropped);
    state.end(&log, Log.record);
    try testing.expectEqualSlices(u32, &.{2}, log.values[0..log.len]);
    try testing.expectEqual(@as(usize, 3), dropped);
}

test "CE queues: teardown of one agent leaves the other agent's queues intact" {
    var first = State.init(testing.allocator);
    var second = State.init(testing.allocator);
    defer second.deinit();
    var first_dropped: usize = 0;
    var second_dropped: usize = 0;
    var log = Log{ .state = &second, .dropped = &second_dropped };
    _ = try first.enqueue(1, .{ .value = 1, .dropped = &first_dropped });
    _ = try second.enqueue(1, .{ .value = 2, .dropped = &second_dropped });
    first.deinit();
    try testing.expectEqual(@as(usize, 1), first_dropped);
    try testing.expectEqual(@as(usize, 0), second_dropped);
    try testing.expect(second.processing_backup);
    second.invokeBackup(&log, Log.record);
    try testing.expectEqualSlices(u32, &.{2}, log.values[0..log.len]);
    try testing.expectEqual(@as(usize, 1), second_dropped);
}

test "CE queues: teardown drops reactions in every unpopped frame and backup" {
    var state = State.init(testing.allocator);
    var dropped: usize = 0;
    _ = try state.enqueue(1, .{ .value = 1, .dropped = &dropped });
    state.begin();
    _ = try state.enqueue(2, .{ .value = 2, .dropped = &dropped });
    state.begin();
    _ = try state.enqueue(3, .{ .value = 3, .dropped = &dropped });
    state.deinit();
    try testing.expectEqual(@as(usize, 3), dropped);
}

fn exerciseAllocationFailure(allocator: std.mem.Allocator) !void {
    var state = State.init(allocator);
    var dropped: usize = 0;
    var accepted: usize = 0;
    defer {
        state.deinit();
        std.debug.assert(dropped == accepted);
    }
    state.begin();
    for (0..24) |index| {
        _ = try state.enqueue(@intCast(index % 8), .{ .value = @intCast(index), .dropped = &dropped });
        accepted += 1;
    }
}

test "CE queues: failed enqueue retains caller ownership at every allocation site" {
    try testing.checkAllAllocationFailures(testing.allocator, exerciseAllocationFailure, .{});
}
