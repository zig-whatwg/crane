//! dom.instance_bridge answers a node's NodeBase from the node's own state -
//! the hook Node installs (`node_base_of`), reading Node's InternalState in
//! the instance's generated State (runtime.OwnState) - with no table, no
//! lock and no cache (lane perf2, batch 2: tmp/plans/perf2b2-design.md).
//! These pin what the map and its cache answered before, over real nodes of
//! an engine-less page: a node's NodeBase, which names it back; null for an
//! object that is no node, and for a node torn down; null for a freed slot,
//! counted as a read after the free; and the count of registered nodes.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const testing = std.testing;
const allocator = testing.allocator;
const bridge = dom.instance_bridge;

fn name(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// An engine-less page in a Browser scope of its own: a document and what
/// the test makes in it.
const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page) !void {
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
    }

    fn element(self: *Page, local_name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, name(local_name), .{ .was_passed = false, .value = undefined });
    }

    /// The document's tree, then the Browser's end, as Browser.deinit runs
    /// it with no engine.
    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

test "a node's NodeBase is its own, names it back, and is the tree's" {
    interfaces.process_hooks.startHooksForTest();
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const div = try page.element("div");
    const text = try interfaces.Document.call_createTextNode(page.document, name("t"));
    _ = try interfaces.Node.call_appendChild(div, text);
    _ = try interfaces.Node.call_appendChild(page.document, div);

    const div_base = bridge.getNodeBase(div) orelse return error.NoNodeBase;
    const text_base = bridge.getNodeBase(text) orelse return error.NoNodeBase;
    const document_base = bridge.getNodeBase(page.document) orelse return error.NoNodeBase;
    try testing.expectEqual(@as(?*anyopaque, div), div_base.owner_instance);
    try testing.expectEqual(@as(?*anyopaque, text), text_base.owner_instance);
    try testing.expectEqual(@as(?*anyopaque, page.document), document_base.owner_instance);
    try testing.expectEqual(text_base, div_base.first_child.?);
    try testing.expectEqual(div_base, document_base.first_child.?);
    try testing.expectEqual(div_base, bridge.getNodeBase(div).?);
    // Typed and untyped agree.
    try testing.expectEqual(div_base, bridge.getNodeBaseTyped(runtime.Instance, div).?);
    try testing.expectEqual(@as(?*runtime.Instance, div), bridge.getInstanceTyped(runtime.Instance, div_base));
}

test "an object that is no node has no NodeBase, and asking reads nothing of it" {
    interfaces.process_hooks.startHooksForTest();
    var page: Page = undefined;
    try page.open();
    defer page.close();
    // A platform object of another type: its vtable's ancestry has no Node.
    const headers = try interfaces.Headers.init(allocator, &page.ctx);
    defer interfaces.Headers.deinit(headers);
    try testing.expect(bridge.getNodeBase(headers) == null);
    try testing.expectEqual(@as(usize, 0), bridge.deadSlotLookups(&page.scope));
}

test "every node made is counted once, and its teardown takes it back out" {
    interfaces.process_hooks.startHooksForTest();
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const before = bridge.entryCount(&page.scope);
    var made: [8]*runtime.Instance = undefined;
    for (&made) |*slot| slot.* = try page.element("span");
    try testing.expectEqual(before + made.len, bridge.entryCount(&page.scope));

    // A node torn down (as its tree or the collector tears it down): no
    // NodeBase, and no longer counted.
    const gone = made[3];
    interfaces.Element.deinit(gone);
    try testing.expectEqual(before + made.len - 1, bridge.entryCount(&page.scope));
    if (runtime.SlabAllocator.generationOf(gone) != runtime.SlabAllocator.dead_generation) {
        try testing.expect(bridge.getNodeBase(gone) == null);
    }
    for (made, 0..) |node, i| {
        if (i == 3) continue;
        try testing.expect(bridge.getNodeBase(node) != null);
    }
}

test "a freed slot answers null without being read, and the read is counted" {
    interfaces.process_hooks.startHooksForTest();
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const span = try page.element("span");
    // Torn down and its storage returned: the slot is dead, its first word
    // the slab's free-list pointer.
    runtime.Instance.deinit(span);
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(span));
    const before = bridge.deadSlotLookups(&page.scope);
    try testing.expect(bridge.getNodeBase(span) == null);
    try testing.expectEqual(before + 1, bridge.deadSlotLookups(&page.scope));
}
