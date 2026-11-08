//! The insert and remove steps visit a subtree in shadow-including tree
//! order, now over a loop instead of a recursion (lane crash1 batch 3).
//!
//! tree_helpers.collectShadowIncludingDescendants and mutation's
//! setConnectedRecursive recursed once per level, so moving a deep enough
//! tree into or out of a document overflowed the native stack. Both now run
//! tree_helpers.ShadowIncludingWalk. The order is observable - insert step
//! 7.7 runs the insertion steps (a script element's preparation among them)
//! "for each shadow-including inclusive descendant ... in shadow-including
//! tree order", remove step 14 the removing steps - so this test records the
//! steps' order on a tree of light children, shadow trees and a nested host,
//! and compares it with the order DOM 4.2.2 defines, walked here by
//! recursion over a small tree. It passes before and after the change.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const Node = *runtime.Instance;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: Node = undefined,
    body: Node = undefined,

    fn open(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(testing.allocator), .ctx = try runtime.ContextData.init(testing.allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.body = try self.element("body");
        _ = try interfaces.Node.call_appendChild(self.document, self.body);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    fn element(self: *Page, name: []const u8) !Node {
        return interfaces.Document.call_createElement(self.document, str(name), .notPassed());
    }

    fn add(self: *Page, parent: Node, name: []const u8) !Node {
        const node = try self.element(name);
        _ = try interfaces.Node.call_appendChild(parent, node);
        return node;
    }
};

/// What the registered insertion and removing steps saw, in order.
const Seen = struct {
    var nodes: [64]*dom.NodeBase = undefined;
    var count: usize = 0;

    fn reset() void {
        count = 0;
    }

    fn insertion(node: *dom.NodeBase) void {
        if (count < nodes.len) nodes[count] = node;
        count += 1;
    }

    fn removing(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
        _ = old_parent;
        insertion(node);
    }
};

/// DOM 4.2.2's shadow-including preorder, by recursion: the reference.
fn shadowIncludingOrder(node: Node, out: *std.ArrayListUnmanaged(*dom.NodeBase)) !void {
    try out.append(testing.allocator, dom.instance_bridge.getNodeBase(node).?);
    if (dom.shadow_hosts.rootForHost(node)) |shadow| try shadowIncludingOrder(shadow, out);
    var child = try interfaces.Node.get_firstChild(node);
    while (child) |c| : (child = try interfaces.Node.get_nextSibling(c)) try shadowIncludingOrder(c, out);
}

fn expectSeen(want: []const *dom.NodeBase) !void {
    try testing.expectEqual(want.len, Seen.count);
    try testing.expectEqualSlices(*dom.NodeBase, want, Seen.nodes[0..Seen.count]);
}

test "insert and remove run their steps over a light-and-shadow tree in shadow-including tree order" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const registries = dom.mutation.overrideRegistriesForTest();
    defer registries.restore();
    try dom.mutation.registerInsertionStepsCallback(&Seen.insertion);
    try dom.mutation.registerRemovingStepsCallback(&Seen.removing);

    // host > [shadow > [a1 > a1x, a2 (host) > shadow > [b1 > b2]], c1 > c2, c3 (host, closed) > shadow > [d1]]
    const host = try page.element("div");
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    const a1 = try page.add(shadow, "span");
    _ = try page.add(a1, "b");
    const a2 = try page.add(shadow, "section");
    const inner = try interfaces.Element.call_attachShadow(a2, .{ .mode = ._open_ });
    const b1 = try page.add(inner, "p");
    _ = try page.add(b1, "i");
    const c1 = try page.add(host, "p");
    _ = try page.add(c1, "em");
    const c3 = try page.add(host, "span");
    const closed = try interfaces.Element.call_attachShadow(c3, .{ .mode = ._closed_ });
    _ = try page.add(closed, "u");

    var order: std.ArrayListUnmanaged(*dom.NodeBase) = .empty;
    defer order.deinit(testing.allocator);
    try shadowIncludingOrder(host, &order);
    try testing.expectEqual(@as(usize, 13), order.items.len);

    // Insert step 7.7: the insertion steps for each shadow-including
    // inclusive descendant, in shadow-including tree order; and every one of
    // them connected.
    Seen.reset();
    _ = try interfaces.Node.call_appendChild(page.body, host);
    try expectSeen(order.items);
    for (order.items) |node| try testing.expect(node.is_connected);

    // Remove step 11 (the node's removing steps) and step 14 (each
    // shadow-including descendant's, in shadow-including tree order).
    Seen.reset();
    _ = try interfaces.Node.call_removeChild(page.body, host);
    try expectSeen(order.items);
    for (order.items) |node| try testing.expect(!node.is_connected);
}
