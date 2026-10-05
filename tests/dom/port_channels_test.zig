//! dom.port_channels across threads: a channel whose two ends are owned on
//! two threads, each with a loop of its own, as a page and a worker will be
//! (docs/instances.md, "Decisions").
//!
//! The contract: every message posted to an entangled end reaches the other
//! end's owner exactly once, in the order it was posted, on the owner's
//! thread; an end shipped across while messages are in flight keeps them;
//! a `close` reaches the other side; nothing is lost or delivered twice, and
//! everything is freed when both ends are discarded.

const std = @import("std");
const runtime = @import("runtime");
const port_channels = @import("dom").port_channels;
const Channel = port_channels.Channel;
const End = port_channels.End;
const PortMessage = port_channels.PortMessage;
const TaskSink = runtime.TaskSink;
const testing = std.testing;

const count = 5_000;

/// A thread with a loop: it runs what its sink receives until told to stop.
const Side = struct {
    sink: *TaskSink,
    /// Numbers received, in arrival order.
    got: std.ArrayListUnmanaged(u32) = .empty,
    closes: u32 = 0,
    /// The thread that ran the hooks: must be this side's own.
    thread_id: std.Thread.Id = 0,
    wrong_thread: bool = false,
    stop: std.atomic.Value(bool) = .init(false),
    /// What this side posts once its loop is running.
    outgoing: ?*End = null,

    const hooks: port_channels.ReceiverHooks = .{ .deliver = deliver, .closed = closed };

    fn deliver(receiver: *anyopaque, _: u64, delivery: *port_channels.Delivery) void {
        const self: *Side = @ptrCast(@alignCast(receiver));
        if (std.Thread.getCurrentId() != self.thread_id) self.wrong_thread = true;
        const message = delivery.next() orelse return;
        defer message.destroy();
        const n = std.mem.readInt(u32, message.serialized[0..4], .little);
        self.got.append(std.heap.page_allocator, n) catch {};
    }

    fn closed(receiver: *anyopaque, _: u64) void {
        const self: *Side = @ptrCast(@alignCast(receiver));
        if (std.Thread.getCurrentId() != self.thread_id) self.wrong_thread = true;
        self.closes += 1;
    }

    fn owner(self: *Side) port_channels.Owner {
        return .{ .sink = self.sink, .receiver = self, .generation = 0, .hooks = &hooks };
    }

    fn run(self: *Side) void {
        self.thread_id = std.Thread.getCurrentId();
        if (self.outgoing) |end| {
            var i: u32 = 0;
            while (i < count) : (i += 1) end.post(numbered(i) catch continue);
        }
        var taken: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
        defer taken.deinit(std.heap.page_allocator);
        while (true) {
            self.sink.takeAll(&taken, std.heap.page_allocator) catch {};
            for (taken.items) |task| task.run(task.data);
            taken.clearRetainingCapacity();
            if (self.stop.load(.acquire) and !self.sink.hasPosted()) break;
            self.sink.waitForWork(1 * std.time.ns_per_ms);
        }
    }
};

/// A message carrying `n`.
fn numbered(n: u32) !*PortMessage {
    const bytes = try std.heap.page_allocator.alloc(u8, 4);
    std.mem.writeInt(u32, bytes[0..4], n, .little);
    var result: runtime.SerializedWithTransfer = .{ .serialized = bytes, .array_buffers = &.{}, .platform_objects = &.{} };
    return PortMessage.create(std.heap.page_allocator, &result, &.{});
}

fn waitUntil(side: *Side, n: usize) void {
    var spins: usize = 0;
    // The other thread appends; reading the length is a race only in the
    // sense that it may lag, and the loop asks again.
    while (@atomicLoad(usize, &side.got.items.len, .acquire) < n and spins < 20_000) : (spins += 1) {
        @import("clock").sleep(1 * std.time.ns_per_ms);
    }
}

test "both directions across two threads: every message once, in order, on the owner's thread" {
    const allocator = std.heap.page_allocator;
    const channel = try Channel.create(allocator);
    var a: Side = .{ .sink = try TaskSink.create(allocator) };
    var b: Side = .{ .sink = try TaskSink.create(allocator) };
    channel.end(0).bind(a.owner());
    channel.end(1).bind(b.owner());
    channel.end(0).enable();
    channel.end(1).enable();
    a.outgoing = channel.end(0);
    b.outgoing = channel.end(1);

    const ta = try std.Thread.spawn(.{}, Side.run, .{&a});
    const tb = try std.Thread.spawn(.{}, Side.run, .{&b});
    waitUntil(&a, count);
    waitUntil(&b, count);
    // A closes its end: B hears it, on B's thread.
    channel.end(0).disentangle();
    a.stop.store(true, .release);
    ta.join();
    var spins: usize = 0;
    while (@atomicLoad(u32, &b.closes, .acquire) == 0 and spins < 5_000) : (spins += 1) @import("clock").sleep(1 * std.time.ns_per_ms);
    b.stop.store(true, .release);
    tb.join();

    try testing.expect(!a.wrong_thread and !b.wrong_thread);
    for ([_]*Side{ &a, &b }) |side| {
        try testing.expectEqual(@as(usize, count), side.got.items.len);
        for (side.got.items, 0..) |n, i| try testing.expectEqual(@as(u32, @intCast(i)), n);
        side.got.deinit(allocator);
    }
    try testing.expectEqual(@as(u32, 1), b.closes);
    try testing.expectEqual(@as(u32, 0), a.closes);

    channel.end(0).discard();
    channel.end(1).discard();
    a.sink.close();
    b.sink.close();
    a.sink.release();
    b.sink.release();
}

test "an end shipped to another thread's owner keeps the messages queued for it" {
    const allocator = std.heap.page_allocator;
    const channel = try Channel.create(allocator);
    var sender: Side = .{ .sink = try TaskSink.create(allocator) };
    var first: Side = .{ .sink = try TaskSink.create(allocator) };
    var second: Side = .{ .sink = try TaskSink.create(allocator) };
    channel.end(1).bind(first.owner());
    // Posted while end 1 is first's and disabled: they wait in its queue.
    var i: u32 = 0;
    while (i < 100) : (i += 1) channel.end(0).post(try numbered(i));
    // Shipped: first lets go, and second receives it on its own thread.
    channel.end(1).unbind();
    channel.end(1).bind(second.owner());
    channel.end(1).enable();

    const ts = try std.Thread.spawn(.{}, Side.run, .{&second});
    const tf = try std.Thread.spawn(.{}, Side.run, .{&first});
    waitUntil(&second, 100);
    second.stop.store(true, .release);
    first.stop.store(true, .release);
    ts.join();
    tf.join();

    try testing.expect(!second.wrong_thread);
    try testing.expectEqual(@as(usize, 100), second.got.items.len);
    for (second.got.items, 0..) |n, k| try testing.expectEqual(@as(u32, @intCast(k)), n);
    try testing.expectEqual(@as(usize, 0), first.got.items.len);
    second.got.deinit(allocator);

    channel.end(0).discard();
    channel.end(1).discard();
    for ([_]*Side{ &sender, &first, &second }) |side| {
        side.sink.close();
        side.sink.release();
    }
}
