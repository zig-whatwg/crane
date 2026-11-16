//! A node's event listener list is a field of its rare block, and a node's
//! State nests no EventTarget level (lane nm3 batch 3, item c;
//! tmp/redesign/node-memory-plan-v2.md X2 and I1).
//!
//! Every node's State began with EventTarget's level: the address of its
//! event listener list (8 bytes, null on nearly every node) and the chain's
//! live word (4, padded to 8). Now:
//!
//! - the list's address is a slot of the node's rare block
//!   (dom.element_rare_data's `event_listeners`), there only once the node
//!   has a listener, an event handler or a watching owner - a 16-byte block
//!   for a node with nothing else rare. Gecko keeps a node's listener
//!   manager in its slots the same way (nsINode::mSlotsOrListenerManager,
//!   nsSlots::mListenerManager); Blink and WebKit pay a word in every
//!   EventTarget (EventTarget::data_; WeakPtrImplWithEventTargetData);
//! - the chain's live bits are a byte of the NodeBase, which `node_type`
//!   gave up (it was a u16 whose high byte was always 0);
//! - the NodeBase is at offset 0 of every node's State block.
//!
//! A div's block: 128 -> 112 bytes; a Text's: 112 -> 96 (pinned in
//! node_block_sizes_test.zig).
//!
//! The behaviour here runs without an engine: an event handler content
//! attribute's raw handler is a listener the list keeps with no engine value
//! (dom.event_handlers.setRaw), and an owner's watch makes the list's block
//! (dom.event_listener_changes.watch). Script's side - addEventListener,
//! dispatch while the rare block grows under a callback, collection - is in
//! tests/html/nm3_node_listeners_dispatch_test.zig.
//!
//! The pins name generated States and src/dom types only (AGENTS.md "The
//! impls boundary"); they compile at the base, where they fail.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const NodeBase = dom.NodeBase;
const rare_data = dom.element_rare_data;

/// Whether this build keeps a node's listener list in its rare block.
const in_rare = @hasField(rare_data.Field, "event_listeners");

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

fn baseOf(node: *runtime.Instance) *NodeBase {
    return dom.instance_bridge.getNodeBase(node).?;
}

fn raw(body: []const u8) dom.event_handlers.RawSource {
    return .{ .body = body, .url = "about:blank", .lineno = 1 };
}

// ============================================================================
// The shape
// ============================================================================

test "a node's State nests no EventTarget level: the NodeBase is at its first byte" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    try testing.expect(@FieldType(interfaces.Node.State, "base") == void);
    try testing.expectEqual(@as(usize, 0), dom.node_base.offset_in_state);
    try testing.expectEqual(@sizeOf(NodeBase), @sizeOf(interfaces.Node.State));
    // EventTarget's own State is what it was, for every target that is no
    // node: the list's address and the live word.
    try testing.expectEqual(@as(usize, 16), @sizeOf(interfaces.EventTarget.State));
}

test "the node type is one byte and the State chain's live bits are the byte beside it" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    try testing.expectEqual(@as(usize, 1), @sizeOf(@FieldType(NodeBase, "node_type")));
    try testing.expectEqual(@as(usize, 24), @offsetOf(NodeBase, "node_type"));
    try testing.expectEqual(@as(usize, 25), @offsetOf(NodeBase, "live"));
    try testing.expectEqual(@as(usize, 1), @sizeOf(@FieldType(NodeBase, "live")));
    try testing.expectEqual(@as(usize, 88), @sizeOf(NodeBase));
}

test "a node is still an EventTarget: its ancestry ends with EventTarget's State, with no bytes behind it" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const div = try page.element("div");
    defer interfaces.HTMLDivElement.deinit(div);

    const ancestors = div.vtable.ancestors;
    try testing.expectEqual(runtime.typeId(interfaces.EventTarget.State), ancestors[ancestors.len - 1].id);
    try testing.expectEqual(runtime.typeId(interfaces.Node.State), ancestors[ancestors.len - 2].id);
    try testing.expect(div.implements(interfaces.EventTarget.State));
    try testing.expect(div.implements(interfaces.Node.State));
    try testing.expect(div.implements(interfaces.Element.State));
    try testing.expect(div.stateAs(interfaces.EventTarget.State) == null);
    try testing.expect(div.stateAs(interfaces.Node.State) != null);

    // A target that is no node keeps its EventTarget State.
    const target = try interfaces.EventTarget.init(testing.allocator, &page.ctx);
    defer interfaces.EventTarget.deinit(target);
    try testing.expect(target.implements(interfaces.EventTarget.State));
    try testing.expect(target.stateAs(interfaces.EventTarget.State) != null);
    try testing.expect(!target.implements(interfaces.Node.State));
}

test "each level of a node's chain has its live bit in the NodeBase, and Node's release keeps the others" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const div = try page.element("div");
    // Node's level is bit 0, Element's bit 1, HTMLElement's bit 2.
    try testing.expectEqual(@as(u8, 0b111), baseOf(div).live);
    try testing.expectEqual(@as(usize, 1), runtime.ownStateCount(interfaces.HTMLElement.State, &page.scope));
    const text = try interfaces.Document.call_createTextNode(page.document, str("t"));
    // Node's, CharacterData's, Text's.
    try testing.expectEqual(@as(u8, 0b111), baseOf(text).live);
    interfaces.Text.deinit(text);
    interfaces.HTMLDivElement.deinit(div);
    try testing.expectEqual(@as(usize, 0), runtime.ownStateCount(interfaces.HTMLElement.State, &page.scope));
}

// ============================================================================
// The list
// ============================================================================

test "a node with no listener has no rare block; its first event handler makes a 16-byte one" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const div = try page.element("div");
    defer interfaces.HTMLDivElement.deinit(div);
    const base = baseOf(div);

    try testing.expectEqual(@as(usize, 0), base.rare.blockBytes());
    try testing.expect(!dom.event_handlers.hasListeners(div));
    try testing.expect(!dom.event_listener_types.hasListenersOfType(div, "click"));
    // Reading made nothing.
    try testing.expectEqual(@as(usize, 0), base.rare.blockBytes());

    try dom.event_handlers.setRaw(div, "click", raw("1"));
    try testing.expectEqual(@as(usize, 16), base.rare.blockBytes());
    try testing.expectEqual(@as(usize, 1), base.eventListeners().len());
    try testing.expect(dom.event_handlers.hasListeners(div));
    try testing.expect(dom.event_listener_types.hasListenersOfType(div, "click"));
    try testing.expect(!dom.event_listener_types.hasListenersOfType(div, "input"));
}

test "the list keeps its listeners while the rare block and its own block grow and move" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const div = try page.element("div");
    defer interfaces.HTMLDivElement.deinit(div);
    const base = baseOf(div);

    try dom.event_handlers.setRaw(div, "click", raw("1"));
    const rare_block = base.rare.block;
    const first_list = base.eventListeners().header;

    // Other rare fields: the rare block grows past its one slot and moves
    // (16 -> 32 bytes at the second field, 32 -> 64 at the fourth).
    try base.setStaticNodeName("EMBED");
    try testing.expect(base.rare.block != rare_block);
    try testing.expectEqual(@as(usize, 32), base.rare.blockBytes());
    try rare_data.putBytes(base.rareContext(), &base.rare, .nonce, "n");
    try rare_data.putBytes(base.rareContext(), &base.rare, .is_value, "v");
    try testing.expectEqual(@as(usize, 64), base.rare.blockBytes());
    try testing.expectEqual(first_list, base.eventListeners().header);
    try testing.expectEqual(@as(usize, 1), base.eventListeners().len());

    // More listeners: the list's own block grows (1, 2, 4, 8 listeners).
    inline for (.{ "input", "change", "keydown", "keyup", "focus" }) |event_type| {
        try dom.event_handlers.setRaw(div, event_type, raw("2"));
    }
    try testing.expectEqual(@as(usize, 6), base.eventListeners().len());
    inline for (.{ "click", "input", "change", "keydown", "keyup", "focus" }) |event_type| {
        try testing.expect(dom.event_listener_types.hasListenersOfType(div, event_type));
    }
    try testing.expectEqualStrings("EMBED", base.nodeName());

    // A handler set again keeps its place; erasing empties the list.
    try dom.event_handlers.setRaw(div, "click", raw("3"));
    try testing.expectEqual(@as(usize, 6), base.eventListeners().len());
    dom.event_handlers.eraseAll(div);
    try testing.expect(!dom.event_handlers.hasListeners(div));
    try dom.event_handlers.setRaw(div, "blur", raw("4"));
    try testing.expectEqual(@as(usize, 1), base.eventListeners().len());
}

test "every node type keeps its listeners in its rare block: Text, Comment, DocumentFragment, Document, Attr" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const text = try interfaces.Document.call_createTextNode(page.document, str("t"));
    defer interfaces.Text.deinit(text);
    const comment = try interfaces.Document.call_createComment(page.document, str("c"));
    defer interfaces.Comment.deinit(comment);
    const fragment = try interfaces.Document.call_createDocumentFragment(page.document);
    defer interfaces.DocumentFragment.deinit(fragment);
    const attr = try interfaces.Document.call_createAttribute(page.document, str("data-a"));
    defer interfaces.Attr.deinit(attr);

    inline for (.{ text, comment, fragment, attr, page.document }) |node| {
        try testing.expect(!dom.event_handlers.hasListeners(node));
        try dom.event_handlers.setRaw(node, "ping", raw("1"));
        try testing.expect(dom.event_handlers.hasListeners(node));
        try testing.expectEqual(@as(usize, 1), baseOf(node).eventListeners().len());
    }
    // A Text's data is its leaf word, untouched by the list beside it.
    var data = try interfaces.CharacterData.get_data(text);
    defer data.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("t", data.asSlice());
}

test "a watched node's list block is made with no listener, and its first listener keeps the watch" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const div = try page.element("div");
    defer interfaces.HTMLDivElement.deinit(div);
    const base = baseOf(div);

    try dom.event_listener_changes.watch(div);
    try testing.expect(base.eventListeners().watched());
    try testing.expectEqual(@as(usize, 0), base.eventListeners().len());
    try testing.expect(base.hasEventListenerBlock());
    try dom.event_handlers.setRaw(div, "click", raw("1"));
    try testing.expect(base.eventListeners().watched());
}

// ============================================================================
// Teardown: every exit frees the list (std.testing.allocator fails a leak)
// ============================================================================

test "a node's own teardown releases its listeners before its rare block goes" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    // A div made and torn down first: what its Browser keeps for the first
    // one of a kind (a name's record) is there before the measurement.
    interfaces.HTMLDivElement.deinit(try page.element("div"));
    const memory_before = page.scope.dom_memory.live;
    const div = try page.element("div");
    try dom.event_handlers.setRaw(div, "click", raw("a body the raw handler owns"));
    try dom.event_handlers.setRaw(div, "my-own-event", raw("an event type the list owns a copy of"));
    try baseOf(div).setStaticNodeName("EMBED");
    interfaces.HTMLDivElement.deinit(div);
    try testing.expectEqual(memory_before, page.scope.dom_memory.live);
}

test "a tree's teardown releases every node's listeners" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const root = try page.element("div");
    var parent = root;
    for (0..8) |_| {
        const child = try page.element("span");
        try dom.event_handlers.setRaw(child, "click", raw("1"));
        const text = try interfaces.Document.call_createTextNode(page.document, str("t"));
        try dom.event_handlers.setRaw(text, "my-own-event", raw("2"));
        _ = try interfaces.Node.call_appendChild(child, text);
        _ = try interfaces.Node.call_appendChild(parent, child);
        parent = child;
    }
    interfaces.HTMLDivElement.deinit(root);
}

test "the Browser's final sweep releases the listeners of a node no deinit reached" {
    if (comptime !in_rare) return error.ListenersNotInTheRareBlock;
    var page: Page = undefined;
    try page.open(testing.allocator);
    // No deinit for these: the page's close runs the sweeps.
    const orphan = try page.element("div");
    try dom.event_handlers.setRaw(orphan, "click", raw("1"));
    try dom.event_handlers.setRaw(orphan, "my-own-event", raw("2"));
    const text = try interfaces.Document.call_createTextNode(page.document, str("t"));
    try dom.event_handlers.setRaw(text, "ping", raw("3"));
    page.close();
}
