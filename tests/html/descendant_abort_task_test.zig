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

fn exerciseDescendantAbort() !void {
    const browser_mod = @import("browser");
    const dom = @import("dom");
    const interfaces = @import("interfaces");
    const BrowsingContext = @import("html_core").BrowsingContext;
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.TestUnexpectedResult;
    try page.loadHTML("<!doctype html><body><iframe id='child'></iframe></body>", .{ .base_url = "http://example.test/start" });
    _ = try browser.runEventLoopBlocking(20);
    const parent = page.document_instance orelse return error.TestUnexpectedResult;
    const frame = (try interfaces.Document.call_getElementById(parent, runtime.DOMString.initInterned("child"))) orelse return error.TestUnexpectedResult;
    const child = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.TestUnexpectedResult;
    const window = (try interfaces.Document.get_defaultView(child)) orelse return error.TestUnexpectedResult;
    const navigable = BrowsingContext.ofWindow(@ptrCast(window)) orelse return error.TestUnexpectedResult;
    try page.runScript(
        \\const childDocument = document.getElementById('child').contentDocument;
        \\childDocument.open();
        \\childDocument.write('<!doctype html><body><p>unfinished');
    );
    const parent_state = dom.document_internals.getInternal(parent) orelse return error.TestUnexpectedResult;
    const child_state = dom.document_internals.getInternal(child) orelse return error.TestUnexpectedResult;
    try std.testing.expect(parent_state.salvageable);
    try std.testing.expect(child_state.salvageable);
    try std.testing.expect(child_state.active_parser != null);
    @import("html").document_abort.DescendantAbort.queue(parent, child, navigable.id);
    // Queueing neither aborts the parser nor propagates unsalvageability.
    try std.testing.expect(!child_state.active_parser_was_aborted);
    try std.testing.expect(parent_state.salvageable);
    _ = try browser.runEventLoopBlocking(20);
    try std.testing.expect(child_state.active_parser_was_aborted);
    try std.testing.expect(child_state.active_parser == null);
    try std.testing.expect(!child_state.salvageable);
    try std.testing.expect(!parent_state.salvageable);
}

test "descendant abort task aborts its active parser and propagates unsalvageability" {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exerciseDescendantAbort() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
