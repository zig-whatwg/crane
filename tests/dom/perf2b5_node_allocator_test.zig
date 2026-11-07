//! A node is freed through the allocator that made it (lane perf2, batch 5).
//!
//! A node's state keeps no allocator copy any more: what its impl allocates
//! and frees goes through its Browser's allocator (runtime.allocatorOf, read
//! from the scope that issued its slot and block). That is the allocator it
//! was made with only because the creation allocator IS the scope's - Node's
//! initOwn asserts it. A test that fails allocations in a construction chain
//! therefore makes its Browser scope with the failing allocator too
//! (fx1_policy_document_test's FailingScope), and this test proves the
//! discipline end to end: under a leak-checking, poisoning DebugAllocator
//! wrapped in a FailingAllocator, everything a Browser scope, a Document and
//! its elements allocate is freed through that same wrapper - its allocated
//! and freed byte counts agree - and the DebugAllocator reports no leak.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn element(document: *runtime.Instance, local_name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElement(document, .initInterned(local_name), .notPassed());
}

fn underFailingAllocatorBrowser() !void {
    interfaces.process_hooks.startHooksForTest();
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer if (debug.deinit() != .ok) @panic("the DebugAllocator found a leak");
    var failing = testing.FailingAllocator.init(debug.allocator(), .{});
    const allocator = failing.allocator();

    {
        // The Browser scope and its realm, made with the failing allocator.
        const scope = try allocator.create(runtime.BrowserScope);
        scope.* = runtime.BrowserScope.init(allocator);
        const previous = runtime.BrowserScope.standalone();
        runtime.BrowserScope.setStandalone(scope);
        defer {
            runtime.BrowserScope.setStandalone(previous);
            scope.deinit();
            allocator.destroy(scope);
        }
        var context = try runtime.ContextData.init(allocator, .{});
        defer context.deinit();

        const origin = try dom.origin_record.OriginRecord.create(allocator, "https://node.test");
        defer origin.release();
        const document = try interfaces.Document.initWith(allocator, &context, .{ .origin = origin });
        defer interfaces.Document.deinit(document);
        try testing.expect(runtime.allocatorOf(document).ptr == allocator.ptr);

        // An element whose node name the NodeBase owns (rare data), and an
        // element with an attribute its state owns: allocations of the
        // node's own, freed by its teardown.
        const iframe = try element(document, "iframe");
        defer dom.node_creation.destroyUninserted(iframe);
        const div = try element(document, "div");
        defer dom.node_creation.destroyUninserted(div);
        try interfaces.Element.call_setAttribute(div, .initInterned("title"), .{ .domstring = .initInterned("a title") });
        try testing.expect(runtime.allocatorOf(div).ptr == allocator.ptr);
        try testing.expect(failing.allocated_bytes > 0);
    }

    // Everything the scope, the document and the elements allocated went back
    // through the allocator that allocated it.
    try testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "a node made under a failing-allocator Browser frees through that same allocator" {
    try onThread(underFailingAllocatorBrowser);
}
