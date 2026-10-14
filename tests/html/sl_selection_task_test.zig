//! A selectionchange task may be dropped synchronously by a closing queue.
//! Exercise the public control setters with the testing allocator; no task
//! payload or pointer into textarea's movable state map survives the handoff.
const std = @import("std");
const runtime = @import("runtime");
const browser_mod = @import("browser");

const DropQueue = struct {
    allocator: std.mem.Allocator,
    tasks: usize = 0,
    drops: usize = 0,

    fn enqueue(context: *anyopaque, task: runtime.EventLoopTask) void {
        const self: *DropQueue = @ptrCast(@alignCast(context));
        self.tasks += 1;
        if (task.drop) |drop| {
            self.drops += 1;
            drop(task.context);
        }
    }
    fn microtask(_: *anyopaque, _: runtime.EventLoopMicrotask) void {}
    fn flush(_: *anyopaque) void {}
    fn once(_: *anyopaque) bool {
        return false;
    }
    fn getAllocator(context: *anyopaque) std.mem.Allocator {
        const self: *DropQueue = @ptrCast(@alignCast(context));
        return self.allocator;
    }
    const vtable: runtime.EventLoop.VTable = .{
        .queueTask = enqueue,
        .queueMicrotask = microtask,
        .runMicrotasks = flush,
        .runOnce = once,
        .promiseAllocator = getAllocator,
    };
};

fn exercise(comptime tag: []const u8) !void {
    const allocator = std.testing.allocator;
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body><" ++ tag ++ " id=control></" ++ tag ++ "></body>", .{ .base_url = "http://example.test/selection" });
    try page.runScript("globalThis.control = document.getElementById('control'); control.value = 'abcdef';");
    _ = try browser.runEventLoopBlocking(20);
    const document = page.document_instance orelse return error.TestUnexpectedResult;
    var queue: DropQueue = .{ .allocator = allocator };
    const previous = document.ctx.event_loop;
    document.ctx.event_loop = .{ .ptr = &queue, .vtable = &DropQueue.vtable };
    defer document.ctx.event_loop = previous;

    // Each change has one selectionchange task and one select task. The
    // first immediate drop must clear the flag so the second can queue too.
    try page.runScript("control.setSelectionRange(1, 2); control.setSelectionRange(2, 3);");
    try std.testing.expectEqual(@as(usize, 4), queue.tasks);
    try std.testing.expectEqual(queue.tasks, queue.drops);
    // Repeating the unchanged selection schedules neither event.
    try page.runScript("control.setSelectionRange(2, 3);");
    try std.testing.expectEqual(@as(usize, 4), queue.tasks);
}

fn onFreshThread(comptime tag: []const u8) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(tag) catch |err| {
                result.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "input selectionchange synchronous drop releases task and permits another change" {
    try onFreshThread("input");
}

test "textarea selectionchange synchronous drop releases task and permits another change" {
    try onFreshThread("textarea");
}
