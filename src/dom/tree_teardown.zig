//! Freeing a detached tree a bounded number of nodes at a time.
//!
//! A tree nothing owns any more - its root's wrapper was collected, and no
//! node of it has a wrapper (wrappers in a tree are upward-closed and linked
//! both ways, so one live wrapper anywhere would have kept the root) - is
//! freed by its root's teardown, which walks the whole subtree. For a tree of
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
    var at = resumePoint(root, position.*);
    var freed: usize = 0;
    while (freed < budget) {
        while (at.last_child) |child| at = child;
        if (at == root) break;
        const parent = at.parent_node orelse break;
        unlinkLastChild(parent, at);
        // Node's own teardown of a node that has no children now: its type's
        // deinit, its registries, its storage when no wrapper holds it.
        // (Lane nodeholds' node_holds.nodeReleased runs inside it, in
        // Node.deinit - at the real free, as it must.)
        if (instance_bridge.getInstance(at)) |raw| node_creation.destroyUninserted(@ptrCast(@alignCast(raw)));
        freed += 1;
        at = parent;
    }
    position.* = if (at == root) .{} else positionOf(at);
    return freed;
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

/// Take `child`, `parent`'s last child, out of its child list and sibling
/// links.
fn unlinkLastChild(parent: *NodeBase, child: *NodeBase) void {
    const prev = child.previous_sibling;
    if (prev) |p| p.next_sibling = null else parent.first_child = null;
    parent.last_child = prev;
    child.previous_sibling = null;
    child.next_sibling = null;
    child.parent_node = null;
    const size = parent.child_nodes.size();
    if (size > 0 and parent.child_nodes.items()[size - 1] == child) {
        _ = parent.child_nodes.remove(size - 1) catch {};
        return;
    }
    // The list and the links disagree (never expected): find it.
    for (parent.child_nodes.items(), 0..) |item, i| {
        if (item != child) continue;
        _ = parent.child_nodes.remove(i) catch {};
        return;
    }
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
