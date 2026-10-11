//! Node.getRootNode's composed option, a Selection document-check dependency.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    html: *runtime.Instance,
    host: *runtime.Instance,
    outer: *runtime.Instance,
    inner: *runtime.Instance,
    text: *runtime.Instance,
    light: *runtime.Instance,
    slot: *runtime.Instance,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.testing.allocator);
        self.ctx = try runtime.ContextData.init(std.testing.allocator, .{});
        self.document = try interfaces.Document.init(std.testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.html = try self.element("html");
        try append(self.document, self.html);
        self.host = try self.element("div");
        try append(self.html, self.host);
        self.outer = try interfaces.Element.call_attachShadow(self.host, .{ .mode = ._closed_ });
        try dom.node_document.set(self.outer, self.document);
        const inner_host = try self.element("span");
        try append(self.outer, inner_host);
        self.inner = try interfaces.Element.call_attachShadow(inner_host, .{ .mode = ._open_ });
        try dom.node_document.set(self.inner, self.document);
        self.text = try interfaces.Document.call_createTextNode(self.document, .initInterned("nested"));
        try append(self.inner, self.text);
        self.slot = try self.element("slot");
        try append(self.outer, self.slot);
        self.light = try self.element("b");
        try append(self.host, self.light);
    }

    fn element(self: *Fixture, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, .initInterned(name), .notPassed());
    }

    fn append(parent: *runtime.Instance, child: *runtime.Instance) !void {
        _ = try interfaces.Node.call_appendChild(parent, child);
    }

    fn deinit(self: *Fixture) void {
        // Hosts are torn down before their shadow roots, as in slot_assignment_test.
        interfaces.Document.deinit(self.document);
        interfaces.ShadowRoot.deinit(self.outer);
        interfaces.ShadowRoot.deinit(self.inner);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }
};

fn expectRoot(node: *runtime.Instance, composed: bool, expected: *runtime.Instance) !void {
    try std.testing.expectEqual(expected, try interfaces.Node.call_getRootNode(node, .passed(.{ .composed = composed })));
}

test "Selection dependency: composed root crosses nested closed and open shadow roots" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try expectRoot(f.text, false, f.inner);
    try std.testing.expectEqual(f.inner, try interfaces.Node.call_getRootNode(f.text, .notPassed()));
    try expectRoot(f.text, true, f.document);
    try expectRoot(f.inner, true, f.document);
    try expectRoot(f.outer, true, f.document);
}

test "Selection dependency: slot assignment does not change a light node's root" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try std.testing.expectEqual(f.slot, dom.shadow_dom_algorithms.assignedSlotOf(f.light).?);
    try expectRoot(f.light, false, f.document);
    try expectRoot(f.light, true, f.document);
}

test "Selection dependency: detached shadow trees have their outer host as composed root" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    _ = try interfaces.Node.call_removeChild(f.html, f.host);
    defer Fixture.append(f.html, f.host) catch {};
    try expectRoot(f.text, false, f.inner);
    try expectRoot(f.text, true, f.host);
    try expectRoot(f.light, false, f.host);
    try expectRoot(f.light, true, f.host);
}
