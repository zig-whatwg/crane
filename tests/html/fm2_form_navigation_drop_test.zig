//! A closing queue must destroy planned GET/POST navigation payloads.
//! No impl or private task seam: submit through the public form interface.
const std = @import("std");
const runtime = @import("runtime");
const browser_mod = @import("browser");

const DropQueue = struct {
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
    fn getAllocator(_: *anyopaque) std.mem.Allocator {
        return std.testing.allocator;
    }
    const vtable: runtime.EventLoop.VTable = .{
        .queueTask = enqueue,
        .queueMicrotask = microtask,
        .runMicrotasks = flush,
        .runOnce = once,
        .promiseAllocator = getAllocator,
    };
};

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><form id=f action='/destination' target='_blank' rel=noreferrer><input name=field value=value></form>", .{ .base_url = "http://example.test/form" });
    _ = try browser.runEventLoopBlocking(20);
    const document = page.document_instance orelse return error.NoDocument;
    var queue: DropQueue = .{};
    const previous = document.ctx.event_loop;
    document.ctx.event_loop = .{ .ptr = &queue, .vtable = &DropQueue.vtable };
    defer document.ctx.event_loop = previous;
    try page.runScript("const form = document.getElementById('f'); form.submit(); form.method = 'post'; form.submit(); form.enctype = 'multipart/form-data'; form.submit();");
    try std.testing.expectEqual(@as(usize, 3), queue.tasks);
    try std.testing.expectEqual(queue.tasks, queue.drops);
    // Browser teardown plus std.testing.allocator checks URL/target, POST
    // bytes and the entry-list FormData pin, even for synchronous drops.
}

test "a closing queue drops all resources owned by planned form navigations" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
