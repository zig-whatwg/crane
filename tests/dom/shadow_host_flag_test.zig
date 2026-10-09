//! NodeBase.is_shadow_host: set where a shadow root attaches, clear on every
//! other node, and kept by clones (only through the clonable path) and
//! adoption. It is a fast-path guard for the slot steps of insert and remove;
//! the Element state's shadow root stays the source of truth.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const allocator = std.testing.allocator;

fn base(instance: *runtime.Instance) *dom.NodeBase {
    return dom.instance_bridge.getNodeBase(instance).?;
}

test "the shadow host bit fits NodeBase's padding" {
    // 440 bytes before the bit was added, and after. 448 since lane
    // nodeholds' hold chain head (`NodeBase.holds`, a pointer: the padding
    // beside node_type and the bools is 3 bytes), accepted by the integrator.
    try std.testing.expectEqual(@as(usize, 448), @sizeOf(dom.NodeBase));
}

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    other: *runtime.Instance,
    body: *runtime.Instance,
    shadows: [4]*runtime.Instance = undefined,
    shadow_count: usize = 0,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        self.* = .{ .ctx = try runtime.ContextData.init(allocator, .{}), .document = undefined, .other = undefined, .body = undefined };
        self.document = try newDocument(&self.ctx);
        self.other = try newDocument(&self.ctx);
        const html = try element(self.document, "html");
        _ = try interfaces.Node.call_appendChild(self.document, html);
        self.body = try element(self.document, "body");
        _ = try interfaces.Node.call_appendChild(html, self.body);
    }

    fn newDocument(ctx: *runtime.ContextData) !*runtime.Instance {
        const document = try interfaces.Document.init(allocator, ctx);
        try dom.document_internals.setContentType(document, "text/html");
        try dom.document_internals.setDocumentType(document, .html);
        return document;
    }

    fn deinit(self: *Fixture) void {
        interfaces.Document.deinit(self.document);
        interfaces.Document.deinit(self.other);
        for (self.shadows[0..self.shadow_count]) |shadow| interfaces.ShadowRoot.deinit(shadow);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
    }

    fn attach(self: *Fixture, host: *runtime.Instance, clonable: bool) !void {
        const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_, .clonable = clonable });
        try dom.node_document.set(shadow, self.document);
        self.shadows[self.shadow_count] = shadow;
        self.shadow_count += 1;
    }

    /// The shadow root `host` was given by a clone (none for a host that is
    /// not one), recorded for teardown.
    fn adoptShadowOf(self: *Fixture, host: *runtime.Instance) void {
        const shadow = dom.shadow_hosts.rootForHost(host) orelse return;
        self.shadows[self.shadow_count] = shadow;
        self.shadow_count += 1;
    }
};

test "attachShadow sets the shadow host bit; other nodes have it clear" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const host = try Fixture.element(f.document, "div");
    const plain = try Fixture.element(f.document, "div");
    _ = try interfaces.Node.call_appendChild(f.body, host);
    _ = try interfaces.Node.call_appendChild(f.body, plain);
    try std.testing.expect(!base(host).is_shadow_host);
    try f.attach(host, false);
    try std.testing.expect(base(host).is_shadow_host);
    try std.testing.expect(!base(plain).is_shadow_host);
    try std.testing.expect(!base(f.body).is_shadow_host);
    try std.testing.expect(!base(f.shadows[0]).is_shadow_host);
}

test "a clone is a shadow host only through the clonable path, and adoption keeps the bit" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const clonable = try Fixture.element(f.document, "div");
    const closed_to_clones = try Fixture.element(f.document, "div");
    _ = try interfaces.Node.call_appendChild(f.body, clonable);
    _ = try interfaces.Node.call_appendChild(f.body, closed_to_clones);
    try f.attach(clonable, true);
    try f.attach(closed_to_clones, false);

    const clone = try interfaces.Node.call_cloneNode(clonable, .{ .was_passed = false, .value = false });
    f.adoptShadowOf(clone);
    _ = try interfaces.Node.call_appendChild(f.body, clone);
    try std.testing.expect(dom.shadow_hosts.rootForHost(clone) != null);
    try std.testing.expect(base(clone).is_shadow_host);

    const plain_clone = try interfaces.Node.call_cloneNode(closed_to_clones, .{ .was_passed = false, .value = false });
    _ = try interfaces.Node.call_appendChild(f.body, plain_clone);
    try std.testing.expect(dom.shadow_hosts.rootForHost(plain_clone) == null);
    try std.testing.expect(!base(plain_clone).is_shadow_host);

    // Adopted into another document, a host is still a host.
    _ = try interfaces.Document.call_adoptNode(f.other, clonable);
    try std.testing.expect(base(clonable).is_shadow_host);
    _ = try interfaces.Node.call_appendChild(f.other, clonable);
}
