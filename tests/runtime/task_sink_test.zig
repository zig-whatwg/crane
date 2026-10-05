//! runtime.TaskSink: a loop's inbox for tasks posted from other threads.
//!
//! The contract the worker threads rest on (workers design 3.1): a posted
//! task either runs on the sink's thread exactly once or is dropped exactly
//! once - never both, never neither - whether it was posted before the loop
//! took its inbox, while the loop ran, or after the sink closed; and the
//! sink's memory goes with its last reference.

const std = @import("std");
const runtime = @import("runtime");
const TaskSink = runtime.TaskSink;
const CrossThreadTask = runtime.CrossThreadTask;
const testing = std.testing;

const Counter = struct {
    ran: u32 = 0,
    dropped: u32 = 0,

    fn run(data: ?*anyopaque) void {
        const self: *Counter = @ptrCast(@alignCast(data.?));
        self.ran += 1;
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Counter = @ptrCast(@alignCast(data.?));
        self.dropped += 1;
    }

    fn task(self: *Counter) CrossThreadTask {
        return .{ .run = run, .drop = drop, .data = self };
    }
};

test "a posted task is taken in order and runs once; nothing is dropped" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    var a: Counter = .{};
    var b: Counter = .{};
    try testing.expect(sink.post(a.task()));
    try testing.expect(sink.post(b.task()));
    try testing.expect(sink.hasPosted());

    var taken: std.ArrayListUnmanaged(CrossThreadTask) = .empty;
    defer taken.deinit(testing.allocator);
    try sink.takeAll(&taken, testing.allocator);
    try testing.expect(!sink.hasPosted());
    try testing.expectEqual(@as(usize, 2), taken.items.len);
    try testing.expectEqual(@as(?*anyopaque, &a), taken.items[0].data);
    for (taken.items) |task| task.run(task.data);
    try testing.expectEqual(@as(u32, 1), a.ran);
    try testing.expectEqual(@as(u32, 1), b.ran);
    try testing.expectEqual(@as(u32, 0), a.dropped + b.dropped);
}

test "close drops each queued task once, and a post after close drops its own task" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    var queued: Counter = .{};
    var late: Counter = .{};
    try testing.expect(sink.post(queued.task()));
    sink.close();
    try testing.expectEqual(@as(u32, 1), queued.dropped);
    try testing.expectEqual(@as(u32, 0), queued.ran);
    // Closed: the post fails, and the task is dropped by the post, once.
    try testing.expect(!sink.post(late.task()));
    try testing.expectEqual(@as(u32, 1), late.dropped);
    // A second close drops nothing again.
    sink.close();
    try testing.expectEqual(@as(u32, 1), queued.dropped);
}

test "the last reference closes the sink and drops what it still holds" {
    const sink = try TaskSink.create(testing.allocator);
    var held: Counter = .{};
    const holder = sink.retain();
    try testing.expect(holder.post(held.task()));
    sink.release();
    try testing.expectEqual(@as(u32, 0), held.dropped);
    holder.release();
    try testing.expectEqual(@as(u32, 1), held.dropped);
}

test "a post that cannot grow the inbox drops its task" {
    // The sink itself is allocation 0; the inbox's first growth fails.
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 1 });
    const sink = try TaskSink.create(failing.allocator());
    defer sink.release();
    var task: Counter = .{};
    try testing.expect(!sink.post(task.task()));
    try testing.expectEqual(@as(u32, 1), task.dropped);
    try testing.expectEqual(@as(u32, 0), task.ran);
    try testing.expect(!sink.hasPosted());
}

test "waitForWork returns at once with a task posted, and after its timeout without" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    // Nothing posted: the timeout ends the wait.
    sink.waitForWork(1 * std.time.ns_per_ms);
    var a: Counter = .{};
    try testing.expect(sink.post(a.task()));
    // A task waits: no wait at all (an unbounded one would hang the test).
    sink.waitForWork(null);
    var taken: std.ArrayListUnmanaged(CrossThreadTask) = .empty;
    defer taken.deinit(testing.allocator);
    try sink.takeAll(&taken, testing.allocator);
    try testing.expectEqual(@as(usize, 1), taken.items.len);
}

test "sources count the posters a loop waits for" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    try testing.expectEqual(@as(u32, 0), sink.sourceCount());
    sink.addSource();
    sink.addSource();
    sink.removeSource();
    try testing.expectEqual(@as(u32, 1), sink.sourceCount());
    sink.removeSource();
    try testing.expectEqual(@as(u32, 0), sink.sourceCount());
}

// ----------------------------------------------------------------------------
// Two threads
// ----------------------------------------------------------------------------

/// One posted item: whichever happens to it, it happens once.
const Item = struct {
    ran: std.atomic.Value(u32) = .init(0),
    dropped: std.atomic.Value(u32) = .init(0),

    fn run(data: ?*anyopaque) void {
        const self: *Item = @ptrCast(@alignCast(data.?));
        _ = self.ran.fetchAdd(1, .monotonic);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Item = @ptrCast(@alignCast(data.?));
        _ = self.dropped.fetchAdd(1, .monotonic);
    }
};

const per_poster = 20_000;

const Poster = struct {
    sink: *TaskSink,
    items: []Item,

    fn run(self: *Poster) void {
        defer self.sink.release();
        for (self.items) |*item| {
            _ = self.sink.post(.{ .run = Item.run, .drop = Item.drop, .data = item });
        }
    }
};

/// The loop: take, run, wait - until told to stop, then close.
const Loop = struct {
    sink: *TaskSink,
    stop: std.atomic.Value(bool) = .init(false),
    ran: usize = 0,

    fn run(self: *Loop) void {
        var taken: std.ArrayListUnmanaged(CrossThreadTask) = .empty;
        defer taken.deinit(std.heap.page_allocator);
        while (!self.stop.load(.acquire)) {
            self.sink.takeAll(&taken, std.heap.page_allocator) catch {};
            for (taken.items) |task| task.run(task.data);
            self.ran += taken.items.len;
            taken.clearRetainingCapacity();
            self.sink.waitForWork(1 * std.time.ns_per_ms);
        }
        // The loop's end: what was posted and not taken is dropped.
        self.sink.close();
    }
};

test "two posters and a loop on three threads: every task runs once or is dropped once" {
    const allocator = std.heap.page_allocator;
    const sink = try TaskSink.create(allocator);
    defer sink.release();

    const items_a = try allocator.alloc(Item, per_poster);
    defer allocator.free(items_a);
    const items_b = try allocator.alloc(Item, per_poster);
    defer allocator.free(items_b);
    for (items_a) |*item| item.* = .{};
    for (items_b) |*item| item.* = .{};

    var loop: Loop = .{ .sink = sink };
    const loop_thread = try std.Thread.spawn(.{}, Loop.run, .{&loop});
    var poster_a: Poster = .{ .sink = sink.retain(), .items = items_a };
    var poster_b: Poster = .{ .sink = sink.retain(), .items = items_b };
    const thread_a = try std.Thread.spawn(.{}, Poster.run, .{&poster_a});
    const thread_b = try std.Thread.spawn(.{}, Poster.run, .{&poster_b});
    thread_a.join();
    // The loop ends while the second poster may still be posting: some of
    // its tasks run, the rest are dropped - by close, or by the post that
    // found the sink closed.
    loop.stop.store(true, .release);
    loop_thread.join();
    thread_b.join();

    var ran: usize = 0;
    for ([_][]Item{ items_a, items_b }) |items| {
        for (items) |*item| {
            const r = item.ran.load(.monotonic);
            const d = item.dropped.load(.monotonic);
            try testing.expectEqual(@as(u32, 1), r + d);
            ran += r;
        }
    }
    try testing.expectEqual(loop.ran, ran);
}

/// A loop that waits with no timeout: a post from another thread must wake it.
const Sleeper = struct {
    sink: *TaskSink,
    woke: std.atomic.Value(bool) = .init(false),

    fn run(self: *Sleeper) void {
        while (!self.sink.hasPosted()) self.sink.waitForWork(null);
        self.woke.store(true, .release);
    }
};

test "a post wakes a loop waiting with no timeout" {
    const sink = try TaskSink.create(testing.allocator);
    defer sink.release();
    var sleeper: Sleeper = .{ .sink = sink };
    const thread = try std.Thread.spawn(.{}, Sleeper.run, .{&sleeper});
    var item: Counter = .{};
    // Give the sleeper time to block, so the post is what wakes it.
    std.Thread.yield() catch {};
    try testing.expect(sink.post(item.task()));
    thread.join();
    try testing.expect(sleeper.woke.load(.acquire));
    sink.close();
    try testing.expectEqual(@as(u32, 1), item.dropped);
}
