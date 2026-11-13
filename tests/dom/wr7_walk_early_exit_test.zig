//! The wrapper redesign's decision 7 remedy, at P7 (tmp/redesign/
//! wrapper-redesign-design.md 4.4 "Cost per major GC" and section 9,
//! decision 7): the walk (dom.wrapper_tracing) runs in the collector's atomic
//! pause and tests each child of every node on a held path, so a flat body
//! of 50,000 children with one held child cost 50,000 child tests a major
//! collection - gc_bench `wide`, the one body whose pause failed decision
//! 7's gate (p95 1.79x P2's at P6). The remedy is exact, never a guess:
//! - the walk enters the child on the path to the node whose wrapper (or
//!   hold) brought it to the tree - known from that node's climb to its root
//!   - without scanning for it;
//! - a node's children are scanned only until the ones found hold all of the
//!   node's remaining holds (`subtree_holds` = its own hold + its hosted
//!   roots' + its children's, refcount's invariant).
//! Blink's marking reaches a parent's last child as directly as its first
//! (ContainerNode::Trace visits first_child_ and last_child_), and it never
//! visits nodes that are not on the way to a held one in a tree the walk
//! prunes - so the remedy only removes tests that cannot find a wrapper.
//!
//! `dom.wrapper_tracing.measureWalk` runs the walk with a counter in place of
//! the engine: how many nodes it visits and how many children it tests.
//! Trees are made natively, no engine: each node a test keeps holds one
//! reference, as a wrapper's would.
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

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        self.* = .{ .ctx = try runtime.ContextData.init(allocator, .{}), .document = undefined };
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
    }

    fn deinit(self: *Fixture) void {
        interfaces.Document.deinit(self.document);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    /// A new element: its creator's reference ends at its first insertion,
    /// so a child made here is held by nothing once inserted.
    fn element(self: *Fixture, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
    }

    /// A detached root kept by the test (its born reference claimed), with
    /// `count` unheld `p` children.
    fn flat(self: *Fixture, count: usize) !*runtime.Instance {
        const root = try self.element("div");
        _ = refcount.claimCreatorReference(base(root));
        for (0..count) |_| _ = try interfaces.Node.call_appendChild(root, try self.element("p"));
        return root;
    }
};

const children = 5000;

/// `root`'s child at `index`.
fn childAt(root: *runtime.Instance, index: usize) *NodeBase {
    var child = base(root).first_child.?;
    for (0..index) |_| child = child.next_sibling.?;
    return child;
}

test "wr7 decision 7: a flat tree with only its LAST child held - gc_bench wide - is walked with one child test, from that child's path" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const root = try f.flat(children);
    defer dom.node_creation.destroyUninserted(root);
    const last = childAt(root, children - 1);
    refcount.holderRef(last);
    defer refcount.holderDeref(last);
    const stats = dom.wrapper_tracing.measureWalk(base(root), last);
    std.debug.print("wr7 fact: last child held: visited {d}, tested {d} of {d} children\n", .{ stats.visited, stats.tested, children });
    // The root and the held child.
    try std.testing.expectEqual(@as(usize, 2), stats.visited);
    try std.testing.expect(stats.tested <= 1);
}

test "wr7 decision 7: a held child reached from another node's path is found by a scan that stops once every hold is found" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const root = try f.flat(children);
    defer dom.node_creation.destroyUninserted(root);
    const early = childAt(root, 99);
    refcount.holderRef(early);
    defer refcount.holderDeref(early);
    // No path into the tree (the walk came from its node document, say):
    // the scan stops at the 100th child, where the root's holds are all
    // found.
    const stats = dom.wrapper_tracing.measureWalk(base(root), null);
    std.debug.print("wr7 fact: child 100 held, no path: visited {d}, tested {d} of {d} children\n", .{ stats.visited, stats.tested, children });
    try std.testing.expectEqual(@as(usize, 2), stats.visited);
    try std.testing.expectEqual(@as(usize, 100), stats.tested);
}

test "wr7 decision 7: exact - every held node of a tree is visited whichever path the walk came by, and nothing unheld" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const root = try f.flat(64);
    defer dom.node_creation.destroyUninserted(root);
    // Held: children 3, 40 and 63, and a grandchild under child 10 (its
    // parent unheld, so only the subtree total leads there).
    const grandchild = try f.element("b");
    _ = try interfaces.Node.call_appendChild(@ptrCast(@alignCast(dom.instance_bridge.getInstance(childAt(root, 10)).?)), grandchild);
    const held = [_]*NodeBase{ childAt(root, 3), childAt(root, 40), childAt(root, 63), base(grandchild) };
    for (held) |node| refcount.holderRef(node);
    defer for (held) |node| refcount.holderDeref(node);
    // From each held node's path, and from none: the same nodes - the root
    // (the test keeps it: held too), the four held, and child 10 on the way
    // to the grandchild.
    for ([_]?*NodeBase{ null, held[0], held[1], held[2], held[3] }) |path_to| {
        const stats = dom.wrapper_tracing.measureWalk(base(root), path_to);
        try std.testing.expectEqual(@as(usize, 6), stats.visited);
        try std.testing.expectEqual(@as(usize, held.len + 1), stats.held);
    }
    // From child 63's path the root's scan still finds the other three and
    // stops at the last of them (child 40): 41 tests, not 64 - plus child
    // 10's one test of its child: 42 (the old walk: 65).
    const from_last = dom.wrapper_tracing.measureWalk(base(root), held[2]);
    try std.testing.expectEqual(@as(usize, 42), from_last.tested);
}
