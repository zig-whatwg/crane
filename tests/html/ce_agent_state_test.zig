const std = @import("std");
const testing = std.testing;
const AgentState = @import("html_core").custom_element_agent.AgentState;

const Counts = struct { held: usize = 0, released: usize = 0, dropped: usize = 0 };
const Root = struct {
    counts: *Counts,
    pub fn release(self: Root) void {
        self.counts.released += 1;
    }
};
const Payload = struct {
    value: u32,
    counts: *Counts,
    pub fn deinit(self: *Payload) void {
        self.counts.dropped += 1;
    }
};
fn realmIsLive(realm: u32) bool {
    return realm != 99;
}
const Returns = @import("html_core").custom_element_returns.PendingReturns(u32, Root);
const State = AgentState(u32, u32, Payload, Root, Returns, realmIsLive);
fn acquire(counts: *Counts, _: u32) !Root {
    counts.held += 1;
    return .{ .counts = counts };
}
const Log = struct {
    state: *State,
    counts: *Counts,
    values: [16]u32 = undefined,
    len: usize = 0,
    cancel_on: ?u32 = null,
    fn invoke(self: *Log, _: u32, reaction: *Payload) void {
        self.values[self.len] = reaction.value;
        self.len += 1;
        if (self.cancel_on == reaction.value) {
            self.cancel_on = null;
            self.state.clearRealm(10);
            // A freed instance address may be reused in another realm. Its
            // old element-queue slot must not invoke this new object's work.
            _ = self.state.enqueue(self.counts, 1, 20, .{ .value = 4, .counts = self.counts }, acquire) catch unreachable;
        }
    }
};

test "CE agent: realm cleanup drops only that realm and releases its roots" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var counts = Counts{};
    var log = Log{ .state = &state, .counts = &counts };
    state.begin();
    _ = try state.enqueue(&counts, 1, 10, .{ .value = 1, .counts = &counts }, acquire);
    _ = try state.enqueue(&counts, 1, 10, .{ .value = 2, .counts = &counts }, acquire);
    _ = try state.enqueue(&counts, 2, 20, .{ .value = 3, .counts = &counts }, acquire);
    try testing.expectEqual(@as(usize, 2), counts.held);
    state.clearRealm(10);
    try testing.expectEqual(@as(usize, 2), counts.dropped);
    try testing.expectEqual(@as(usize, 1), counts.released);
    state.end(&log, Log.invoke);
    try testing.expectEqualSlices(u32, &.{3}, log.values[0..log.len]);
    try testing.expectEqual(counts.held, counts.released);
    try testing.expectEqual(@as(usize, 3), counts.dropped);
}

test "CE agent: realm teardown during invocation leaves no stale element access" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var counts = Counts{};
    var log = Log{ .state = &state, .counts = &counts, .cancel_on = 1 };
    state.begin();
    _ = try state.enqueue(&counts, 1, 10, .{ .value = 1, .counts = &counts }, acquire);
    _ = try state.enqueue(&counts, 1, 10, .{ .value = 2, .counts = &counts }, acquire);
    _ = try state.enqueue(&counts, 2, 20, .{ .value = 3, .counts = &counts }, acquire);
    state.end(&log, Log.invoke);
    try testing.expectEqualSlices(u32, &.{ 1, 3 }, log.values[0..log.len]);
    try testing.expectEqual(@as(usize, 1), counts.released);
    state.invokeBackup(&log, Log.invoke);
    try testing.expectEqualSlices(u32, &.{ 1, 3, 4 }, log.values[0..log.len]);
    try testing.expectEqual(counts.held, counts.released);
    try testing.expectEqual(@as(usize, 4), counts.dropped);
}

test "CE agent: a cancelled backup microtask can later run safely" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var counts = Counts{};
    var log = Log{ .state = &state, .counts = &counts };
    try testing.expect(try state.enqueue(&counts, 1, 10, .{ .value = 1, .counts = &counts }, acquire));
    state.clearRealm(10);
    try testing.expectEqual(@as(usize, 1), counts.dropped);
    try testing.expectEqual(counts.held, counts.released);
    state.invokeBackup(&log, Log.invoke);
    try testing.expectEqual(@as(usize, 0), log.len);
}

test "CE agent: rejected microtask scheduling drops work and permits rescheduling" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var counts = Counts{};
    var log = Log{ .state = &state, .counts = &counts };
    try testing.expect(try state.enqueue(&counts, 1, 10, .{ .value = 1, .counts = &counts }, acquire));
    state.cancelBackup();
    try testing.expectEqual(@as(usize, 1), counts.dropped);
    try testing.expectEqual(counts.held, counts.released);
    try testing.expect(try state.enqueue(&counts, 1, 10, .{ .value = 2, .counts = &counts }, acquire));
    state.invokeBackup(&log, Log.invoke);
    try testing.expectEqualSlices(u32, &.{2}, log.values[0..log.len]);
    try testing.expectEqual(counts.held, counts.released);
}

test "CE agent: deferring a scope keeps its roots until the backup invocation" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var counts = Counts{};
    var log = Log{ .state = &state, .counts = &counts };
    state.begin();
    _ = try state.enqueue(&counts, 1, 10, .{ .value = 1, .counts = &counts }, acquire);
    try testing.expect(try state.deferCurrent());
    try testing.expectEqual(@as(usize, 0), counts.released);
    state.invokeBackup(&log, Log.invoke);
    try testing.expectEqualSlices(u32, &.{1}, log.values[0..log.len]);
    try testing.expectEqual(counts.held, counts.released);
}

test "CE agent: realm cleanup preserves constructor scope slots until they pop" {
    var state = State.init(testing.allocator);
    defer state.deinit();
    var counts = Counts{};
    try state.pushConstructor(.{
        .constructor = try acquire(&counts, 1),
        .registry = 100,
        .registry_root = try acquire(&counts, 100),
        .realm = 10,
    });
    try state.pushConstructor(.{
        .constructor = try acquire(&counts, 2),
        .registry = 200,
        .registry_root = try acquire(&counts, 200),
        .realm = 20,
    });
    state.clearRealm(10);
    try testing.expectEqual(@as(usize, 2), state.active_constructors.len);
    try testing.expectEqual(@as(?u32, null), state.active_constructors.get(0).?.registry);
    try testing.expectEqual(@as(?u32, 200), state.active_constructors.get(1).?.registry);
    try testing.expectEqual(@as(usize, 2), counts.released);
    state.popConstructor();
    state.popConstructor();
    try testing.expectEqual(counts.held, counts.released);
}

test "CE agent: pending return holds are released when the agent ends before its microtask" {
    var counts = Counts{};
    var state = State.init(testing.allocator);
    _ = try state.returns.append(10, try acquire(&counts, 1));
    state.deinit();
    try testing.expectEqual(counts.held, counts.released);
}

test "CE agent: invocation skips a retired realm even when unloading missed its queue" {
    var counts = Counts{};
    var state = State.init(testing.allocator);
    defer state.deinit();
    var log = Log{ .state = &state, .counts = &counts };
    state.begin();
    _ = try state.enqueue(&counts, 1, 99, .{ .value = 1, .counts = &counts }, acquire);
    state.end(&log, Log.invoke);
    try testing.expectEqual(@as(usize, 0), log.len);
    try testing.expectEqual(@as(usize, 1), counts.dropped);
    try testing.expectEqual(counts.held, counts.released);
}

test "CE agent: pre-agent cleanup drops callbacks, return roots and constructor roots exactly once" {
    var counts = Counts{};
    var state = State.init(testing.allocator);
    _ = try state.enqueue(&counts, 1, 99, .{ .value = 1, .counts = &counts }, acquire);
    _ = try state.returns.append(10, try acquire(&counts, 2));
    try state.pushConstructor(.{
        .constructor = try acquire(&counts, 3),
        .registry = 4,
        .registry_root = try acquire(&counts, 4),
        .realm = 99,
    });
    state.releasePending();
    try testing.expectEqual(@as(usize, 1), counts.dropped);
    try testing.expectEqual(counts.held, counts.released);
    state.releasePending();
    state.deinit();
    try testing.expectEqual(@as(usize, 1), counts.dropped);
    try testing.expectEqual(counts.held, counts.released);
}

fn allocationFailures(allocator: std.mem.Allocator) !void {
    var counts = Counts{};
    var accepted: usize = 0;
    var state = State.init(allocator);
    defer {
        state.deinit();
        std.debug.assert(counts.held == counts.released);
        std.debug.assert(counts.dropped == accepted);
    }
    for (0..24) |i| {
        _ = try state.enqueue(&counts, @intCast(i % 8), @intCast(i % 2), .{ .value = @intCast(i), .counts = &counts }, acquire);
        accepted += 1;
    }
}

test "CE agent: failed enqueue releases acquired roots and leaves payload with caller" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailures, .{});
}
