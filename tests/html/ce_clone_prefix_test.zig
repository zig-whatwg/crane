//! DOM clone-single-node step 1.1 preserves the namespace prefix.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn exercise(comptime prefixed: bool) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(document);
    const original = try interfaces.Document.call_createElementNS(
        document,
        runtime.DOMString.initInterned("urn:ce-clone-prefix"),
        runtime.DOMString.initInterned(if (prefixed) "p:item" else "item"),
        .{ .was_passed = false, .value = undefined },
    );
    defer dom.node_creation.destroyUninserted(original);
    for ([_]bool{ false, true }) |deep| {
        const copy = try interfaces.Node.call_cloneNode(original, .{ .was_passed = true, .value = deep });
        defer dom.node_creation.destroyUninserted(copy);
        var name = try interfaces.Node.get_nodeName(copy);
        defer name.deinit(testing.allocator);
        try testing.expectEqualStrings(if (prefixed) "p:item" else "item", name.asSlice());
        var local_name = try interfaces.Element.get_localName(copy);
        defer local_name.deinit(testing.allocator);
        try testing.expectEqualStrings("item", local_name.asSlice());
        try testing.expectEqual(@as(?*runtime.Instance, document), try interfaces.Node.get_ownerDocument(copy));
    }
}

fn onFreshThread(comptime prefixed: bool) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(prefixed) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "an element clone does not invent an empty namespace prefix" {
    try onFreshThread(false);
}

test "an element clone preserves a nonempty namespace prefix" {
    try onFreshThread(true);
}
