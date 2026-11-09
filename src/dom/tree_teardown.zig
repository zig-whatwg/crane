//! Freeing a tree's descendants leaves first: a bounded number at a time for
//! a detached tree (`freeDescendants`), or all of them for a node's own
//! teardown (`freeAllDescendants`, Node.deinit) - in constant stack either
//! way, whatever the tree's depth.
//!
//! A tree nothing owns any more - its root's total of held nodes is zero, so
//! no node of it has a wrapper (a wrapper holds its node: refcount step 7) -
//! is freed by its root's teardown, which walks the whole subtree. For a tree of
//! thousands of nodes that is one long pause wherever it runs. The agent's
//! deferred teardown queue (runtime.gc.DeferredTeardown) frees such a tree in
//! slices instead: `freeDescendants` frees at most a budget of the root's
//! descendants, leaves first, and the caller frees the root itself through its
//! own teardown once it has no children left.
//!
//! Each node goes the way the tree's teardown would free it: unlinked from its
//! parent (a garbage tree no script can reach - no removing steps, no mutation
//! records), then through Node's destruction hook (dom.node_creation, the
//! teardown a tree runs for each child, `Node.deinitNodeByType`). A node freed
//! with no children is freed alone, so the slice never recurses. Nodes leave
//! from the end of each child list - an O(1) pop - post-order: a parent goes
//! only after its last child. What a node owns outside its child list - a
//! host's shadow tree, a template's contents - goes with that node's own
//! teardown, in one go.
//!
//! Blink sweeps a dead Oilpan heap incrementally; WebKit's
//! `ContainerNode::removeDetachedChildren` unlinks children before they are
//! deref'd, which is the order this keeps.
//!
//! Engine-neutral: the queue's steps (the engine adapter's today, a
//! reference-counted DOM's later) decide whether the tree may still be freed,
//! and call this to free it.

const std = @import("std");
const runtime = @import("runtime");
const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");
const node_creation = @import("node_creation.zig");
const refcount = @import("refcount.zig");

const SlabAllocator = runtime.SlabAllocator;

/// The agent's queue these trees wait in (runtime.gc.DeferredTeardown), for
/// the host code that owns it and reaches the runtime only through the DOM
/// (html.AgentHost).
pub const DeferredTeardown = runtime.gc.DeferredTeardown;

/// Where the last slice stopped: the node to descend from next (an ancestor
/// of everything freed so far, or the root), by slab generation.
pub const Position = DeferredTeardown.Position;

/// Free at most `budget` of `root`'s descendants, leaves first, never `root`
/// itself; `position` carries the place between calls (start it empty).
/// Returns how many were freed. `root` has no children left when
/// `root.first_child == null` afterwards.
pub fn freeDescendants(root: *NodeBase, position: *Position, budget: usize) usize {
    // Node's own teardown of a node that has no children now: its type's
    // deinit, its registries, its storage when no wrapper holds it - and the
    // end of its creator's reference, should it still have one (a collected
    // tree's nodes go the way an uninserted node goes:
    // dom.node_creation.destroyUninserted). (Node.deinit marks the node's
    // teardown begun, which every hold on it reads as gone - at the real
    // free, as it must.)
    const walk = freeLeavesFirst(root, resumePoint(root, position.*), budget, &node_creation.destroyUninserted);
    position.* = if (walk.at == root) .{} else positionOf(walk.at);
    return walk.freed;
}

/// Free EVERY descendant of `root`, leaves first, each through `free` - the
/// teardown a tree runs for a child (Node.deinitNodeByType) - and never
/// `root` itself, whose own teardown is the caller's. Returns how many were
/// freed.
///
/// A tree's teardown at any depth in constant stack: each node is unlinked
/// from its parent and freed only once it has no children left, so its own
/// teardown has no subtree to walk and never reaches this again for the same
/// tree. Node.deinit frees its subtree this way. It used to call each child's
/// teardown, which called its children's: one set of frames per tree level,
/// and a 10,000-deep tree overflowed the stack (lane crash1's sweep: a
/// SIGSEGV at the tree's teardown, the zero-crashes rule).
///
/// WebKit unlinks every child from its container - parent, siblings - before
/// the child's last reference goes (ContainerNodeAlgorithms.cpp
/// removeDetachedChildrenInContainer); its earlier deletion queue, which
/// Blink shared until Oilpan, never destroyed a node inside its parent's
/// destruction: "We have to tell all children that their parent has died",
/// and the children joined one queue, "Reuse the nextSibling pointer for this
/// purpose" (ContainerNodeAlgorithms.h addChildNodesToDeletionQueue, WebKit
/// 11c11fd3c856). Blink's Oilpan finalizes each node on its own, so no
/// destructor walks a subtree. Here the tree's links are the queue: the walk
/// descends to the last leaf, frees it, and climbs - no list, no allocation.
pub fn freeAllDescendants(root: *NodeBase, free: *const fn (*runtime.Instance) void) usize {
    return freeLeavesFirst(root, root, std.math.maxInt(usize), free).freed;
}

const Walk = struct {
    /// How many nodes left the tree.
    freed: usize,
    /// Where the walk stopped: an ancestor of everything freed, or `root`.
    at: *NodeBase,
};

/// The walk both teardowns share: from `start` (in `root`'s tree), free at
/// most `budget` of `root`'s descendants, leaves first, never `root`.
fn freeLeavesFirst(root: *NodeBase, start: *NodeBase, budget: usize, free: *const fn (*runtime.Instance) void) Walk {
    var at = start;
    var freed: usize = 0;
    while (freed < budget) {
        while (at.lastChild()) |child| at = child;
        if (at == root) break;
        const parent = at.parent_node orelse break;
        unlinkLastChild(parent, at);
        if (instance_bridge.getInstance(at)) |raw| free(@ptrCast(@alignCast(raw)));
        freed += 1;
        at = parent;
    }
    return .{ .freed = freed, .at = at };
}

/// How many nodes `root`'s tree holds, counting at most `cap` - an estimate
/// for the queue's memory bound, cheap next to freeing them.
pub fn countUpTo(root: *NodeBase, cap: usize) usize {
    var count: usize = 1;
    var at: *NodeBase = root;
    while (count < cap) {
        if (at.first_child) |child| {
            at = child;
        } else {
            while (at != root and at.next_sibling == null) at = at.parent_node orelse return count;
            if (at == root) return count;
            at = at.next_sibling.?;
        }
        count += 1;
    }
    return count;
}

/// Take `child`, `parent`'s last child, out of its sibling links (a node's
/// children: NodeBase.children).
fn unlinkLastChild(parent: *NodeBase, child: *NodeBase) void {
    parent.unlinkChild(child);
    // The pointer and the parent bit only: a dying tree's holds stay on its
    // root, which its own free takes out of its document (refcount.nodeFreed).
    refcount.unlinkForTeardown(child);
}

fn positionOf(node: *NodeBase) Position {
    const raw = instance_bridge.getInstance(node) orelse return .{};
    const instance: *runtime.Instance = @ptrCast(@alignCast(raw));
    return .{ .instance = instance, .generation = SlabAllocator.generationOf(instance) };
}

/// The node to resume from: the saved one while it is the same object and
/// still in `root`'s tree, else the root (script may have run since).
fn resumePoint(root: *NodeBase, position: Position) *NodeBase {
    const instance = position.instance orelse return root;
    if (SlabAllocator.generationOf(instance) != position.generation) return root;
    const node = instance_bridge.getNodeBase(instance) orelse return root;
    var up: ?*NodeBase = node;
    while (up) |n| : (up = n.parent_node) {
        if (n == root) return node;
    }
    return root;
}
