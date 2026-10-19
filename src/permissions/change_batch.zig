//! Completion of Permissions B's per-settings tasks. This owns no realm,
//! platform object or script handle. A delivery's run OR drop returns one
//! task share; the automation command has its own independent share.
const std = @import("std");
const runtime = @import("runtime");

pub const ChangeBatch = struct {
    allocator: std.mem.Allocator,
    refs: std.atomic.Value(usize) = .init(1),
    remaining: std.atomic.Value(usize) = .init(0),

    pub fn create(allocator: std.mem.Allocator) std.mem.Allocator.Error!*ChangeBatch {
        const self = try allocator.create(ChangeBatch);
        self.* = .{ .allocator = allocator };
        return self;
    }

    /// Before handing a task to TaskSink.post, which owns it even on drop.
    pub fn startTask(self: *ChangeBatch) void {
        _ = self.refs.fetchAdd(1, .monotonic);
        _ = self.remaining.fetchAdd(1, .monotonic);
    }

    pub fn finishTask(self: *ChangeBatch) void {
        const before = self.remaining.fetchSub(1, .acq_rel);
        std.debug.assert(before != 0);
        self.release();
    }

    pub fn isDone(self: *const ChangeBatch) bool {
        return self.remaining.load(.acquire) == 0;
    }

    pub fn release(self: *ChangeBatch) void {
        const before = self.refs.fetchSub(1, .acq_rel);
        std.debug.assert(before != 0);
        if (before == 1) self.allocator.destroy(self);
    }
};

test "a permission command waits for every task and can abandon its share" {
    var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("batch leaked");
    const batch = try ChangeBatch.create(gpa.allocator());
    try std.testing.expect(batch.isDone());
    batch.startTask();
    batch.startTask();
    try std.testing.expect(!batch.isDone());
    batch.finishTask();
    try std.testing.expect(!batch.isDone());
    // The last queued task, not the command, now owns the batch's lifetime.
    batch.release();
    batch.finishTask();
}

const TestTask = struct {
    batch: *ChangeBatch,
    ran: *bool,

    fn run(data: ?*anyopaque) void {
        const self: *TestTask = @ptrCast(@alignCast(data.?));
        self.ran.* = true;
        self.batch.finishTask();
    }

    fn drop(data: ?*anyopaque) void {
        const self: *TestTask = @ptrCast(@alignCast(data.?));
        self.batch.finishTask();
    }

    fn task(self: *TestTask) runtime.CrossThreadTask {
        return .{ .run = run, .drop = drop, .data = self };
    }
};

test "a closed permission target completes its batch through drop" {
    var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("closed target leaked");
    const allocator = gpa.allocator();
    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    sink.close();
    const batch = try ChangeBatch.create(allocator);
    defer batch.release();
    var ran = false;
    var delivery: TestTask = .{ .batch = batch, .ran = &ran };
    batch.startTask();
    try std.testing.expect(!sink.post(delivery.task()));
    try std.testing.expect(batch.isDone());
    try std.testing.expect(!ran);
}

test "same-thread permission deliveries complete only after their task runs" {
    var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("same-thread target leaked");
    const allocator = gpa.allocator();
    const sink = try runtime.TaskSink.create(allocator);
    defer sink.release();
    const batch = try ChangeBatch.create(allocator);
    defer batch.release();
    var ran = false;
    var delivery: TestTask = .{ .batch = batch, .ran = &ran };
    batch.startTask();
    try std.testing.expect(sink.post(delivery.task()));
    try std.testing.expect(!batch.isDone());
    var tasks: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
    defer tasks.deinit(allocator);
    try sink.takeAll(&tasks, allocator);
    for (tasks.items) |task| task.run(task.data);
    try std.testing.expect(batch.isDone());
    try std.testing.expect(ran);
}

test "a worker task can finish after its permission command was abandoned" {
    var sender_gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(sender_gpa.deinit() == .ok) catch @panic("batch leaked");
    var target_gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(target_gpa.deinit() == .ok) catch @panic("sink leaked");
    const sink = try runtime.TaskSink.create(target_gpa.allocator());
    defer sink.release();
    const batch = try ChangeBatch.create(sender_gpa.allocator());
    var ran = false;
    var delivery: TestTask = .{ .batch = batch, .ran = &ran };
    batch.startTask();
    try std.testing.expect(sink.post(delivery.task()));
    batch.release();
    const Worker = struct {
        fn run(target: *runtime.TaskSink) void {
            var tasks: std.ArrayListUnmanaged(runtime.CrossThreadTask) = .empty;
            defer tasks.deinit(target.allocator);
            target.takeAll(&tasks, target.allocator) catch @panic("test task allocation failed");
            for (tasks.items) |task| task.run(task.data);
        }
    };
    const thread = try std.Thread.spawn(.{}, Worker.run, .{sink});
    thread.join();
    try std.testing.expect(ran);
}
