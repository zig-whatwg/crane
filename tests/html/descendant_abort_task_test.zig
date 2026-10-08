const std = @import("std");
const runtime = @import("runtime");

test "descendant abort task captures its global task document and generation" {
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    // A real allocator-issued slot, without replacing the process's slab.
    var slab: runtime.SlabAllocator = .{
        .slabs = null,
        .free_list = null,
        .backing_allocator = arena.allocator(),
        .total_slabs = 0,
        .total_allocated = 0,
        .total_freed = 0,
        .next_generation = 1,
    };
    const VTable = struct {
        const delegates = .{};
        const value: runtime.VTable = .{ .name = "Document", .deinit = null, .methods_ptr = &delegates };
    };
    const Queue = struct {
        task: ?runtime.EventLoopTask = null,
        allocator: std.mem.Allocator,
        fn enqueue(context: *anyopaque, task: runtime.EventLoopTask) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.task = task;
        }
        fn microtask(_: *anyopaque, _: runtime.EventLoopMicrotask) void {}
        fn flush(_: *anyopaque) void {}
        fn once(_: *anyopaque) bool {
            return false;
        }
        fn getAllocator(context: *anyopaque) std.mem.Allocator {
            const self: *@This() = @ptrCast(@alignCast(context));
            return self.allocator;
        }
        const vtable: runtime.EventLoop.VTable = .{ .queueTask = enqueue, .queueMicrotask = microtask, .runMicrotasks = flush, .runOnce = once, .promiseAllocator = getAllocator };
    };
    var queue: Queue = .{ .allocator = allocator };
    var context = try runtime.ContextData.init(allocator, .{ .event_loop = .{ .ptr = &queue, .vtable = &Queue.vtable } });
    defer context.deinit();
    const parent = try slab.alloc(&VTable.value);
    defer slab.free(parent);
    parent.ctx = &context;
    const child = try slab.alloc(&VTable.value);
    defer slab.free(child);
    child.ctx = &context;
    const child_generation = runtime.SlabAllocator.generationOf(child);
    @import("html").document_abort.DescendantAbort.queue(parent, child, 0);
    const task = queue.task orelse return error.TestUnexpectedResult;
    defer if (task.drop) |drop| drop(task.context);
    try std.testing.expect(task.drop != null);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(child)), task.document);
    try std.testing.expectEqual(child_generation, task.document_generation);
}
