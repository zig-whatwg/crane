//! An Attr torn down by Node's own teardown (lane nm3 batch 3, step 1).
//!
//! `Node.deinitNodeByType` - the teardown a tree runs for a node, and what
//! `dom.node_creation.destroyUninserted` runs for a node its creator drops -
//! dispatches on the node type to the node's own interface's deinit. An Attr
//! (and any type the switch did not name) took a fallback instead: it
//! cleared Node's live bit and ran EventTarget's deinit, and nothing else.
//! So for such a node
//!
//! - its NodeBase was never released: the rare block (a registered observer
//!   list, a node name, the childNodes cache) and what the block owns stayed
//!   allocated, and the Browser's final sweep could not find them - the live
//!   bit it walks by was already clear;
//! - the bridge still counted the node and the Browser's DOM memory still
//!   held its bytes;
//! - Attr's own state (its names and value) was left for the Browser's end;
//! - its teardown was never marked complete, so its slab slot was never
//!   returned.
//!
//! Every test runs under std.testing.allocator with a Browser scope of its
//! own, swept and ended in the test: a block left behind fails it as a leak.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,

    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

/// How many nodes `scope`'s bridge counts as registered.
fn liveNodes(scope: *runtime.BrowserScope) usize {
    return dom.instance_bridge.entryCount(scope);
}

test "an Attr torn down as an uninserted node releases its NodeBase, its rare block and its slot" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const nodes_before = liveNodes(&page.scope);
    const memory_before = page.scope.dom_memory.live;

    const attr = try interfaces.Document.call_createAttribute(page.document, str("data-x"));
    const generation = runtime.SlabAllocator.generationOf(attr);
    const base = dom.instance_bridge.getNodeBase(attr) orelse return error.NoNodeBase;
    try testing.expectEqual(dom.NodeBase.ATTRIBUTE_NODE, base.node_type);
    // A rare block with a block of its own behind it, which only the
    // NodeBase's release frees - what a MutationObserver registered on the
    // Attr makes (its list's head), without an observer to tell.
    try base.setOwnedNodeName(try base.allocator().dupe(u8, "owned-name"));
    try testing.expect(base.rare.blockBytes() != 0);
    try testing.expectEqual(nodes_before + 1, liveNodes(&page.scope));

    dom.node_creation.destroyUninserted(attr);

    // The bridge no longer counts it, and the Browser's DOM memory holds
    // none of its bytes: slot, State block, rare block, name record.
    try testing.expectEqual(nodes_before, liveNodes(&page.scope));
    try testing.expectEqual(memory_before, page.scope.dom_memory.live);
    // Its teardown completed, so its slot went back (no engine wraps it).
    try testing.expect(runtime.SlabAllocator.generationOf(attr) != generation);
}

test "an Attr torn down as an uninserted node frees its own state now, not at its Browser's end" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const attr = try interfaces.Document.call_createAttribute(page.document, str("data-y"));
    try interfaces.Attr.set_value(attr, str("a value of its own"));
    const nodes_before = runtime.ownStateCount(interfaces.Node.State, &page.scope);
    try testing.expectEqual(@as(usize, 1), runtime.ownStateCount(interfaces.Attr.State, &page.scope));

    dom.node_creation.destroyUninserted(attr);

    // One node fewer keeps a Node state, and no Attr state waits for the
    // Browser's sweep.
    try testing.expectEqual(nodes_before - 1, runtime.ownStateCount(interfaces.Node.State, &page.scope));
    try testing.expectEqual(@as(usize, 0), runtime.ownStateCount(interfaces.Attr.State, &page.scope));
}
