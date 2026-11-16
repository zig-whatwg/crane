//! A holder's counted reference (refcount design section 7, step 5): a
//! MutationRecord, a static NodeList, a live collection takes one reference on
//! each node it holds, for as long as it holds it. Production has no ledger
//! yet (none is wired to the agent before step 7), so `refcount.holderRef` /
//! `holderDeref` are `ref`/`deref` without one, as the wrapper's are: they keep
//! the count and `subtree_holds` and report a violation as an error log.
//! SHADOW MODE: nothing is flagged or queued; frees are still the collector's.
//!
//! Real nodes with no node document (real_nodes.zig `bare`; lane wb1), linked
//! with step 3's own functions; no engine. They were NodeBase values made by
//! the test's allocator.

const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const real_nodes = @import("real_nodes.zig");
const refcount = dom.refcount;
const NodeBase = dom.NodeBase;

test "a holder's reference on a node already held adds to its count and moves no holds" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const parent = try nodes.bare(.element);
    const child = try nodes.bare(.element);
    child.setParent(parent);
    parent.subtree_holds += child.subtree_holds;

    refcount.holderRef(child);
    refcount.holderRef(child);
    try testing.expectEqual(@as(u32, 3), refcount.count(child));
    try testing.expectEqual(@as(u32, 1), child.subtree_holds);
    try testing.expectEqual(@as(u32, 2), parent.subtree_holds);

    refcount.holderDeref(child);
    refcount.holderDeref(child);
    try testing.expectEqual(@as(u32, 1), refcount.count(child));
    try testing.expect(refcount.hasParentBit(child));
    try testing.expectEqual(@as(u32, 2), parent.subtree_holds);
    child.setParent(null);
}

test "a holder's reference on a node nothing else holds makes it a hold, and its release ends it" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const parent = try nodes.bare(.element);
    const child = try nodes.bare(.element);
    // A node whose born reference went (what step 7 will do): count 0.
    child.rc = 0;
    child.subtree_holds = 0;
    child.setParent(parent);

    refcount.holderRef(child);
    try testing.expectEqual(@as(u32, 1), refcount.count(child));
    try testing.expectEqual(@as(u32, 1), child.subtree_holds);
    try testing.expectEqual(@as(u32, 2), parent.subtree_holds);

    refcount.holderDeref(child);
    try testing.expectEqual(@as(u32, 0), refcount.count(child));
    try testing.expectEqual(@as(u32, 0), child.subtree_holds);
    try testing.expectEqual(@as(u32, 1), parent.subtree_holds);
    // Shadow mode: nothing is flagged or queued - frees are the collector's.
    try testing.expect(!child.rc_flags.garbage and !parent.rc_flags.garbage);
    child.setParent(null);
}

test "a holder's and a wrapper's references are one count" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const node = try nodes.bare(.element);
    refcount.wrapperRef(node);
    refcount.holderRef(node);
    try testing.expectEqual(@as(u32, 3), refcount.count(node));
    refcount.wrapperDeref(node);
    try testing.expectEqual(@as(u32, 2), refcount.count(node));
    refcount.holderDeref(node);
    try testing.expectEqual(@as(u32, 1), refcount.count(node));
    try testing.expectEqual(@as(u32, 1), node.subtree_holds);
}
