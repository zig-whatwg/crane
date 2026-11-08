//! A node's connected flag is exact, shadow trees included, so the insert,
//! remove and move steps read it instead of walking to the root (lane
//! crash1 batch 3).
//!
//! "A node is connected if its shadow-including root is a document." Those
//! steps used to ask NodeBase.is_connected and, when it said no, walk to the
//! root and on through shadow hosts (mutation.isConnectedThroughShadow) - on
//! every insert into a detached tree, which made a tree built one node at a
//! time cost O(nodes x depth). The walk was there because one case left the
//! flag wrong: a shadow root attached to a host already in a document. The
//! attach step now gives the new root its host's flag
//! (dom.shadow_hosts.attached), as Blink's and WebKit's isConnected flags
//! are set; this file checks the flag against the definition - the walk -
//! for every node, after each of thousands of seeded mutations, and pins
//! that pre-insertion validity's early answer for a node with no children
//! still sees a host's shadow tree and a template's contents.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const Node = *runtime.Instance;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// An engine-less HTML document with a body.
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
};

fn flagOf(node: Node) bool {
    return (dom.instance_bridge.getNodeBase(node) orelse return false).is_connected;
}

/// The definition: the shadow-including root is a document.
fn connectedByWalk(node: Node) bool {
    var current = node;
    while (true) {
        var root = current;
        while (interfaces.Node.get_parentNode(root) catch null) |parent| root = parent;
        const root_type = interfaces.Node.get_nodeType(root) catch return false;
        if (root_type == interfaces.Node.get_DOCUMENT_NODE()) return true;
        if (root.stateAs(interfaces.ShadowRoot.State) == null) return false;
        current = interfaces.ShadowRoot.get_host(root) catch return false;
    }
}

/// A node's flag, or for a Document its standing as connected.
fn expectExact(nodes: []const Node) !void {
    for (nodes) |node| {
        if ((interfaces.Node.get_nodeType(node) catch 0) == interfaces.Node.get_DOCUMENT_NODE()) continue;
        const walk = connectedByWalk(node);
        if (flagOf(node) != walk) std.debug.print("flag {} walk {} for a {d}\n", .{ flagOf(node), walk, interfaces.Node.get_nodeType(node) catch 0 });
        try testing.expectEqual(walk, flagOf(node));
    }
}

test "a shadow root attached to a connected host is connected, and follows its host out and back in" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const host = try page.element("div");
    _ = try interfaces.Node.call_appendChild(page.body, host);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    try testing.expect(flagOf(shadow));
    const inner = try page.element("span");
    _ = try interfaces.Node.call_appendChild(shadow, inner);
    try testing.expect(flagOf(inner));
    try testing.expect(try interfaces.Node.get_isConnected(inner));

    _ = try interfaces.Node.call_removeChild(page.body, host);
    try expectExact(&.{ host, shadow, inner });
    try testing.expect(!flagOf(inner));
    // Into a detached tree: still not connected; then into the document.
    const holder = try page.element("div");
    _ = try interfaces.Node.call_appendChild(holder, host);
    try expectExact(&.{ holder, host, shadow, inner });
    _ = try interfaces.Node.call_appendChild(page.body, holder);
    try expectExact(&.{ holder, host, shadow, inner });
    try testing.expect(flagOf(inner));

    // A shadow root attached to a disconnected host, its host inserted later;
    // nested inside the first shadow tree.
    const nested_host = try page.element("p");
    const nested = try interfaces.Element.call_attachShadow(nested_host, .{ .mode = ._closed_ });
    try testing.expect(!flagOf(nested));
    _ = try interfaces.Node.call_appendChild(inner, nested_host);
    try expectExact(&.{ nested_host, nested });
    try testing.expect(flagOf(nested));
    // Attached to a host that is connected only through a shadow tree.
    const deep_host = try page.element("span");
    _ = try interfaces.Node.call_appendChild(nested, deep_host);
    const deep = try interfaces.Element.call_attachShadow(deep_host, .{ .mode = ._open_ });
    try expectExact(&.{ deep_host, deep });
    try testing.expect(flagOf(deep));
}

test "the connected flag equals the definition after each of 3,000 seeded mutations" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    var prng = std.Random.DefaultPrng.init(0xc0ec_7ed1);
    const random = prng.random();

    var nodes: std.ArrayListUnmanaged(Node) = .empty;
    defer nodes.deinit(testing.allocator);
    // Parents a node may go into: elements, shadow roots, fragments, the body.
    var parents: std.ArrayListUnmanaged(Node) = .empty;
    defer parents.deinit(testing.allocator);
    try nodes.append(testing.allocator, page.body);
    try parents.append(testing.allocator, page.body);

    const names = [_][]const u8{ "div", "span", "p", "section" };
    for (0..3000) |_| {
        switch (random.uintLessThan(u32, 10)) {
            // Make a node: an element (sometimes with a shadow root), a text
            // node or a fragment.
            0, 1, 2 => {
                const kind = random.uintLessThan(u32, 6);
                const node = if (kind == 0)
                    try interfaces.Document.call_createTextNode(page.document, str("t"))
                else if (kind == 1)
                    try interfaces.Document.call_createDocumentFragment(page.document)
                else
                    try page.element(names[random.uintLessThan(usize, names.len)]);
                try nodes.append(testing.allocator, node);
                if (kind != 0) try parents.append(testing.allocator, node);
            },
            // Attach a shadow root to an element that has none.
            3 => {
                const host = nodes.items[random.uintLessThan(usize, nodes.items.len)];
                if (host.stateAs(interfaces.Element.State) == null or host == page.body) continue;
                const attached = if (random.boolean())
                    interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ })
                else
                    interfaces.Element.call_attachShadow(host, .{ .mode = ._closed_ });
                const shadow = attached catch continue;
                try nodes.append(testing.allocator, shadow);
                try parents.append(testing.allocator, shadow);
            },
            // Insert a node somewhere (a fragment moves its children).
            4, 5, 6, 7 => {
                const node = nodes.items[random.uintLessThan(usize, nodes.items.len)];
                const parent = parents.items[random.uintLessThan(usize, parents.items.len)];
                if (node == page.body or node.stateAs(interfaces.ShadowRoot.State) != null) continue;
                _ = interfaces.Node.call_appendChild(parent, node) catch continue;
            },
            // Remove a node from its parent.
            else => {
                const node = nodes.items[random.uintLessThan(usize, nodes.items.len)];
                if (node == page.body) continue;
                const parent = (interfaces.Node.get_parentNode(node) catch null) orelse continue;
                _ = interfaces.Node.call_removeChild(parent, node) catch continue;
            },
        }
        try expectExact(nodes.items);
    }
}

test "pre-insertion validity: a node with no children still contains its shadow tree and its template contents" {
    var page: Page = undefined;
    try page.open();
    defer page.close();
    // A host with no light children, inserted into its own shadow tree.
    const host = try page.element("div");
    _ = try interfaces.Node.call_appendChild(page.body, host);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    const inside = try page.element("span");
    _ = try interfaces.Node.call_appendChild(shadow, inside);
    try testing.expectError(error.HierarchyRequestError, interfaces.Node.call_appendChild(inside, host));
    try testing.expectError(error.HierarchyRequestError, interfaces.Node.call_appendChild(shadow, host));
    // A template, which has no children, inserted into its own contents.
    const template = try page.element("template");
    _ = try interfaces.Node.call_appendChild(page.body, template);
    const contents = try interfaces.HTMLTemplateElement.get_content(template);
    const in_contents = try page.element("p");
    _ = try interfaces.Node.call_appendChild(contents, in_contents);
    try testing.expectError(error.HierarchyRequestError, interfaces.Node.call_appendChild(in_contents, template));
    try testing.expectError(error.HierarchyRequestError, interfaces.Node.call_appendChild(contents, template));
    // A leaf into itself.
    const leaf = try page.element("b");
    try testing.expectError(error.HierarchyRequestError, interfaces.Node.call_appendChild(leaf, leaf));
    // And a leaf anywhere else goes in.
    _ = try interfaces.Node.call_appendChild(inside, leaf);
    try testing.expectEqual(inside, (try interfaces.Node.get_parentNode(leaf)).?);
}
