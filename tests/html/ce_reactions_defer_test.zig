const std = @import("std");
const testing = std.testing;
const Payload = struct {
    value: u32,
    drops: *usize,
    pub fn deinit(self: *@This()) void {
        self.drops.* += 1;
    }
};
const Queue = @import("html_core").custom_element_reactions.Reactions(u32, Payload);
const Log = struct {
    values: [8]u32 = undefined,
    len: usize = 0,
    fn invoke(self: *@This(), _: u32, payload: *Payload) void {
        self.values[self.len] = payload.value;
        self.len += 1;
    }
};

test "CE deferred scope: a pending exception defers the popped frame without invoking it" {
    var queue = Queue.init(testing.allocator);
    defer queue.deinit();
    var drops: usize = 0;
    var log = Log{};
    queue.begin();
    _ = try queue.enqueue(1, .{ .value = 10, .drops = &drops });
    queue.begin();
    _ = try queue.enqueue(2, .{ .value = 20, .drops = &drops });
    try testing.expect(try queue.deferCurrent());
    try testing.expectEqual(@as(usize, 1), queue.depth);
    try testing.expectEqual(@as(usize, 0), log.len);
    queue.end(&log, Log.invoke);
    try testing.expectEqualSlices(u32, &.{10}, log.values[0..log.len]);
    queue.invokeBackup(&log, Log.invoke);
    try testing.expectEqualSlices(u32, &.{ 10, 20 }, log.values[0..log.len]);
    try testing.expectEqual(@as(usize, 2), drops);
}

test "CE deferred scope: existing backup work keeps its order and its single scheduled microtask" {
    var queue = Queue.init(testing.allocator);
    defer queue.deinit();
    var drops: usize = 0;
    var log = Log{};
    try testing.expect(try queue.enqueue(1, .{ .value = 10, .drops = &drops }));
    queue.begin();
    _ = try queue.enqueue(2, .{ .value = 20, .drops = &drops });
    try testing.expect(!try queue.deferCurrent());
    queue.invokeBackup(&log, Log.invoke);
    try testing.expectEqualSlices(u32, &.{ 10, 20 }, log.values[0..log.len]);
    try testing.expectEqual(@as(usize, 2), drops);
    queue.begin();
    try testing.expect(!try queue.deferCurrent());
    try testing.expectEqual(@as(usize, 0), queue.depth);
}

fn allocationFailures(allocator: std.mem.Allocator) !void {
    var queue = Queue.init(allocator);
    var drops: usize = 0;
    var accepted: usize = 0;
    defer {
        queue.deinit();
        std.debug.assert(drops == accepted);
    }
    _ = try queue.enqueue(99, .{ .value = 99, .drops = &drops });
    accepted += 1;
    queue.begin();
    for (0..40) |i| {
        _ = try queue.enqueue(@intCast(i), .{ .value = @intCast(i), .drops = &drops });
        accepted += 1;
    }
    _ = try queue.deferCurrent();
}

test "CE deferred scope: failed queue transfer drops every accepted payload exactly once" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailures, .{});
}
