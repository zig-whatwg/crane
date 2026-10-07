//! DOM shadow-including preorder must include each host's closed root too.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    const result = try interfaces.Element.init(testing.allocator, document.ctx);
    errdefer dom.node_creation.destroyUninserted(result);
    try dom.node_creation.setElementNames(result, "http://www.w3.org/1999/xhtml", name);
    try dom.node_document.set(result, document);
    return result;
}

fn exercise(comptime closed: bool, comptime connectivity_only: bool) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(document);
    const host = try element(document, "div");
    _ = try interfaces.Node.call_appendChild(document, host);
    var attached = true;
    defer if (!attached) dom.node_creation.destroyUninserted(host);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = if (closed) ._closed_ else ._open_ });
    // A native fixture has no collector to release these parentless nodes.
    // The test owns them explicitly, through their real interface teardown.
    defer interfaces.ShadowRoot.deinit(shadow);
    const nested = try element(document, "article");
    _ = try interfaces.Node.call_appendChild(shadow, nested);
    const nested_shadow = try interfaces.Element.call_attachShadow(nested, .{ .mode = if (closed) ._open_ else ._closed_ });
    defer interfaces.ShadowRoot.deinit(nested_shadow);
    const deep = try element(document, "span");
    _ = try interfaces.Node.call_appendChild(nested_shadow, deep);
    const nested_light = try element(document, "b");
    _ = try interfaces.Node.call_appendChild(nested, nested_light);
    const light = try element(document, "em");
    _ = try interfaces.Node.call_appendChild(host, light);

    // Prove the fixture has the visibility difference that the IDL getter
    // enforces; the traversal must not use that getter to find closed roots.
    const visible: ?*runtime.Instance = if (closed) null else shadow;
    try testing.expectEqual(visible, try interfaces.Element.get_shadowRoot(host));
    const expected = [_]*runtime.Instance{ host, shadow, nested, nested_shadow, deep, nested_light, light };
    if (connectivity_only) {
        for (expected) |object| try testing.expect(try interfaces.Node.get_isConnected(object));
        _ = try interfaces.Node.call_removeChild(document, host);
        attached = false;
        for (expected) |object| {
            try testing.expect(!try interfaces.Node.get_isConnected(object));
            try testing.expect(!dom.instance_bridge.getNodeBase(object).?.is_connected);
        }
        _ = try interfaces.Node.call_appendChild(document, host);
        attached = true;
        for (expected) |object| {
            try testing.expect(try interfaces.Node.get_isConnected(object));
            try testing.expect(dom.instance_bridge.getNodeBase(object).?.is_connected);
        }
        return;
    }
    const host_base = dom.instance_bridge.getNodeBase(host).?;
    var inclusive = try dom.tree_helpers.getShadowIncludingInclusiveDescendants(testing.allocator, host_base);
    defer inclusive.deinit();
    try testing.expectEqual(expected.len, inclusive.len);
    for (expected, inclusive.toSlice()) |object, node| try testing.expectEqual(@as(?*anyopaque, object), dom.instance_bridge.getInstance(node));
    var descendants = try dom.tree_helpers.getShadowIncludingDescendants(testing.allocator, host_base);
    defer descendants.deinit();
    try testing.expectEqual(expected.len - 1, descendants.len);
    for (expected[1..], descendants.toSlice()) |object, node| try testing.expectEqual(@as(?*anyopaque, object), dom.instance_bridge.getInstance(node));
}

fn onFreshThread(comptime closed: bool, comptime connectivity_only: bool) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(closed, connectivity_only) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "CE traversal: an open root includes closed nested shadow trees before light children" {
    try onFreshThread(false, false);
}

test "CE traversal: a closed root includes its own shadow tree and nested open roots" {
    try onFreshThread(true, false);
}

test "CE traversal: removing and reinserting an open host updates nested shadow connectedness" {
    try onFreshThread(false, true);
}

test "CE traversal: removing and reinserting a closed host updates nested shadow connectedness" {
    try onFreshThread(true, true);
}
