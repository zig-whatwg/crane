//! Node's childNodes list is kept in the node's rare block (lane nm2 batch 2,
//! step a; node-memory plan v2 section 6 item 5, lane nm1's queue 2a).
//!
//! Every node's generated State carried `cached_childNodes`, 8 bytes for a
//! [SameObject] NodeList that most nodes never hand out - a Text, a Comment
//! and a childless element included. It is a field of the node's ONE sparse
//! rare block now (dom.node_rare_data's `child_nodes`; the block's word is
//! NodeBase's since this batch's step b), read and kept by the generated
//! getter through dom.same_object_cache's node accessors. Blink keeps the
//! list in the node's rare data (Node::childNodes() ->
//! EnsureRareData().EnsureNodeLists().EnsureChildNodeList, core/dom/node.cc
//! and node_lists_node_data.h at chromium 44274363dc1a), WebKit too
//! (ContainerNode::childNodes -> ensureRareData().ensureNodeLists()
//! .ensureChildNodeList, Source/WebCore/dom/ContainerNode.cpp).
//!
//! - A node whose childNodes was never read has no block; the first read
//!   costs a 16-byte block (one slot).
//! - [SameObject]: the same list every read, on an element, a Text and a
//!   Document alike, and beside an element's own rare fields.
//! - The node's cache is raw (the list holds the node, never the reverse):
//!   when the list is freed before its node the slot is cleared and the next
//!   read makes a new list (dom.refcount's childNodesFreed).
//!
//! The State's size is pinned in node_block_sizes_test.zig; the codegen's
//! output in tests/codegen/cg1_element_same_object_test.zig. These name
//! generated interfaces and src/dom types only; they compile at the base,
//! where they fail.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const rare_data = dom.node_rare_data;

/// Whether this build keeps the list in the rare block.
const in_rare = @hasField(rare_data.Field, "child_nodes");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, str(name), .{ .was_passed = false, .value = undefined });
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

/// `node`'s rare block's bytes as its allocator was asked for them; 0 for none.
fn blockBytes(node: *runtime.Instance) usize {
    return dom.instance_bridge.getNodeBase(node).?.rare.blockBytes();
}

fn cached(node: *runtime.Instance) ?*runtime.Instance {
    return rare_data.get(dom.instance_bridge.getNodeBase(node).?.rare, .child_nodes);
}

test "Node's State keeps no childNodes cache: it is a field of the node's rare block" {
    if (comptime !in_rare) return error.ChildNodesNotInRareData;
    try testing.expect(!@hasField(@FieldType(interfaces.Node.State, "own"), "cached_childNodes"));
    try testing.expect(rare_data.Value(.child_nodes) == *runtime.Instance);
}

test "childNodes: no block until it is read, a 16-byte block after, the same list every read - on an element, a Text and a Document" {
    if (comptime !in_rare) return error.ChildNodesNotInRareData;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    const text = try interfaces.Document.call_createTextNode(page.document, str("t"));
    _ = try interfaces.Node.call_appendChild(page.div, text);

    var lists: [3]*runtime.Instance = undefined;
    for ([_]*runtime.Instance{ page.div, text, page.document }, 0..) |node, i| {
        try testing.expectEqual(@as(usize, 0), blockBytes(node));
        const list = try interfaces.Node.get_childNodes(node);
        try testing.expect((try interfaces.Node.get_childNodes(node)) == list);
        try testing.expect(cached(node).? == list);
        try testing.expectEqual(@as(usize, 16), blockBytes(node));
        lists[i] = list;
    }
    // The lists are live over their nodes' children.
    try testing.expectEqual(@as(u32, 1), try interfaces.NodeList.get_length(lists[0]));
    try testing.expectEqual(@as(u32, 0), try interfaces.NodeList.get_length(lists[1]));
    try testing.expectEqual(@as(u32, 1), try interfaces.NodeList.get_length(lists[2]));

    // The lists are their wrappers' to free, and no engine wraps them here:
    // freed by hand, before their nodes (as cg1_element_same_object_test
    // did until lane lk1 moved its run-time tests to tests/html, on a real
    // page). Each lets go of its node's cache as it goes.
    for (lists) |list| runtime.Instance.deinit(list);
}

test "a childNodes list freed before its node clears the node's cache; the next read makes a new list in the same slot" {
    if (comptime !in_rare) return error.ChildNodesNotInRareData;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    const first = try interfaces.Node.get_childNodes(page.div);
    const block = dom.instance_bridge.getNodeBase(page.div).?.rare.block;
    runtime.Instance.deinit(first);
    // Cleared, not dangling: the freed list's slot reads as no list.
    try testing.expect(cached(page.div) == null);

    const second = try interfaces.Node.get_childNodes(page.div);
    try testing.expect(cached(page.div).? == second);
    try testing.expect((try interfaces.Node.get_childNodes(page.div)) == second);
    // The field kept its bit: the same block, no new allocation for it.
    try testing.expect(dom.instance_bridge.getNodeBase(page.div).?.rare.block == block);
    try testing.expectEqual(@as(usize, 16), blockBytes(page.div));
    runtime.Instance.deinit(second);
}

test "childNodes shares the block with an element's own rare fields, and both survive each other's grow" {
    if (comptime !in_rare) return error.ChildNodesNotInRareData;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    const class_list = try interfaces.Element.get_classList(page.div);
    const list = try interfaces.Node.get_childNodes(page.div);
    // classList's slot and childNodes': 2 fields, 3 slots, 32 bytes.
    try testing.expectEqual(@as(usize, 32), blockBytes(page.div));
    _ = try interfaces.Element.get_attributes(page.div);
    try interfaces.Element.call_setAttribute(page.div, str("title"), .{ .domstring = str("t") });
    _ = (try interfaces.Element.call_getAttributeNode(page.div, str("title"))).?;
    // 5 fields now: the block grew and moved (a freed one reads 0xdd).
    try testing.expectEqual(@as(usize, 64), blockBytes(page.div));
    try testing.expect((try interfaces.Node.get_childNodes(page.div)) == list);
    try testing.expect((try interfaces.Element.get_classList(page.div)) == class_list);

    // An orphan with its list made: freed by its creator, unwrapped - the
    // chain ends the list's edge at Node's level, then Node frees the block.
    const orphan = try page.element("p");
    const orphan_list = try interfaces.Node.get_childNodes(orphan);
    runtime.Instance.deinit(orphan_list);
    dom.node_creation.destroyUninserted(orphan);

    runtime.Instance.deinit(list);
    runtime.Instance.deinit(class_list);
}
