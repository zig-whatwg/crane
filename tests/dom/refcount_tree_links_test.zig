//! Reference counting, step 3: tree links (tmp/plans/refcount-design.md
//! section 7, lane rc3). Still shadow mode: the counts are kept and checked,
//! and decide nothing.
//!
//! Every parent write goes through NodeBase.setParent (the parent bit), and
//! insert, remove, move and adopt keep `subtree_holds` along the
//! host-including chain: a shadow root's and a template's contents' totals
//! count in their host's. The Document keeps its two counts (decision D6):
//! `referencing_nodes`, the nodes that name it as their node document (WebKit
//! Document::incrementReferencingNodeCount), and `foreign_holds`, the holds of
//! its detached trees (a detached root's total counts there).
//!
//! In shadow mode nothing releases a node's born reference yet, so every node
//! is held: a node's `subtree_holds` is the number of nodes in its
//! host-including subtree, and a document's `foreign_holds` is the number of
//! nodes in its detached trees. The numbers below rely on that.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const allocator = std.testing.allocator;
const refcount = dom.refcount;
const NodeBase = dom.NodeBase;

fn base(instance: *runtime.Instance) *NodeBase {
    return dom.instance_bridge.getNodeBase(instance).?;
}

fn counts(document: *runtime.Instance) *refcount.DocumentCounts {
    return refcount.documentCounts(document).?;
}

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    other: *runtime.Instance,
    body: *runtime.Instance,
    /// A shadow root, freed after the documents (its host's teardown leaves
    /// it to its owner, as tests/dom/shadow_host_flag_test.zig does).
    shadow: ?*runtime.Instance = null,

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
        if (self.shadow) |shadow| interfaces.ShadowRoot.deinit(shadow);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
    }

    /// A detached `div` with two `span` children, made in `document`.
    fn smallTree(document: *runtime.Instance) !*runtime.Instance {
        const div = try element(document, "div");
        _ = try interfaces.Node.call_appendChild(div, try element(document, "span"));
        _ = try interfaces.Node.call_appendChild(div, try element(document, "span"));
        return div;
    }
};

test "a new node names its document: referencing_nodes and foreign_holds rise by one" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const before = counts(f.document).*;
    const div = try Fixture.element(f.document, "div");
    defer dom.node_creation.destroyUninserted(div);
    try std.testing.expectEqual(before.referencing_nodes + 1, counts(f.document).referencing_nodes);
    try std.testing.expectEqual(before.foreign_holds + 1, counts(f.document).foreign_holds);
    try std.testing.expect(base(div).rc_flags.foreign);
    try std.testing.expect(!refcount.hasParentBit(base(div)));
}

test "freeing a detached node takes it out of both counts" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const before = counts(f.document).*;
    const div = try Fixture.smallTree(f.document);
    try std.testing.expectEqual(before.referencing_nodes + 3, counts(f.document).referencing_nodes);
    try std.testing.expectEqual(before.foreign_holds + 3, counts(f.document).foreign_holds);
    dom.node_creation.destroyUninserted(div);
    try std.testing.expectEqual(before.referencing_nodes, counts(f.document).referencing_nodes);
    try std.testing.expectEqual(before.foreign_holds, counts(f.document).foreign_holds);
}

test "appendChild sets the parent bit and moves the subtree's holds into the document's tree" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const doc_total = base(f.document).subtree_holds;
    const foreign = counts(f.document).foreign_holds;
    const div = try Fixture.smallTree(f.document);
    try std.testing.expectEqual(@as(u32, 3), base(div).subtree_holds);
    try std.testing.expectEqual(foreign + 3, counts(f.document).foreign_holds);

    _ = try interfaces.Node.call_appendChild(f.body, div);
    try std.testing.expect(refcount.hasParentBit(base(div)));
    try std.testing.expect(!base(div).rc_flags.foreign);
    try std.testing.expectEqual(doc_total + 3, base(f.document).subtree_holds);
    try std.testing.expectEqual(foreign, counts(f.document).foreign_holds);
    try refcount.verifyTree(base(f.document));
}

test "removeChild clears the parent bit; the removed subtree's holds become the document's foreign holds" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const div = try Fixture.smallTree(f.document);
    _ = try interfaces.Node.call_appendChild(f.body, div);
    const doc_total = base(f.document).subtree_holds;
    const foreign = counts(f.document).foreign_holds;

    _ = try interfaces.Node.call_removeChild(f.body, div);
    defer dom.node_creation.destroyUninserted(div);
    try std.testing.expect(!refcount.hasParentBit(base(div)));
    try std.testing.expect(base(div).rc_flags.foreign);
    try std.testing.expectEqual(doc_total - 3, base(f.document).subtree_holds);
    try std.testing.expectEqual(foreign + 3, counts(f.document).foreign_holds);
    try refcount.verifyTree(base(f.document));
    try refcount.verifyTree(base(div));
}

test "a fragment's children move out of it: the fragment keeps only itself" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const fragment = try interfaces.Document.call_createDocumentFragment(f.document);
    defer dom.node_creation.destroyUninserted(fragment);
    _ = try interfaces.Node.call_appendChild(fragment, try Fixture.element(f.document, "p"));
    _ = try interfaces.Node.call_appendChild(fragment, try Fixture.smallTree(f.document));
    try std.testing.expectEqual(@as(u32, 5), base(fragment).subtree_holds);
    const doc_total = base(f.document).subtree_holds;
    const foreign = counts(f.document).foreign_holds;

    _ = try interfaces.Node.call_insertBefore(f.body, fragment, null);
    try std.testing.expectEqual(@as(u32, 1), base(fragment).subtree_holds);
    try std.testing.expectEqual(doc_total + 4, base(f.document).subtree_holds);
    try std.testing.expectEqual(foreign - 4, counts(f.document).foreign_holds);
    try refcount.verifyTree(base(f.document));
}

test "replaceChild moves both subtrees' holds" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const old = try Fixture.smallTree(f.document);
    _ = try interfaces.Node.call_appendChild(f.body, old);
    const replacement = try Fixture.element(f.document, "p");
    const doc_total = base(f.document).subtree_holds;

    _ = try interfaces.Node.call_replaceChild(f.body, replacement, old);
    defer dom.node_creation.destroyUninserted(old);
    try std.testing.expectEqual(doc_total - 3 + 1, base(f.document).subtree_holds);
    try std.testing.expect(!refcount.hasParentBit(base(old)));
    try std.testing.expect(refcount.hasParentBit(base(replacement)));
    try refcount.verifyTree(base(f.document));
}

test "moveBefore moves the holds between parents; the tree's total is unchanged" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = try Fixture.element(f.document, "section");
    const b = try Fixture.element(f.document, "section");
    _ = try interfaces.Node.call_appendChild(f.body, a);
    _ = try interfaces.Node.call_appendChild(f.body, b);
    const moved = try Fixture.smallTree(f.document);
    _ = try interfaces.Node.call_appendChild(a, moved);
    const doc_total = base(f.document).subtree_holds;
    try std.testing.expectEqual(@as(u32, 4), base(a).subtree_holds);

    try interfaces.ParentNode.call_moveBefore(b, moved, null);
    try std.testing.expectEqual(@as(u32, 1), base(a).subtree_holds);
    try std.testing.expectEqual(@as(u32, 4), base(b).subtree_holds);
    try std.testing.expectEqual(doc_total, base(f.document).subtree_holds);
    try std.testing.expect(refcount.hasParentBit(base(moved)));
    try refcount.verifyTree(base(f.document));
}

test "adoptNode moves a detached tree's references and foreign holds to the new document" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const div = try Fixture.smallTree(f.document);
    defer dom.node_creation.destroyUninserted(div);
    const from = counts(f.document).*;
    const to = counts(f.other).*;

    _ = try interfaces.Document.call_adoptNode(f.other, div);
    try std.testing.expectEqual(from.referencing_nodes - 3, counts(f.document).referencing_nodes);
    try std.testing.expectEqual(from.foreign_holds - 3, counts(f.document).foreign_holds);
    try std.testing.expectEqual(to.referencing_nodes + 3, counts(f.other).referencing_nodes);
    try std.testing.expectEqual(to.foreign_holds + 3, counts(f.other).foreign_holds);
}

test "appending a connected subtree to another document adopts it: its holds leave one tree and join the other" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const div = try Fixture.smallTree(f.document);
    _ = try interfaces.Node.call_appendChild(f.body, div);
    const other_html = try Fixture.element(f.other, "html");
    _ = try interfaces.Node.call_appendChild(f.other, other_html);
    const total = base(f.document).subtree_holds;
    const other_total = base(f.other).subtree_holds;
    const foreign = counts(f.document).foreign_holds;
    const other_foreign = counts(f.other).foreign_holds;

    _ = try interfaces.Node.call_appendChild(other_html, div);
    try std.testing.expectEqual(total - 3, base(f.document).subtree_holds);
    try std.testing.expectEqual(other_total + 3, base(f.other).subtree_holds);
    try std.testing.expectEqual(foreign, counts(f.document).foreign_holds);
    try std.testing.expectEqual(other_foreign, counts(f.other).foreign_holds);
    try refcount.verifyTree(base(f.document));
    try refcount.verifyTree(base(f.other));
}

test "a shadow root's holds count in its host's chain" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const host = try Fixture.element(f.document, "div");
    _ = try interfaces.Node.call_appendChild(f.body, host);
    const doc_total = base(f.document).subtree_holds;
    const foreign = counts(f.document).foreign_holds;

    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    f.shadow = shadow;
    try std.testing.expect(base(shadow).rc_flags.hosted);
    try std.testing.expect(!base(shadow).rc_flags.foreign);
    try std.testing.expectEqual(@as(u32, 2), base(host).subtree_holds);
    try std.testing.expectEqual(doc_total + 1, base(f.document).subtree_holds);
    try std.testing.expectEqual(foreign, counts(f.document).foreign_holds);

    _ = try interfaces.Node.call_appendChild(shadow, try Fixture.smallTree(f.document));
    try std.testing.expectEqual(doc_total + 4, base(f.document).subtree_holds);
    try refcount.verifyTree(base(f.document));

    // The host leaves the document; the shadow tree goes with it.
    _ = try interfaces.Node.call_removeChild(f.body, host);
    try std.testing.expectEqual(doc_total - 1, base(f.document).subtree_holds);
    try std.testing.expectEqual(foreign + 5, counts(f.document).foreign_holds);
    try refcount.verifyTree(base(host));
    _ = try interfaces.Node.call_appendChild(f.body, host);
}

test "a template's contents count in the template's chain, and name the inert document" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const template = try Fixture.element(f.document, "template");
    _ = try interfaces.Node.call_appendChild(f.body, template);
    const content = try interfaces.HTMLTemplateElement.get_content(template);
    try std.testing.expect(base(content).rc_flags.hosted);
    try std.testing.expectEqual(@as(u32, 2), base(template).subtree_holds);
    const inert = (try interfaces.Node.get_ownerDocument(content)).?;
    try std.testing.expect(inert != f.document);
    const inert_counts = counts(inert).*;
    const doc_total = base(f.document).subtree_holds;

    const inside = try Fixture.element(inert, "p");
    _ = try interfaces.Node.call_appendChild(content, inside);
    try std.testing.expectEqual(doc_total + 1, base(f.document).subtree_holds);
    try std.testing.expectEqual(inert_counts.referencing_nodes + 1, counts(inert).referencing_nodes);
    // The paragraph left the inert document's detached roots.
    try std.testing.expectEqual(inert_counts.foreign_holds, counts(inert).foreign_holds);
    try refcount.verifyTree(base(f.document));
}

test "verifyTree catches a count a mutation forgot" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const div = try Fixture.smallTree(f.document);
    _ = try interfaces.Node.call_appendChild(f.body, div);
    try refcount.verifyTree(base(f.document));
    base(div).subtree_holds += 1;
    try std.testing.expectError(error.SubtreeHoldsMismatch, refcount.verifyTree(base(f.document)));
    base(div).subtree_holds -= 1;
    refcount.setParentBit(base(div), false);
    try std.testing.expectError(error.ParentBitMismatch, refcount.verifyTree(base(f.document)));
    refcount.setParentBit(base(div), true);
}
