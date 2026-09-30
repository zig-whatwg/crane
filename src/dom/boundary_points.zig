//! DOM 5.2 "boundary point" position: whether one boundary point is before,
//! equal to, or after another in the same tree.
//!
//! Spec: https://dom.spec.whatwg.org/#concept-range-bp-position
//!
//! Generic over the tree it walks, so the algorithm is pinned here on a fake
//! tree and run on the DOM through the adapter its caller supplies (Range
//! reads parents and siblings through `interfaces.Node`). A `Tree` declares:
//!
//!   pub const Node: type             - compared with ==
//!   pub fn parent(Node) ?Node
//!   pub fn index(Node) u32           - the node's index among its siblings

const std = @import("std");

pub const Position = enum { before, equal, after };

/// The position of the boundary point (node_a, offset_a) relative to
/// (node_b, offset_b). The two nodes have the same root.
pub fn position(comptime Tree: type, node_a: Tree.Node, offset_a: u32, node_b: Tree.Node, offset_b: u32) Position {
    // Step 1: "Assert: nodeA and nodeB have the same root." The callers check.

    // Step 2: "If nodeA is nodeB, then return equal if offsetA is offsetB,
    // before if offsetA is less than offsetB, and after if offsetA is greater
    // than offsetB."
    if (node_a == node_b) {
        if (offset_a == offset_b) return .equal;
        return if (offset_a < offset_b) .before else .after;
    }

    // Step 3: "If nodeA is following nodeB, then if the position of (nodeB,
    // offsetB) relative to (nodeA, offsetA) is before, return after, and if
    // it is after, return before." The swapped call cannot recurse again:
    // nodeB precedes nodeA, so nodeB is not following nodeA.
    if (isFollowing(Tree, node_a, node_b)) {
        return switch (position(Tree, node_b, offset_b, node_a, offset_a)) {
            .before => .after,
            .after => .before,
            .equal => .equal,
        };
    }

    // Step 4: "If nodeA is an ancestor of nodeB:"
    if (isAncestor(Tree, node_a, node_b)) {
        // Step 4.1: "Let child be nodeB."
        var child = node_b;
        // Step 4.2: "While child is not a child of nodeA, set child to its
        // parent."
        while (Tree.parent(child)) |parent| {
            if (parent == node_a) break;
            child = parent;
        }
        // Step 4.3: "If child's index is less than offsetA, then return
        // after."
        if (Tree.index(child) < offset_a) return .after;
    }

    // Step 5: "Return before."
    return .before;
}

/// "An object A is an ancestor of an object B if and only if B is a
/// descendant of A" - strictly: a node is not its own ancestor.
pub fn isAncestor(comptime Tree: type, ancestor: Tree.Node, node: Tree.Node) bool {
    var current = Tree.parent(node);
    while (current) |c| : (current = Tree.parent(c)) {
        if (c == ancestor) return true;
    }
    return false;
}

/// "An object A is following an object B if A and B are in the same tree and
/// A comes after B in tree order" - preorder, depth-first. False for nodes in
/// different trees.
pub fn isFollowing(comptime Tree: type, a: Tree.Node, b: Tree.Node) bool {
    if (a == b) return false;

    // Bring both to the same depth; if they meet, one is the other's
    // ancestor, and a descendant follows its ancestors.
    const depth_a = depthOf(Tree, a);
    const depth_b = depthOf(Tree, b);
    var x = a;
    var y = b;
    var d = depth_a;
    while (d > depth_b) : (d -= 1) x = Tree.parent(x).?;
    d = depth_b;
    while (d > depth_a) : (d -= 1) y = Tree.parent(y).?;
    if (x == y) return depth_a > depth_b;

    // Climb in step to the children of the common ancestor; their indices
    // order the two subtrees.
    while (true) {
        const px = Tree.parent(x);
        const py = Tree.parent(y);
        if (px == py) {
            // No common ancestor: different trees.
            if (px == null) return false;
            return Tree.index(x) > Tree.index(y);
        }
        x = px.?;
        y = py.?;
    }
}

fn depthOf(comptime Tree: type, node: Tree.Node) usize {
    var depth: usize = 0;
    var current = Tree.parent(node);
    while (current) |c| : (current = Tree.parent(c)) depth += 1;
    return depth;
}

// ============================================================================
// Tests
// ============================================================================

const Fake = struct {
    const N = struct { parent: ?*N = null, index: u32 = 0 };
    pub const Node = *N;
    pub fn parent(n: Node) ?Node {
        return n.parent;
    }
    pub fn index(n: Node) u32 {
        return n.index;
    }
};

/// root
/// |- a          (index 0)
/// |  |- a0      (index 0)
/// |  `- a1      (index 1)
/// `- b          (index 1)
const Sample = struct {
    root: Fake.N = .{},
    a: Fake.N = .{ .index = 0 },
    a0: Fake.N = .{ .index = 0 },
    a1: Fake.N = .{ .index = 1 },
    b: Fake.N = .{ .index = 1 },

    fn link(t: *Sample) void {
        t.a.parent = &t.root;
        t.b.parent = &t.root;
        t.a0.parent = &t.a;
        t.a1.parent = &t.a;
    }
};

fn pos(a: *Fake.N, oa: u32, b: *Fake.N, ob: u32) Position {
    return position(Fake, a, oa, b, ob);
}

test "boundary point position: the same node compares offsets" {
    var t: Sample = .{};
    t.link();
    try std.testing.expectEqual(Position.before, pos(&t.a0, 0, &t.a0, 1));
    try std.testing.expectEqual(Position.equal, pos(&t.a0, 2, &t.a0, 2));
    try std.testing.expectEqual(Position.after, pos(&t.a0, 3, &t.a0, 1));
}

test "boundary point position: A following B, neither an ancestor of the other" {
    var t: Sample = .{};
    t.link();
    // b comes after a0 in tree order, whatever the offsets.
    try std.testing.expectEqual(Position.after, pos(&t.b, 0, &t.a0, 5));
    try std.testing.expectEqual(Position.before, pos(&t.a0, 5, &t.b, 0));
    // Siblings: a1 follows a0.
    try std.testing.expectEqual(Position.after, pos(&t.a1, 0, &t.a0, 9));
    try std.testing.expectEqual(Position.before, pos(&t.a0, 9, &t.a1, 0));
}

test "boundary point position: A an ancestor of B" {
    var t: Sample = .{};
    t.link();
    // (root, 1) is between a and b: after anything inside a.
    try std.testing.expectEqual(Position.after, pos(&t.root, 1, &t.a0, 0));
    // (root, 0) is before a: before anything inside it.
    try std.testing.expectEqual(Position.before, pos(&t.root, 0, &t.a0, 0));
    // (a, 1) is between a0 and a1: after a0's contents, before a1's.
    try std.testing.expectEqual(Position.after, pos(&t.a, 1, &t.a0, 4));
    try std.testing.expectEqual(Position.before, pos(&t.a, 1, &t.a1, 0));
}

test "boundary point position: B an ancestor of A" {
    var t: Sample = .{};
    t.link();
    try std.testing.expectEqual(Position.before, pos(&t.a0, 0, &t.root, 1));
    try std.testing.expectEqual(Position.after, pos(&t.a0, 0, &t.root, 0));
    try std.testing.expectEqual(Position.before, pos(&t.a0, 4, &t.a, 1));
    try std.testing.expectEqual(Position.after, pos(&t.a1, 0, &t.a, 1));
}

test "following: tree order, and nothing across trees" {
    var t: Sample = .{};
    t.link();
    var other: Fake.N = .{};
    try std.testing.expect(isFollowing(Fake, &t.a0, &t.root));
    try std.testing.expect(!isFollowing(Fake, &t.root, &t.a0));
    try std.testing.expect(isFollowing(Fake, &t.b, &t.a1));
    try std.testing.expect(!isFollowing(Fake, &t.a1, &t.b));
    try std.testing.expect(!isFollowing(Fake, &t.a, &t.a));
    try std.testing.expect(!isFollowing(Fake, &other, &t.a));
    try std.testing.expect(!isFollowing(Fake, &t.a, &other));
}
