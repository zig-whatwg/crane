//! Regression for the Range WPT oracle's unbounded swap recursion.
//! DOM: https://dom.spec.whatwg.org/#dom-node-comparedocumentposition
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const Tree = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    root: *runtime.Instance,

    fn init(self: *Tree) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.testing.allocator);
        self.ctx = try runtime.ContextData.init(std.testing.allocator, .{});
        self.document = try interfaces.Document.init(std.testing.allocator, &self.ctx);
        self.root = try self.element(self.document, "root");
    }

    fn element(self: *Tree, parent: *runtime.Instance, name: []const u8) !*runtime.Instance {
        const node = try interfaces.Document.call_createElement(self.document, .initInterned(name), .notPassed());
        _ = try interfaces.Node.call_appendChild(parent, node);
        return node;
    }

    fn deinit(self: *Tree) void {
        interfaces.Document.deinit(self.document);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }
};

fn expectOrder(a: *runtime.Instance, b: *runtime.Instance, expected: u16) !void {
    try std.testing.expectEqual(expected, try interfaces.Node.call_compareDocumentPosition(a, b));
    const reverse = (expected & 33) | ((expected & 2) << 1) | ((expected & 4) >> 1) |
        ((expected & 8) << 1) | ((expected & 16) >> 1);
    try std.testing.expectEqual(reverse, try interfaces.Node.call_compareDocumentPosition(b, a));
}

test "Range comparison oracle: sibling subtrees have opposite document positions" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(std.testing.allocator, .{});
    defer ctx.deinit();
    const document = try interfaces.Document.init(std.testing.allocator, &ctx);
    defer interfaces.Document.deinit(document);
    const root = try interfaces.Document.call_createElement(document, .initInterned("root"), .notPassed());
    _ = try interfaces.Node.call_appendChild(document, root);
    const first = try interfaces.Document.call_createElement(document, .initInterned("p"), .notPassed());
    _ = try interfaces.Node.call_appendChild(root, first);
    const second = try interfaces.Document.call_createElement(document, .initInterned("p"), .notPassed());
    _ = try interfaces.Node.call_appendChild(root, second);
    const a = try interfaces.Document.call_createTextNode(document, .initInterned("first"));
    _ = try interfaces.Node.call_appendChild(first, a);
    const b = try interfaces.Document.call_createTextNode(document, .initInterned("second"));
    _ = try interfaces.Node.call_appendChild(second, b);

    // dom/common.js:getPosition swaps while b reports a FOLLOWING. Both
    // directions returning FOLLOWING makes the second swap repeat the first.
    // Pin the cause natively without crashing the shared DOM test executable.
    try std.testing.expectEqual(@as(u16, 4), try interfaces.Node.call_compareDocumentPosition(a, b));
    try std.testing.expectEqual(@as(u16, 2), try interfaces.Node.call_compareDocumentPosition(b, a));
    const ra = try interfaces.Document.call_createRange(document);
    defer interfaces.Range.deinit(ra);
    const rb = try interfaces.Document.call_createRange(document);
    defer interfaces.Range.deinit(rb);
    try interfaces.Range.call_setStart(ra, a, 0);
    try interfaces.Range.call_setEnd(ra, a, 0);
    try interfaces.Range.call_setStart(rb, b, 0);
    try interfaces.Range.call_setEnd(rb, b, 0);
    try std.testing.expectEqual(@as(i16, -1), try interfaces.Range.call_compareBoundaryPoints(ra, 0, rb));
    try std.testing.expectEqual(@as(i16, 1), try interfaces.Range.call_compareBoundaryPoints(rb, 0, ra));
}

test "Node comparison: every connected pair agrees with preorder and containment" {
    var f: Tree = undefined;
    try f.init();
    defer f.deinit();
    const a = try f.element(f.root, "a");
    const a0 = try f.element(a, "a0");
    const a1 = try f.element(a, "a1");
    const b = try f.element(f.root, "b");
    const b0 = try f.element(b, "b0");
    const nodes = [_]*runtime.Instance{ f.document, f.root, a, a0, a1, b, b0 };
    for (nodes, 0..) |first, i| {
        try expectOrder(first, first, 0);
        for (nodes[i + 1 ..]) |second| {
            var ancestor = try interfaces.Node.get_parentNode(second);
            while (ancestor != null and ancestor.? != first) ancestor = try interfaces.Node.get_parentNode(ancestor.?);
            try expectOrder(first, second, if (ancestor == first) 20 else 4);
        }
    }
}

test "Node comparison: deep cousins compare without recursive tree traversal" {
    var f: Tree = undefined;
    try f.init();
    defer f.deinit();
    var a = try f.element(f.root, "a");
    var b = try f.element(f.root, "b");
    for (0..512) |_| {
        a = try f.element(a, "a");
        b = try f.element(b, "b");
    }
    try expectOrder(a, b, 4);
    try expectOrder(f.root, a, 20);
}

test "Node comparison: attributes use their owners and attribute-list order" {
    var f: Tree = undefined;
    try f.init();
    defer f.deinit();
    const a = try f.element(f.root, "a");
    const child = try f.element(a, "child");
    const b = try f.element(f.root, "b");
    try interfaces.Element.call_setAttribute(a, .initInterned("first"), .{ .domstring = .initInterned("1") });
    try interfaces.Element.call_setAttribute(a, .initInterned("second"), .{ .domstring = .initInterned("2") });
    try interfaces.Element.call_setAttribute(b, .initInterned("third"), .{ .domstring = .initInterned("3") });
    const first = (try interfaces.Element.call_getAttributeNode(a, .initInterned("first"))).?;
    defer {
        _ = interfaces.Element.call_removeAttributeNode(a, first) catch unreachable;
        interfaces.Attr.deinit(first);
    }
    const second = (try interfaces.Element.call_getAttributeNode(a, .initInterned("second"))).?;
    defer {
        _ = interfaces.Element.call_removeAttributeNode(a, second) catch unreachable;
        interfaces.Attr.deinit(second);
    }
    const third = (try interfaces.Element.call_getAttributeNode(b, .initInterned("third"))).?;
    defer {
        _ = interfaces.Element.call_removeAttributeNode(b, third) catch unreachable;
        interfaces.Attr.deinit(third);
    }
    try expectOrder(first, first, 0);
    try expectOrder(first, second, 36);
    try expectOrder(a, first, 20);
    try expectOrder(f.root, first, 20);
    try expectOrder(first, child, 4);
    try expectOrder(first, third, 4);
    try expectOrder(first, b, 4);
    try expectOrder(child, third, 4);
}

test "Node comparison: disconnected trees and unattached attributes stay consistently ordered" {
    var f: Tree = undefined;
    try f.init();
    defer f.deinit();
    const detached = try interfaces.Document.call_createElement(f.document, .initInterned("detached"), .notPassed());
    defer interfaces.Element.deinit(detached);
    const attr = try interfaces.Document.call_createAttribute(f.document, .initInterned("unattached"));
    defer interfaces.Attr.deinit(attr);
    const nodes = [_]*runtime.Instance{ f.root, detached, attr };
    for (nodes, 0..) |a, i| {
        for (nodes[i + 1 ..]) |b| {
            const result = try interfaces.Node.call_compareDocumentPosition(a, b);
            try std.testing.expect(result == 35 or result == 37);
            try expectOrder(a, b, result);
            try std.testing.expectEqual(result, try interfaces.Node.call_compareDocumentPosition(a, b));
        }
    }
}
