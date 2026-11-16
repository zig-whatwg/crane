//! A leaf node keeps no first child (lane nm2 batch 2, step d: N9 of
//! tmp/redesign/nodedata-design.md; node-memory plan v2 section 6 item 5).
//!
//! Every node's NodeBase carried a `first_child` pointer. A Text, a Comment,
//! a CDATASection and a ProcessingInstruction can have no children (DOM
//! 4.2.3 "ensure pre-insert validity" step 1: a parent is a Document, a
//! DocumentFragment or an Element), so on them the word was always null - 8
//! bytes on the most numerous node of a parsed page after the element.
//! Blink and WebKit keep the first-child pointer in ContainerNode only
//! (core/dom/container_node.h `first_child_`; Source/WebCore/dom/
//! ContainerNode.h `m_firstChild`), and their Node::firstChild() answers
//! null for a node that is no container.
//!
//! Here the word stays where it is - NodeBase is one layout at one offset in
//! every node's State block - and a leaf uses it: CharacterData keeps its
//! data's word there (`NodeBase.leafWord`; dom.character_data.Data is the
//! pair of that word and the two lengths left in CharacterData's state, 8
//! bytes instead of 16). So:
//!
//! - `NodeBase.firstChild()` answers null for a leaf and is the only read of
//!   the word as a child: the field has another name, and `zig build
//!   lint-refcount` holds that nothing outside node_base.zig names it;
//! - linking a child under a leaf is refused in every build (it would write
//!   a pointer over the leaf's data);
//! - a Text's and a Comment's State is 8 bytes smaller (the total is pinned
//!   in node_block_sizes_test.zig).
//!
//! The pins name generated States and src/dom types only; they compile at
//! the base, where they fail.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const real_nodes = @import("real_nodes.zig");

const NodeBase = dom.NodeBase;

/// Whether this build's leaves keep their data's word in the NodeBase.
const leaf_word = @hasDecl(NodeBase, "leafWord") and @hasField(NodeBase, "leaf");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

test "NodeBase has no field named first_child; CharacterData's own state is its two lengths, 8 bytes" {
    if (comptime !leaf_word) return error.NoLeafWord;
    try testing.expect(!@hasField(NodeBase, "first_child"));
    try testing.expectEqual(@as(usize, 8), @sizeOf(@FieldType(interfaces.CharacterData.State, "_embedded")));
    try testing.expectEqual(@as(usize, 1), @sizeOf(@FieldType(NodeBase, "leaf")));
}

test "a container's firstChild is its first child; a leaf's is null whatever its word holds" {
    if (comptime !leaf_word) return error.NoLeafWord;
    // Real nodes with no node document (real_nodes.zig; lane wb1), linked by
    // hand: the word is the subject. They were NodeBase values on the stack,
    // the Text marked a leaf by the test; a real Text is one by construction.
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const parent = try nodes.bare(.element);
    const a = try nodes.bare(.element);
    const b = try nodes.bare(.text);
    try testing.expect(b.leaf and !a.leaf and !parent.leaf);
    try testing.expect(parent.firstChild() == null);
    parent.linkChildBefore(a, null);
    parent.linkChildBefore(b, null);
    try testing.expect(parent.firstChild().? == a);
    try testing.expect(parent.lastChild().? == b);

    // The leaf's word is its own: any bits, never a child. (The Text's data
    // is empty and inline; the word is put back before its teardown reads it.)
    const word = b.leafWord().*;
    b.leafWord().* = @intFromPtr(a);
    try testing.expect(b.firstChild() == null);
    try testing.expect(b.lastChild() == null);
    try testing.expectEqual(@as(usize, 0), b.childCount());
    var children = b.children();
    try testing.expect(children.next() == null);
    // And a walk of the parent's children passes over it.
    try testing.expectEqual(@as(usize, 2), parent.childCount());
    b.leafWord().* = word;

    parent.unlinkChild(b);
    parent.unlinkChild(a);
    try testing.expect(parent.firstChild() == null);
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
        self.div = try interfaces.Document.call_createElement(self.document, str("div"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    fn expectData(self: *Page, node: *runtime.Instance, expected: []const u8) !void {
        var value = try interfaces.CharacterData.get_data(node);
        defer value.deinit(self.ctx.allocator);
        try testing.expectEqualStrings(expected, value.asSlice());
        try testing.expectEqualStrings(expected, dom.character_data.dataOf(node).?);
    }
};

test "every CharacterData node is a leaf and no other node is; its data lives in its NodeBase's word" {
    if (comptime !leaf_word) return error.NoLeafWord;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    const text = try interfaces.Document.call_createTextNode(page.document, str("12345678"));
    const comment = try interfaces.Document.call_createComment(page.document, str("a comment longer than the word"));
    const fragment = try interfaces.Document.call_createDocumentFragment(page.document);
    _ = try interfaces.Node.call_appendChild(page.div, text);
    _ = try interfaces.Node.call_appendChild(page.div, comment);
    for ([_]*runtime.Instance{ text, comment }) |node| try testing.expect(dom.instance_bridge.getNodeBase(node).?.leaf);
    for ([_]*runtime.Instance{ page.div, page.document, fragment }) |node| try testing.expect(!dom.instance_bridge.getNodeBase(node).?.leaf);
    dom.node_creation.destroyUninserted(fragment);

    // Eight bytes: in the word itself, which is the NodeBase's.
    const base = dom.instance_bridge.getNodeBase(text).?;
    const bytes = dom.character_data.dataOf(text).?;
    try testing.expectEqualStrings("12345678", bytes);
    try testing.expect(@intFromPtr(bytes.ptr) == @intFromPtr(base.leafWord()));
    try testing.expect(base.firstChild() == null);
    try testing.expect((try interfaces.Node.get_firstChild(text)) == null);
    try testing.expect(!(try interfaces.Node.call_hasChildNodes(text)));

    // Every storage, through the DOM's own operations, with the tree's
    // walks reading the leaves between them.
    try interfaces.CharacterData.call_appendData(text, str("9"));
    try page.expectData(text, "123456789");
    try interfaces.CharacterData.call_deleteData(text, 0, 7);
    try page.expectData(text, "89");
    try interfaces.CharacterData.set_data(text, str("\n        "));
    try page.expectData(text, "\n        ");
    try page.expectData(comment, "a comment longer than the word");
    try testing.expectEqual(@as(usize, 2), dom.instance_bridge.getNodeBase(page.div).?.childCount());
    const tail = try interfaces.Text.call_splitText(text, 1);
    try page.expectData(text, "\n");
    try page.expectData(tail, "        ");
    try testing.expect((try interfaces.Node.get_nextSibling(text)).? == tail);
    try interfaces.Node.call_normalize(page.div);
    try page.expectData(text, "\n        ");

    // A deep clone copies the data, not the word's bits as a child.
    const clone = try interfaces.Node.call_cloneNode(page.div, .{ .was_passed = true, .value = true });
    const cloned_text = (try interfaces.Node.get_firstChild(clone)).?;
    try page.expectData(cloned_text, "\n        ");
    try testing.expect((try interfaces.Node.get_firstChild(cloned_text)) == null);
    dom.node_creation.destroyUninserted(clone);
}

test "a child under a leaf is refused by the DOM before any link is written" {
    if (comptime !leaf_word) return error.NoLeafWord;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    const text = try interfaces.Document.call_createTextNode(page.document, str("leaf"));
    _ = try interfaces.Node.call_appendChild(page.div, text);
    const child = try interfaces.Document.call_createElement(page.document, str("b"), .{ .was_passed = false, .value = undefined });
    // DOM 4.2.3 "ensure pre-insert validity" step 1.
    try testing.expectError(error.HierarchyRequestError, interfaces.Node.call_appendChild(text, child));
    try page.expectData(text, "leaf");
    dom.node_creation.destroyUninserted(child);
}
