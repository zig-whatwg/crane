//! Reject impossible sparse growth before allocating dummy options.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const options = @import("html").forms.options;
const testing = std.testing;

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var failing = std.testing.FailingAllocator.init(testing.allocator, .{});
    var context = try runtime.ContextData.init(failing.allocator(), .{});
    defer context.deinit();
    const document = try interfaces.Document.init(failing.allocator(), &context);
    defer interfaces.Document.deinit(document);
    const select = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("select"), .notPassed());
    defer dom.node_creation.destroyUninserted(select);
    const option = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("option"), .notPassed());
    defer dom.node_creation.destroyUninserted(option);
    failing.fail_index = failing.alloc_index;
    defer failing.fail_index = std.math.maxInt(usize);
    for ([_]u32{ 100_000, 4_000_000_000, std.math.maxInt(u32) }) |index| {
        try options.setIndex(select, index, option);
        try testing.expect(!failing.has_induced_failure);
        try testing.expectEqual(@as(u32, 0), try interfaces.HTMLSelectElement.get_length(select));
    }
}

test "oversized indexed option writes are no-ops even with an exhausted allocator" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

fn mutationAllocationFailure() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var failing = std.testing.FailingAllocator.init(testing.allocator, .{});
    var context = try runtime.ContextData.init(failing.allocator(), .{});
    defer context.deinit();
    const document = try interfaces.Document.init(failing.allocator(), &context);
    defer interfaces.Document.deinit(document);
    const select = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("select"), .notPassed());
    defer dom.node_creation.destroyUninserted(select);
    const option = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("option"), .notPassed());
    defer dom.node_creation.destroyUninserted(option);
    // Four children fill infra.List's inline storage. The next insertion
    // must allocate and route its failure through options.mutationError.
    for (0..4) |_| {
        const child = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("div"), .notPassed());
        _ = try interfaces.Node.call_appendChild(select, child);
    }
    failing.fail_index = failing.alloc_index;
    defer failing.fail_index = std.math.maxInt(usize);
    try testing.expectError(error.OutOfMemory, options.add(select, option, .notPassed()));
    try testing.expect(failing.has_induced_failure);
}

test "option mutation propagates allocation failure" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            mutationAllocationFailure() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
