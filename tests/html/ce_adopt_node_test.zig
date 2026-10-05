//! Document.adoptNode must use the shared DOM adoption algorithm.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const Case = enum { parented_range, detached_range, shadow_tree };

fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    const result = try interfaces.Element.init(testing.allocator, document.ctx);
    errdefer dom.node_creation.destroyUninserted(result);
    try dom.node_creation.setElementNames(result, "http://www.w3.org/1999/xhtml", name);
    try dom.node_document.set(result, document);
    return result;
}

fn exercise(comptime case: Case) !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(document);
    const destination = try interfaces.Document.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(destination);
    const host = try element(document, "div");
    // Adoption leaves it detached; if a preceding assertion failed while it
    // was parented, the source document still owns its cleanup instead.
    defer if ((interfaces.Node.get_parentNode(host) catch null) == null) dom.node_creation.destroyUninserted(host);

    if (case == .shadow_tree) {
        const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._closed_ });
        defer interfaces.ShadowRoot.deinit(shadow);
        const shadow_child = try element(document, "span");
        _ = try interfaces.Node.call_appendChild(shadow, shadow_child);
        const light_child = try element(document, "em");
        _ = try interfaces.Node.call_appendChild(host, light_child);
        try testing.expectError(error.NotSupportedError, interfaces.Document.call_adoptNode(destination, document));
        try testing.expectError(error.HierarchyRequestError, interfaces.Document.call_adoptNode(destination, shadow));
        try testing.expectEqual(host, try interfaces.Document.call_adoptNode(destination, host));
        for ([_]*runtime.Instance{ host, shadow, shadow_child, light_child }) |node| {
            try testing.expectEqual(@as(?*runtime.Instance, destination), try interfaces.Node.get_ownerDocument(node));
        }
        return;
    }

    const text = try interfaces.Document.call_createTextNode(document, runtime.DOMString.initInterned("abcdef"));
    _ = try interfaces.Node.call_appendChild(host, text);
    if (case == .parented_range) _ = try interfaces.Node.call_appendChild(document, host);
    const range = try interfaces.Document.call_createRange(document);
    defer interfaces.Range.deinit(range);
    try interfaces.Range.call_setStart(range, text, 1);
    try interfaces.Range.call_setEnd(range, text, 4);
    try testing.expectEqual(host, try interfaces.Document.call_adoptNode(destination, host));
    try testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Node.get_parentNode(host));
    try testing.expectEqual(@as(?*runtime.Instance, destination), try interfaces.Node.get_ownerDocument(text));
    if (case == .parented_range) {
        try testing.expectEqual(document, try interfaces.AbstractRange.get_startContainer(range));
        try testing.expectEqual(document, try interfaces.AbstractRange.get_endContainer(range));
        try testing.expectEqual(@as(u32, 0), try interfaces.AbstractRange.get_startOffset(range));
        try testing.expectEqual(@as(u32, 0), try interfaces.AbstractRange.get_endOffset(range));
    } else {
        try testing.expectEqual(text, try interfaces.AbstractRange.get_startContainer(range));
        try testing.expectEqual(text, try interfaces.AbstractRange.get_endContainer(range));
        try interfaces.CharacterData.call_insertData(text, 0, runtime.DOMString.initInterned("XY"));
        try testing.expectEqual(@as(u32, 3), try interfaces.AbstractRange.get_startOffset(range));
        try testing.expectEqual(@as(u32, 6), try interfaces.AbstractRange.get_endOffset(range));
    }
}

fn onFreshThread(comptime case: Case) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(case) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "adoptNode removes a parented element and relocates its live range" {
    try onFreshThread(.parented_range);
}

test "adoptNode moves a detached element's live range to the new document" {
    try onFreshThread(.detached_range);
}

test "adoptNode rejects a shadow root and adopts a host's closed shadow descendants" {
    try onFreshThread(.shadow_tree);
}
