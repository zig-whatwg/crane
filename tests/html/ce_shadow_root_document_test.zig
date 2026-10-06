//! DOM attach-a-shadow-root step 5 uses the host's node document.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn exercise(comptime closed: bool) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const first_document = try interfaces.Document.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(first_document);
    const second_document = try interfaces.Document.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(second_document);

    for ([_]*runtime.Instance{ first_document, second_document }) |document| {
        const host = try interfaces.Element.init(testing.allocator, &context);
        defer dom.node_creation.destroyUninserted(host);
        try dom.node_creation.setElementNames(host, "http://www.w3.org/1999/xhtml", "div");
        try dom.node_document.set(host, document);
        const root = try interfaces.Element.call_attachShadow(host, .{ .mode = if (closed) ._closed_ else ._open_ });
        // The native fixture has no collector to release a parentless root.
        defer interfaces.ShadowRoot.deinit(root);
        try testing.expectEqual(@as(?*runtime.Instance, document), try interfaces.Node.get_ownerDocument(root));
        try testing.expectEqual(try interfaces.Node.get_ownerDocument(host), try interfaces.Node.get_ownerDocument(root));
    }
}

fn onFreshThread(comptime closed: bool) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(closed) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "an open shadow root starts with its host's node document" {
    try onFreshThread(false);
}

test "a closed shadow root starts with its host's node document" {
    try onFreshThread(true);
}
