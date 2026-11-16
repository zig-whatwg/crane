//! The WithBase retirement (lane wb1; node-memory plan v2, X3 and section 6
//! item 7): every node lives in a node block the runtime made.
//!
//! Before the node allocator's chain (H1-H6) a NodeBase could also be a
//! value anywhere - a test's stack, a field of ElementWithBase /
//! TextWithBase / AttrWithBase - with its allocator tagged into its owner
//! word and a bare NodeBase as its node document. A NodeBase outside a node
//! block cannot hold 32-bit links (they decode from the block's cage), and
//! the plan's folded Instance makes "which Instance owns this node" address
//! arithmetic: so the owner-less form goes first. What these tests hold:
//!
//! 1. The types and the modules that worked only on them are gone, and so is
//!    every cast of a NodeBase to a struct.
//! 2. NodeBase has no owner-less form: no `ownerless`, no bare-NodeBase node
//!    document (`setDocumentBase`), and the owner word is the Instance or 0.
//! 3. `ownerInstance()`, whose null meant three things, is two accessors:
//!    `instance()` - the node's Instance, for code that holds a live node -
//!    and `registeredInstance()` - null before the node's registration and
//!    once its teardown released it, in a build that poisons released nodes
//!    too (the liveness test; the plan's H3 makes it a bit of the block's
//!    stamp).
//! 4. On a real page every node answers both, and its allocator and its
//!    document key come from its Instance.
//!
//! The pins name generated interfaces and src/dom only; they compile at the
//! base, where they fail.

const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const real_nodes = @import("real_nodes.zig");

const NodeBase = dom.NodeBase;
const Instance = runtime.Instance;
const baseOf = real_nodes.baseOf;
const str = real_nodes.str;

test "the WithBase node types and the modules that worked only on them are gone" {
    inline for (.{
        "ElementWithBase",   "TextWithBase",     "CommentWithBase",           "AttrWithBase",
        "element_with_base", "text_with_base",   "attr_with_base",            "selectors",
        "dom_token_list",    "DOMTokenListImpl", "scopeMatchSelectorsString", "range_mutations",
    }) |name| {
        if (@hasDecl(dom, name)) {
            std.debug.print("dom.{s} is still declared\n", .{name});
            return error.WithBaseDeclarationLeft;
        }
    }
    inline for (.{ "evaluator", "value", "context", "functions" }) |name| {
        if (@hasDecl(dom.xpath, name)) return error.OldXPathEvaluatorLeft;
    }
    // The grammar's types stay: XPathExpression's impl reads them.
    try testing.expect(@hasDecl(dom.xpath, "ast"));
}

test "NodeBase is cast to no struct and has no owner-less form" {
    inline for (.{
        "asElement",          "asElementConst",  "asText",               "asComment",  "asAttr",
        "asAttrConst",        "asCharacterData", "asCharacterDataConst", "asDocument", "ownerless",
        "ownerlessAllocator", "setDocumentBase",
    }) |name| {
        if (@hasDecl(NodeBase, name)) {
            std.debug.print("NodeBase.{s} is still declared\n", .{name});
            return error.OwnerlessFormLeft;
        }
    }
    // One meaning each: the old accessor's null meant three things.
    try testing.expect(!@hasDecl(NodeBase, "ownerInstance"));
    try testing.expect(@hasDecl(NodeBase, "instance"));
    try testing.expect(@hasDecl(NodeBase, "registeredInstance"));
    // No size change: the owner is still one word (the total is pinned in
    // node_block_sizes_test.zig).
    try testing.expectEqual(@as(usize, 8), @sizeOf(@FieldType(NodeBase, "owner")));
}

test "refcount's Ref counts NodeBase and nothing else" {
    // `Ref(T)` took any struct whose first field was a NodeBase - the
    // WithBase shape. A platform node's NodeBase is in its State block, at no
    // struct's start: NodeBase is the one counted type.
    if (!@hasDecl(dom.refcount, "counts_only_node_base")) return error.RefStillTakesANodeStruct;
    try testing.expect(dom.refcount.counts_only_node_base);
}

/// A page with one node of every kind script can make.
const Page = struct {
    nodes: real_nodes.Nodes,
    document: *Instance = undefined,
    all: [7]*Instance = undefined,

    fn open(self: *Page) !void {
        self.* = .{ .nodes = undefined };
        try self.nodes.open(testing.allocator);
        errdefer self.nodes.close();
        const doc = try self.nodes.document();
        self.document = doc;
        const div = try self.nodes.element(doc, "div");
        const text = try self.nodes.text(doc, "text");
        const comment = try self.nodes.comment(doc, "comment");
        const fragment = try self.nodes.fragment(doc);
        try self.nodes.setAttribute(div, "id", "x");
        const attr = (try interfaces.Element.call_getAttributeNode(div, str("id"))).?;
        try self.nodes.append(doc, div);
        try self.nodes.append(div, text);
        try self.nodes.append(div, comment);
        const bare = try self.nodes.bareInstance(.element);
        self.all = .{ doc, div, text, comment, fragment, attr, bare };
    }

    fn close(self: *Page) void {
        self.nodes.close();
    }
};

test "every node names its Instance; its allocator and its document key are the Instance's" {
    if (comptime !@hasDecl(NodeBase, "instance") or !@hasDecl(NodeBase, "registeredInstance")) return error.NoInstanceAccessors;
    var page: Page = undefined;
    try page.open();
    defer page.close();

    for (page.all) |node| {
        const base = baseOf(node);
        try testing.expectEqual(node, base.instance());
        try testing.expectEqual(@as(?*Instance, node), base.registeredInstance());
        try testing.expectEqual(@as(?*Instance, node), dom.instance_bridge.getInstanceTyped(Instance, base));
        try testing.expect(base.stands());
        // The owner word is the Instance, untagged.
        try testing.expectEqual(@intFromPtr(node), base.owner);
        // What the node allocates from is its Browser's allocator.
        const expected = runtime.allocatorOf(node);
        const actual = base.allocator();
        try testing.expect(expected.ptr == actual.ptr and expected.vtable == actual.vtable);
    }

    // A document's key is its Instance, and every node of it names that key.
    const document = baseOf(page.document);
    try testing.expectEqual(@intFromPtr(page.document), document.keyAsDocument());
    for (page.all[1..6]) |node| {
        const base = baseOf(node);
        try testing.expectEqual(document.keyAsDocument(), base.documentKey());
        try testing.expectEqual(@as(?*Instance, page.document), base.documentInstance());
        try testing.expectEqual(@as(?*NodeBase, document), base.documentBase());
    }
    // A node made with no document names none.
    const bare = baseOf(page.all[6]);
    try testing.expectEqual(@as(usize, 0), bare.documentKey());
    try testing.expectEqual(@as(?*Instance, null), bare.documentInstance());
    try testing.expectEqual(@as(?*NodeBase, null), bare.documentBase());
}

test "every node reached by a tree link from a live node names a live Instance" {
    // The assertion behind `instance()` at the sites that walk a live tree
    // (selector matching, the style engine, the slot and shadow algorithms,
    // focus navigation, the pointer states): a neighbour of a node the DOM
    // holds is registered and stands.
    if (comptime !@hasDecl(NodeBase, "instance")) return error.NoInstanceAccessors;
    var page: Page = undefined;
    try page.open();
    defer page.close();
    const div = page.all[1];
    const host = try page.nodes.element(page.document, "section");
    try page.nodes.append(div, host);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    const inner = try page.nodes.element(page.document, "span");
    try page.nodes.append(shadow, inner);

    var seen: usize = 0;
    var stack: [16]*NodeBase = undefined;
    var depth: usize = 0;
    stack[0] = baseOf(page.document);
    depth = 1;
    while (depth != 0) {
        depth -= 1;
        const node = stack[depth];
        seen += 1;
        try testing.expect(node.stands());
        const instance = node.instance();
        try testing.expectEqual(@as(?*NodeBase, node), dom.instance_bridge.getNodeBase(instance));
        if (node.parent_node) |parent| try testing.expect(parent.instance() == real_nodes.instanceOf(parent));
        var children = node.children();
        while (children.next()) |child| {
            try testing.expectEqual(@as(?*NodeBase, node), child.parent_node);
            stack[depth] = child;
            depth += 1;
        }
    }
    // document, div, text, comment, section.
    try testing.expectEqual(@as(usize, 5), seen);
    // The shadow tree: its root has no parent and is a node like any other.
    const shadow_base = baseOf(shadow);
    try testing.expectEqual(shadow, shadow_base.instance());
    try testing.expectEqual(inner, shadow_base.firstChild().?.instance());
}

test "a released node reads as released: registeredInstance is null, its owner word 0 in every build" {
    // The liveness test the teardown and collector code asks (dom.refcount's
    // host walks, the dying-tree prediction, the audit). Node's release
    // leaves the owner word 0 (dom.instance_bridge.unregister) and, since
    // lane uaf1, keeps the 0 across the poison a Browser may write over the
    // released NodeBase: "released" reads the same in a poisoning build and
    // in production. The poison in the owner word then means one thing - the
    // arena FREED the block - and it is no answer to a liveness test: a
    // Debug build panics on it (tests/dom/uaf1_freed_block_read_test.zig).
    // Lane wb1 pinned here that the poison read as "no Instance" (its low
    // bit, which no Instance's address has); that holds only for a release
    // build that poisons, so the poison is never followed as an address.
    if (comptime !@hasDecl(NodeBase, "registeredInstance")) return error.NoInstanceAccessors;
    if (comptime !@hasDecl(NodeBase, "freedBlockReadPanics")) return error.NoFreedBlockCheck;
    try testing.expectEqual(@as(u8, 1), runtime.ArenaAllocator.poison_byte & 1);
    try testing.expect(@alignOf(Instance) >= 2);
    try testing.expectEqual(@as(usize, 1), NodeBase.freed_owner_word & 1);

    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    const instance = try nodes.element(doc, "div");
    const base = baseOf(instance);
    try testing.expectEqual(@as(?*Instance, instance), base.registeredInstance());

    // The state a release leaves, written on a live node's block (a read
    // of a really released block would be a read after its free): the owner
    // word 0, the rest poison where the Browser poisons.
    const saved = base.*;
    @memset(std.mem.asBytes(base), runtime.ArenaAllocator.poison_byte);
    base.owner = 0;
    try testing.expectEqual(@as(?*Instance, null), base.registeredInstance());
    try testing.expectEqual(@as(?*anyopaque, null), dom.instance_bridge.getInstance(base));
    base.* = saved;
    try testing.expectEqual(@as(?*Instance, instance), base.registeredInstance());

    // And the real release, read the one way that is no read after a free:
    // through the Instance, whose slot's generation says it is gone.
    dom.node_creation.destroyUninserted(instance);
    try testing.expectEqual(@as(?*NodeBase, null), dom.instance_bridge.getNodeBase(instance));
}
