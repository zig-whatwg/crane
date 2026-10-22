//! PortMessage queue/drop ownership; linked with V8 for engine-owned payloads.
const std = @import("std");
const runtime = @import("runtime");
const channels = @import("dom").port_channels;
const TaskSink = runtime.TaskSink;
const Channel = channels.Channel;
const End = channels.End;
const PortMessage = channels.PortMessage;
const Delivery = channels.Delivery;
const ReceiverHooks = channels.ReceiverHooks;
const Owner = channels.Owner;

const testing = std.testing;

/// A receiver that records what reached it.
const Recorder = struct {
    delivered: std.ArrayListUnmanaged(u8) = .empty,
    closes: u32 = 0,
    /// Take nothing while false (a document not fully active).
    ready: bool = true,

    const hooks: ReceiverHooks = .{ .deliver = deliver, .closed = closed };

    fn deliver(receiver: *anyopaque, _: u64, delivery: *Delivery) void {
        const self: *Recorder = @ptrCast(@alignCast(receiver));
        if (!self.ready) return;
        const message = delivery.next() orelse return;
        defer message.destroy();
        self.delivered.append(testing.allocator, message.serialized[0]) catch {};
    }

    fn closed(receiver: *anyopaque, _: u64) void {
        const self: *Recorder = @ptrCast(@alignCast(receiver));
        self.closes += 1;
    }

    fn owner(self: *Recorder, sink: *TaskSink) Owner {
        return .{ .sink = sink, .receiver = self, .generation = 0, .hooks = &hooks };
    }
};

fn testMessage(byte: u8) !*PortMessage {
    var result: runtime.SerializedWithTransfer = .{
        .serialized = try testing.allocator.dupe(u8, &.{byte}),
        .array_buffers = &.{},
        .platform_objects = &.{},
    };
    return PortMessage.create(testing.allocator, &result, &.{});
}

/// Run what `sink` holds, as its loop would, until nothing is posted.
fn drain(sink: *TaskSink) !void {
    var taken: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer taken.deinit(testing.allocator);
    while (sink.hasPosted()) {
        try sink.takeAll(&taken, testing.allocator);
        for (taken.items) |task| task.run(task.data);
        taken.clearRetainingCapacity();
    }
}

test "messages wait for an enabled queue and arrive one per task, in order" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    const channel = try Channel.create(testing.allocator);
    var a: Recorder = .{};
    var b: Recorder = .{};
    defer a.delivered.deinit(testing.allocator);
    defer b.delivered.deinit(testing.allocator);
    channel.end(0).bind(a.owner(sink));
    channel.end(1).bind(b.owner(sink));

    channel.end(0).post(try testMessage('x'));
    channel.end(0).post(try testMessage('y'));
    // Disabled: nothing is posted to the loop.
    try testing.expect(!sink.hasPosted());
    channel.end(1).enable();
    try testing.expect(sink.hasPosted());
    // One task delivers one message, and posts the next.
    var taken: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer taken.deinit(testing.allocator);
    try sink.takeAll(&taken, testing.allocator);
    try testing.expectEqual(@as(usize, 1), taken.items.len);
    taken.items[0].run(taken.items[0].data);
    try testing.expectEqualStrings("x", b.delivered.items);
    try drain(sink);
    try testing.expectEqualStrings("xy", b.delivered.items);

    channel.end(0).discard();
    try drain(sink);
    // The peer's owner heard `close`.
    try testing.expectEqual(@as(u32, 1), b.closes);
    channel.end(1).discard();
}

test "a shipped end's queue goes with it, and its old owner hears nothing" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    const channel = try Channel.create(testing.allocator);
    var old: Recorder = .{};
    var new: Recorder = .{};
    defer old.delivered.deinit(testing.allocator);
    defer new.delivered.deinit(testing.allocator);
    channel.end(1).bind(old.owner(sink));
    channel.end(1).enable();
    channel.end(0).post(try testMessage('m'));
    // Shipped before the notification ran: it finds a new epoch.
    channel.end(1).unbind();
    try drain(sink);
    try testing.expectEqual(@as(usize, 0), old.delivered.items.len);
    // Received: disabled until the new owner enables it.
    channel.end(1).bind(new.owner(sink));
    try drain(sink);
    try testing.expectEqual(@as(usize, 0), new.delivered.items.len);
    channel.end(1).enable();
    try drain(sink);
    try testing.expectEqualStrings("m", new.delivered.items);
    channel.end(0).discard();
    channel.end(1).discard();
}

test "a receiver that takes nothing keeps its message, and a later post delivers both" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    const channel = try Channel.create(testing.allocator);
    var r: Recorder = .{ .ready = false };
    defer r.delivered.deinit(testing.allocator);
    channel.end(1).bind(r.owner(sink));
    channel.end(1).enable();
    channel.end(0).post(try testMessage('a'));
    try drain(sink);
    try testing.expectEqual(@as(usize, 1), channel.end(1).state().queued);
    r.ready = true;
    channel.end(0).post(try testMessage('b'));
    try drain(sink);
    try testing.expectEqualStrings("ab", r.delivered.items);
    // Discarding frees what is still queued (nothing here) and the channel.
    channel.end(1).discard();
    channel.end(0).discard();
}

test "a message carrying an end discards it with itself; a closed sink drops its tasks" {
    const sink = try TaskSink.create(testing.allocator);
    const channel = try Channel.create(testing.allocator);
    const carried = try Channel.create(testing.allocator);
    var r: Recorder = .{};
    defer r.delivered.deinit(testing.allocator);
    channel.end(1).bind(r.owner(sink));
    channel.end(1).enable();

    // One of `carried`'s ends travels in a message; the other is held.
    var result: runtime.SerializedWithTransfer = .{
        .serialized = try testing.allocator.dupe(u8, "p"),
        .array_buffers = &.{},
        .platform_objects = &.{},
    };
    const ends = try testing.allocator.alloc(*End, 1);
    ends[0] = carried.end(0);
    channel.end(0).post(try PortMessage.create(testing.allocator, &result, ends));
    // The loop ends before the notification runs: the sink drops it.
    sink.close();
    sink.release();
    // The queued message - and the end in it - go with the channel's ends.
    channel.end(1).discard();
    channel.end(0).discard();
    carried.end(1).discard();
}
