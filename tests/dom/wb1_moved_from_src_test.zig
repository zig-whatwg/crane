//! Four tests that lived inside src/dom files and built a NodeBase by value
//! (lane wb1: the WithBase retirement, node-memory plan v2 X3). They are
//! here, on real nodes (real_nodes.zig), with the names they had - a src
//! module's own test executable links no engine and cannot make a node:
//!
//! - src/dom/mutation.zig "a callback registered twice runs once" (an
//!   owner-less DocumentFragment NodeBase on the stack);
//! - src/dom/refcount.zig "the parent bit and the count are independent"
//!   (an undefined NodeBase on the stack, its `rc` set by hand);
//! - src/dom/slot_helpers.zig "NodeRef equality compares instance and
//!   generation" (an undefined NodeBase and an undefined Instance, used as
//!   two addresses);
//! - src/dom/style/engine.zig "a detached parentless element has sibling
//!   index and count one" (an owner-less NodeBase from the test allocator).

const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const real_nodes = @import("real_nodes.zig");

const NodeBase = dom.NodeBase;
const refcount = dom.refcount;

test "the parent bit and the count are independent" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const node = try nodes.bare(.element);
    // A node is born with one reference and no parent.
    try testing.expectEqual(NodeBase.rc_one, node.rc);
    try testing.expectEqual(@as(u32, 1), refcount.count(node));
    try testing.expect(!refcount.hasParentBit(node));
    refcount.setParentBit(node, true);
    try testing.expectEqual(@as(u32, 1), refcount.count(node));
    try testing.expect(refcount.hasParentBit(node));
    refcount.setParentBit(node, false);
    try testing.expectEqual(NodeBase.rc_one, node.rc);
}

test "NodeRef equality compares instance and generation" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const a = try nodes.bare(.element);
    const b = try nodes.bare(.element);
    const r1 = dom.slot_helpers.NodeRef.to(a).?;
    // The same node at another generation of its slot: a different node.
    var r2 = r1;
    r2.generation += 1;
    try testing.expect(r1.eql(r1));
    try testing.expect(!r1.eql(r2));
    // Another node is another instance.
    try testing.expect(!r1.eql(dom.slot_helpers.NodeRef.to(b).?));
    // And the reference reads its node back while the slot is the one it took.
    try testing.expectEqual(@as(?*NodeBase, a), r1.get());
    try testing.expect(r2.get() == null);
}

test "a detached parentless element has sibling index and count one" {
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    const doc = try nodes.document();
    for ([_]*NodeBase{ try nodes.bare(.element), real_nodes.baseOf(try nodes.element(doc, "div")) }) |node| {
        const counts = dom.style.engine.treeCounts(@ptrCast(node));
        try testing.expectEqual(@as(usize, 1), counts.index);
        try testing.expectEqual(@as(usize, 1), counts.count);
    }
}

test "a callback registered twice runs once" {
    const Counter = struct {
        var calls: usize = 0;
        fn childrenChanged(_: *NodeBase, _: dom.mutation.ChildrenChange) void {
            calls += 1;
        }
    };
    Counter.calls = 0;
    var nodes: real_nodes.Nodes = undefined;
    try nodes.open(testing.allocator);
    defer nodes.close();
    // The process's registries as the start made them, restored after: the
    // test's callback never stays registered for the process's later tests.
    const registries = dom.mutation.overrideRegistriesForTest();
    defer registries.restore();

    try dom.mutation.registerChildrenChangedCallback(&Counter.childrenChanged);
    try dom.mutation.registerChildrenChangedCallback(&Counter.childrenChanged);
    const parent = try nodes.bare(.fragment);
    dom.mutation.runChildrenChangedSteps(parent, .inserted);
    try testing.expectEqual(@as(usize, 1), Counter.calls);
}
