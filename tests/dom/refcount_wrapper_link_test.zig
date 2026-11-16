//! The wrapper link's count side (refcount design 2.1, step 4): a node's
//! wrapper owns one reference. `refcount.wrapperRef` / `wrapperDeref` are what
//! runtime.lifetime reaches (installed by `refcount.install`); they run in
//! production with no ledger yet, so - like the tree links - they keep the
//! count and `subtree_holds` and report a violation as an error log.
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

test "a wrapper's reference is one more on top of the born one: holds do not move" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const parent = try nodes.bare(.element);
    const child = try nodes.bare(.element);
    // Hand-linked: what step 3's insert leaves.
    child.setParent(parent);
    parent.subtree_holds += child.subtree_holds;

    refcount.wrapperRef(child);
    try testing.expectEqual(@as(u32, 2), refcount.count(child));
    try testing.expect(refcount.hasParentBit(child));
    try testing.expectEqual(@as(u32, 1), child.subtree_holds);
    try testing.expectEqual(@as(u32, 2), parent.subtree_holds);

    refcount.wrapperDeref(child);
    try testing.expectEqual(@as(u32, 1), refcount.count(child));
    try testing.expect(refcount.hasParentBit(child));
    try testing.expectEqual(@as(u32, 2), parent.subtree_holds);
    child.setParent(null);
}

test "a wrapper's reference on a node nothing else holds makes it a hold, and its release ends it" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const parent = try nodes.bare(.element);
    const child = try nodes.bare(.element);
    // A node whose born reference went (what step 5 will do): count 0.
    child.rc = 0;
    child.subtree_holds = 0;
    child.setParent(parent);

    refcount.wrapperRef(child);
    try testing.expectEqual(@as(u32, 1), refcount.count(child));
    try testing.expectEqual(@as(u32, 1), child.subtree_holds);
    try testing.expectEqual(@as(u32, 2), parent.subtree_holds);

    refcount.wrapperDeref(child);
    try testing.expectEqual(@as(u32, 0), refcount.count(child));
    try testing.expectEqual(@as(u32, 0), child.subtree_holds);
    try testing.expectEqual(@as(u32, 1), parent.subtree_holds);
    // Shadow mode: nothing is flagged or queued - frees are the collector's.
    try testing.expect(!child.rc_flags.garbage and !parent.rc_flags.garbage);
    child.setParent(null);
}
