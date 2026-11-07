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
    // Freed uninserted only if it stayed out of the tree; linked, it is the
    // select's tree's to free.
    defer if ((interfaces.Node.get_parentNode(option) catch null) == null) dom.node_creation.destroyUninserted(option);
    for (0..4) |_| {
        const child = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("div"), .notPassed());
        _ = try interfaces.Node.call_appendChild(select, child);
    }
    // DOM "insert" has no step that can fail, and since lane perf2 batch 5 a
    // node's children are its sibling links: appending a fifth child no
    // longer grows a child list (this test once relied on infra.List's four
    // inline slots overflowing to force an OutOfMemory). With the allocator
    // exhausted, the option is linked, and the insertion steps' allocations
    // fall back where they can (the descendants walk): the insertion
    // succeeds. A failure from preInsert would still route through
    // options.mutationError.
    failing.fail_index = failing.alloc_index;
    defer failing.fail_index = std.math.maxInt(usize);
    try options.add(select, option, .notPassed());
    try testing.expectEqual(select, (try interfaces.Node.get_parentNode(option)).?);
    try testing.expectEqual(@as(u32, 1), try interfaces.HTMLSelectElement.get_length(select));
}

test "an option insertion with an exhausted allocator succeeds: linking a child cannot fail" {
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
