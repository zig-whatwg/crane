//! DOM removal visits closed/nested shadow trees before a host's light tree.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const NodeBase = dom.NodeBase;

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    html: *runtime.Instance,
    host: *runtime.Instance,
    shadow: *runtime.Instance,
    nested: *runtime.Instance,
    nested_shadow: *runtime.Instance,
    light: *runtime.Instance,
    scripts: [3]*runtime.Instance,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.testing.allocator);
        self.ctx = try runtime.ContextData.init(std.testing.allocator, .{});
        self.document = try interfaces.Document.init(std.testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.html = try self.element("html");
        _ = try interfaces.Node.call_appendChild(self.document, self.html);
        self.host = try self.element("div");
        self.shadow = try interfaces.Element.call_attachShadow(self.host, .{ .mode = ._closed_ });
        // attachShadow's native factory does not yet inherit its node document.
        // Set it through the owning hook, as parsers do for created nodes.
        try dom.node_document.set(self.shadow, self.document);
        self.scripts[0] = try self.element("script");
        _ = try interfaces.Node.call_appendChild(self.shadow, self.scripts[0]);
        self.nested = try self.element("span");
        _ = try interfaces.Node.call_appendChild(self.shadow, self.nested);
        self.nested_shadow = try interfaces.Element.call_attachShadow(self.nested, .{ .mode = ._open_ });
        try dom.node_document.set(self.nested_shadow, self.document);
        self.scripts[1] = try self.element("script");
        _ = try interfaces.Node.call_appendChild(self.nested_shadow, self.scripts[1]);
        self.light = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.host, self.light);
        self.scripts[2] = try self.element("script");
        _ = try interfaces.Node.call_appendChild(self.light, self.scripts[2]);
    }

    fn element(self: *Fixture, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
    }

    fn connect(self: *Fixture) !void {
        _ = try interfaces.Node.call_appendChild(self.html, self.host);
    }

    fn deinit(self: *Fixture) void {
        // Teardown the host before the roots it references. Host teardown
        // severs the links; roots own only their ordinary children.
        if (base(self.host).parent_node == null) interfaces.HTMLDivElement.deinit(self.host);
        interfaces.Document.deinit(self.document);
        interfaces.ShadowRoot.deinit(self.shadow);
        interfaces.ShadowRoot.deinit(self.nested_shadow);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn expected(self: *Fixture) [8]*NodeBase {
        return .{ base(self.host), base(self.shadow), base(self.scripts[0]), base(self.nested), base(self.nested_shadow), base(self.scripts[1]), base(self.light), base(self.scripts[2]) };
    }
};

fn base(instance: *runtime.Instance) *NodeBase {
    return dom.instance_bridge.getNodeBase(instance).?;
}

test "shadow-including traversal includes the root host's closed and nested roots before light children" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const expected = fixture.expected();
    var inclusive = try dom.tree_helpers.getShadowIncludingInclusiveDescendants(std.testing.allocator, base(fixture.host));
    defer inclusive.deinit();
    try std.testing.expectEqualSlices(*NodeBase, &expected, inclusive.items());
    var descendants = try dom.tree_helpers.getShadowIncludingDescendants(std.testing.allocator, base(fixture.host));
    defer descendants.deinit();
    try std.testing.expectEqualSlices(*NodeBase, expected[1..], descendants.items());
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, dom.tree_helpers.getShadowIncludingDescendants(failing.allocator(), base(fixture.host)));
}

test "host insertion and removal propagate connectedness and release shadow script blockers" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    try fixture.connect();
    const expected = fixture.expected();
    for (expected) |node| try std.testing.expect(node.is_connected);
    for (fixture.scripts) |script| {
        try dom.document_rendering.block(script);
        try std.testing.expect(dom.document_rendering.contains(fixture.document, script));
    }
    _ = try interfaces.Node.call_removeChild(fixture.html, fixture.host);
    for (expected) |node| try std.testing.expect(!node.is_connected);
    for (fixture.scripts) |script| try std.testing.expect(!dom.document_rendering.contains(fixture.document, script));
}

test "allocation failure after detaching a host still removes nested shadow blockers" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    try fixture.connect();
    for (fixture.scripts) |script| {
        try dom.document_rendering.block(script);
        try std.testing.expect(dom.document_rendering.contains(fixture.document, script));
    }
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const parent = base(fixture.html);
    const saved_allocator = parent.allocator;
    parent.allocator = failing.allocator();
    defer parent.allocator = saved_allocator;
    try dom.mutation.remove(base(fixture.host), true);
    try std.testing.expect(failing.has_induced_failure);
    for (fixture.expected()) |node| try std.testing.expect(!node.is_connected);
    for (fixture.scripts) |script| try std.testing.expect(!dom.document_rendering.contains(fixture.document, script));
}
