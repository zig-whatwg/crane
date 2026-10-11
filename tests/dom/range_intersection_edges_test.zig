//! DOM intersectsNode uses strict comparisons at both range edges.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

test "Range intersectsNode: touching either boundary is not an intersection" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(std.testing.allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(std.testing.allocator, &ctx);
    defer interfaces.Document.deinit(document);
    const parent = try interfaces.Document.call_createElement(document, .initInterned("root"), .notPassed());
    _ = try interfaces.Node.call_appendChild(document, parent);
    var children: [3]*runtime.Instance = undefined;
    for (&children) |*child| {
        child.* = try interfaces.Document.call_createElement(document, .initInterned("span"), .notPassed());
        _ = try interfaces.Node.call_appendChild(parent, child.*);
    }
    const range = try interfaces.Document.call_createRange(document);
    defer interfaces.Range.deinit(range);

    // Includes both equal-boundary edges and a collapsed range between nodes.
    for (0..4) |start| {
        for (start..4) |end| {
            try interfaces.Range.call_setStart(range, parent, @intCast(start));
            try interfaces.Range.call_setEnd(range, parent, @intCast(end));
            for (children, 0..) |child, index| {
                try std.testing.expectEqual(index < end and index + 1 > start, try interfaces.Range.call_intersectsNode(range, child));
            }
        }
    }

    // A collapsed point *inside* a Text still intersects that Text's outer
    // boundary interval; do not replace strict ordering with an empty check.
    const text = try interfaces.Document.call_createTextNode(document, .initInterned("abc"));
    _ = try interfaces.Node.call_appendChild(children[1], text);
    try interfaces.Range.call_setStart(range, text, 1);
    try interfaces.Range.call_setEnd(range, text, 1);
    try std.testing.expect(try interfaces.Range.call_intersectsNode(range, text));
    try std.testing.expect(try interfaces.Range.call_intersectsNode(range, document));
    const detached = try interfaces.Document.call_createElement(document, .initInterned("detached"), .notPassed());
    defer interfaces.Element.deinit(detached);
    try std.testing.expect(!try interfaces.Range.call_intersectsNode(range, detached));
}
