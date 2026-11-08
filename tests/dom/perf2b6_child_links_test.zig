//! A node's children with no `last_child` (lane perf2 batch 6): the first
//! child's previous link holds its parent's last child, as Gecko's
//! nsIContent::mPreviousOrLastSibling does (nsINode::GetLastChild reads
//! mFirstChild->mPreviousOrLastSibling; GetPreviousSibling answers null when
//! the link's target has no next sibling). NodeBase.linkChildBefore and
//! unlinkChild keep it; previousSibling() and lastChild() read it.
//!
//! A seeded sequence of inserts (at the front, the back and the middle) and
//! removals (first, last, middle, only child) is checked after every step
//! against a plain array of the same children: first, last, every previous
//! and next link, the count, index() and the reverse walk.

const std = @import("std");
const dom = @import("dom");
const testing = std.testing;
const NodeBase = dom.NodeBase;

const max_children = 24;

fn node(node_type: u16) NodeBase {
    return .{ .owner = NodeBase.ownerless(&std.testing.allocator), .node_type = node_type };
}

fn expectLinks(parent: *NodeBase, model: []const *NodeBase) !void {
    try testing.expectEqual(model.len, parent.childCount());
    if (model.len == 0) {
        try testing.expect(parent.first_child == null);
        try testing.expect(parent.lastChild() == null);
        return;
    }
    try testing.expectEqual(model[0], parent.first_child.?);
    try testing.expectEqual(model[model.len - 1], parent.lastChild().?);
    for (model, 0..) |child, i| {
        try testing.expectEqual(i, child.index());
        try testing.expectEqual(if (i == 0) null else model[i - 1], child.previousSibling());
        try testing.expectEqual(if (i + 1 == model.len) null else model[i + 1], child.next_sibling);
        try testing.expectEqual(child, parent.childAt(i).?);
    }
    var reversed = parent.childrenReversed();
    var at = model.len;
    while (reversed.next()) |child| {
        at -= 1;
        try testing.expectEqual(model[at], child);
    }
    try testing.expectEqual(@as(usize, 0), at);
}

test "the first child's previous link is the last child: inserts and removals at every position keep every link" {
    var parent = node(NodeBase.ELEMENT_NODE);
    var pool: [max_children]NodeBase = undefined;
    for (&pool) |*n| n.* = node(NodeBase.TEXT_NODE);
    var model_buf: [max_children]*NodeBase = undefined;
    var model: std.ArrayListUnmanaged(*NodeBase) = .initBuffer(&model_buf);
    var free_buf: [max_children]*NodeBase = undefined;
    var free: std.ArrayListUnmanaged(*NodeBase) = .initBuffer(&free_buf);
    for (&pool) |*n| free.appendAssumeCapacity(n);

    var prng = std.Random.DefaultPrng.init(0x7065_7266_3262_3600);
    const random = prng.random();
    for (0..2_000) |_| {
        const insert = model.items.len == 0 or (free.items.len != 0 and random.boolean());
        if (insert) {
            const child = free.pop().?;
            const at = random.uintAtMost(usize, model.items.len);
            const before: ?*NodeBase = if (at == model.items.len) null else model.items[at];
            child.parent_node = &parent;
            parent.linkChildBefore(child, before);
            model.insertAssumeCapacity(at, child);
        } else {
            const at = random.uintLessThan(usize, model.items.len);
            const child = model.orderedRemove(at);
            parent.unlinkChild(child);
            child.parent_node = null;
            try testing.expect(child.previous_or_last == null and child.next_sibling == null);
            try testing.expect(child.previousSibling() == null);
            free.appendAssumeCapacity(child);
        }
        try expectLinks(&parent, model.items);
    }
}

test "an only child is its own last child, and its previous sibling is null" {
    var parent = node(NodeBase.ELEMENT_NODE);
    var only = node(NodeBase.TEXT_NODE);
    only.parent_node = &parent;
    parent.linkChildBefore(&only, null);
    try testing.expectEqual(&only, parent.lastChild().?);
    try testing.expectEqual(&only, only.previous_or_last.?);
    try testing.expect(only.previousSibling() == null);
    try expectLinks(&parent, &.{&only});
    parent.unlinkChild(&only);
    try expectLinks(&parent, &.{});
}
