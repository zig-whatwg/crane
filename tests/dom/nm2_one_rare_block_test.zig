//! One rare word per node (lane nm2 batch 2; tmp/redesign/node-memory-plan-v2.md
//! B7 and section 6 item 5, lane nm1's queue 2b).
//!
//! A node kept TWO rare pointers: NodeBase's, to a fixed 104-byte
//! NodeRareData (the registered observer list, the node name brand, a Text's
//! slottable state), and - on an element - Element's, to the sparse block of
//! lane rare1 (dom.element_rare_data). 8 bytes on every element for a second
//! word that is null on nearly all of them, and a 104-byte block for one
//! registered observer.
//!
//! Now the node has ONE word, NodeBase's, and it holds the sparse block:
//! the node-level fields are fields of that block like any element field.
//! Blink has had this shape since 2026-01 (one `Node::data_`, whose
//! NodeRareData is the sparse block and carries the mutation observer data,
//! the flat tree data and the element's fields alike: core/dom/node.h,
//! core/dom/node_rare_data.h at chromium 44274363dc1a); WebKit keeps one
//! `m_rareDataWithBitfields` whose ElementRareData extends NodeRareData.
//!
//! - Element's state keeps no rare word (its size is pinned in
//!   node_block_sizes_test.zig); NodeBase's `rare` is the block's Holder.
//! - The registered observer list and the node name are blocks of their own
//!   that the sparse block points at, so an entry and a name never move
//!   when the block grows; a registered observer costs a 16-byte block and
//!   a 16-byte list head, not 104 bytes.
//! - An element's teardown lets its own fields go and leaves the block to
//!   its NodeBase's (the destruction chain runs Element's part first): the
//!   node-level fields are still there when Node's part reads them.
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
const RegisteredObserver = dom.node_base.RegisteredObserverType;

/// Whether this build keeps one rare word per node.
const one_word = @FieldType(NodeBase, "rare") == rare_data.Holder;

/// Element's InternalState, as its generated State keeps it by value.
const ElementState = @FieldType(interfaces.Element.State, "_embedded");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

// ============================================================================
// The shape
// ============================================================================

test "a node has one rare word: NodeBase's holds the sparse block, Element's state keeps none" {
    if (comptime !one_word) return error.NodeBaseRareIsNotTheSparseBlock;
    if (comptime @hasField(ElementState, "rare")) return error.ElementKeepsARareWord;
    if (comptime @hasDecl(dom.node_base, "NodeRareData")) return error.FixedNodeRareDataKept;
    try testing.expectEqual(@as(usize, 8), @sizeOf(@FieldType(NodeBase, "rare")));
}

// ============================================================================
// The node-level fields, on a bare NodeBase
// ============================================================================

fn bareNode() NodeBase {
    return .{
        .owner = NodeBase.ownerless(&std.testing.allocator),
        .node_type = NodeBase.ELEMENT_NODE,
    };
}

/// Distinct observers, never dereferenced: a registration names its observer
/// by address only.
const Observers = struct {
    slots: [3]u64 = .{ 0, 0, 0 },

    fn registration(self: *Observers, index: usize) RegisteredObserver {
        return RegisteredObserver.initFromPtr(@ptrCast(&self.slots[index]), .{ .attributes = true });
    }

    fn indexOf(self: *const Observers, registered: *const RegisteredObserver) usize {
        return (@intFromPtr(registered.getObserverPtr()) - @intFromPtr(&self.slots[0])) / @sizeOf(u64);
    }

    fn expectOrder(self: *const Observers, node: *const NodeBase, expected: []const usize) !void {
        var seen: [8]usize = undefined;
        var count: usize = 0;
        var entries = node.registeredObservers();
        while (entries.next()) |registered| : (count += 1) seen[count] = self.indexOf(registered);
        try testing.expectEqualSlices(usize, expected, seen[0..count]);
    }
};

test "one registered observer costs a 16-byte block, and its entry stays where it is while the block grows" {
    if (comptime !one_word) return error.NodeBaseRareIsNotTheSparseBlock;
    var observers: Observers = .{};
    var node = bareNode();
    defer node.deinitRareData();

    try testing.expectEqual(@as(usize, 0), node.rare.blockBytes());
    const first = try node.appendRegisteredObserver(observers.registration(0));
    // One field: the header and one slot, which points at the list's head.
    try testing.expectEqual(@as(usize, 16), node.rare.blockBytes());
    const block = node.rare.block;

    // A second node-level field and an element-level one: the block grows
    // and moves; the entry, the list's head and the name do not.
    try node.setStaticNodeName("EMBED");
    var words: [1]u64 align(16) = .{0};
    try rare_data.put(node.rareContext(), &node.rare, .class_list, @ptrCast(&words[0]));
    try testing.expect(node.rare.block != block);
    try testing.expectEqual(@as(usize, 32), node.rare.blockBytes());

    const second = try node.appendRegisteredObserver(observers.registration(1));
    try observers.expectOrder(&node, &.{ 0, 1 });
    try testing.expectEqualStrings("EMBED", node.nodeName());
    first.options = .{ .child_list = true };
    try testing.expect(first.options.child_list);

    node.removeRegisteredObserver(first);
    try observers.expectOrder(&node, &.{1});
    node.removeRegisteredObserver(second);
    try testing.expect(!node.hasRegisteredObservers());
    // The element-level field is cleared by its owner; the teardown frees
    // the block, the list's head and the name's record (std.testing.allocator).
    rare_data.clear(&node.rare, .class_list);
}

test "an element's teardown part lets its fields go and leaves the node's: the block is the NodeBase's to free" {
    if (comptime !one_word) return error.NodeBaseRareIsNotTheSparseBlock;
    var node = bareNode();
    defer node.deinitRareData();
    const ctx = node.rareContext();

    const owned = try testing.allocator.dupe(u8, "SCRIPT");
    try node.setOwnedNodeName(owned);
    try rare_data.putBytes(ctx, &node.rare, .nonce, "n0nce");
    const slottable = try rare_data.ensureOwn(ctx, &node.rare, .slottable);
    try testing.expect(slottable.assigned_slot == null);
    try testing.expect(rare_data.hasElementFields(node.rare));

    // What Element's `end` runs once its fields' owners let go of them.
    // Each of its fields reads as never set; their bits stay (a cleared
    // field keeps its bit), so the block neither moves nor shrinks.
    const block = node.rare.block;
    rare_data.releaseElementFields(ctx, &node.rare);
    try testing.expect(node.rare.block == block);
    try testing.expect(rare_data.getBytes(node.rare, .nonce) == null);
    try testing.expect(rare_data.get(node.rare, .slottable) == null);
    // The node-level field is untouched, in the same block.
    try testing.expectEqualStrings("SCRIPT", node.nodeName());
    try testing.expect(node.hasOwnedNodeName());
}

// ============================================================================
// On a page
// ============================================================================

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

test "an element's fields and its node's fields are one block, freed once at both exits (poisoning allocator)" {
    if (comptime !one_word) return error.NodeBaseRareIsNotTheSparseBlock;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    // An embed element names its NodeBase (the node-level field) when it is
    // made; `attributes` and an Attr node are Element's fields.
    const in_tree = try page.element("embed");
    _ = try interfaces.Node.call_appendChild(page.div, in_tree);
    const orphan = try page.element("embed");
    for ([_]*runtime.Instance{ in_tree, orphan }) |embed| {
        const base = dom.instance_bridge.getNodeBase(embed).?;
        try testing.expectEqualStrings("EMBED", base.nodeName());
        try testing.expectEqual(@as(usize, 16), base.rare.blockBytes());
        _ = try interfaces.Element.get_attributes(embed);
        try interfaces.Element.call_setAttribute(embed, str("title"), .{ .domstring = str("t") });
        _ = (try interfaces.Element.call_getAttributeNode(embed, str("title"))).?;
        // One block: what Element's accessors read is the NodeBase's word.
        try testing.expect(rare_data.of(embed).block == base.rare.block);
        try testing.expectEqualStrings("EMBED", base.nodeName());
    }
    // `in_tree` goes by its document's teardown, through its own deinit;
    // `orphan` by the Browser's sweeps (Element's, then Node's).
}
