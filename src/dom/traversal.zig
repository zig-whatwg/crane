//! DOM § 6 traversal objects, as the seam Document creates them through.
//!
//! `createNodeIterator()` and `createTreeWalker()` are Document's methods, but
//! the root, whatToShow and filter they set are the NodeIterator's and the
//! TreeWalker's own state, which Document may not reach into. Each traverser
//! impl installs its set-up step when it creates an object - necessarily before
//! Document can hold one to set up - and Document calls it here. The same shape
//! as `abort_algorithms.zig`.
//!
//! lint-impls: hook for NodeIterator, TreeWalker

const runtime = @import("runtime");

/// What the NodeIterator impl supplies: steps 2-5 of createNodeIterator() -
/// root and reference set to root, pointer before reference true, whatToShow
/// and filter - plus the document whose iterator list it is joining.
pub const NodeIteratorSetUp = *const fn (
    iterator: *runtime.Instance,
    root: *runtime.Instance,
    what_to_show: u32,
    filter: ?*runtime.CallbackWrapper,
    document: *runtime.Instance,
) anyerror!void;

/// What the TreeWalker impl supplies: steps 2-4 of createTreeWalker() -
/// root and current node set to root, whatToShow and filter.
pub const TreeWalkerSetUp = *const fn (
    walker: *runtime.Instance,
    root: *runtime.Instance,
    what_to_show: u32,
    filter: ?*runtime.CallbackWrapper,
) anyerror!void;

/// Per thread, like the objects themselves.
threadlocal var node_iterator: ?NodeIteratorSetUp = null;
threadlocal var tree_walker: ?TreeWalkerSetUp = null;

/// Called by the NodeIterator impl. Idempotent.
pub fn installNodeIterator(set_up: NodeIteratorSetUp) void {
    node_iterator = set_up;
}

/// Called by the TreeWalker impl. Idempotent.
pub fn installTreeWalker(set_up: TreeWalkerSetUp) void {
    tree_walker = set_up;
}

/// Set up a NodeIterator the caller has just created. The iterator owns
/// `filter` from here on, and releases it when it is freed.
pub fn setUpNodeIterator(
    iterator: *runtime.Instance,
    root: *runtime.Instance,
    what_to_show: u32,
    filter: ?*runtime.CallbackWrapper,
    document: *runtime.Instance,
) !void {
    const set_up = node_iterator orelse return error.NotSupported;
    return set_up(iterator, root, what_to_show, filter, document);
}

/// Set up a TreeWalker the caller has just created. The walker owns `filter`
/// from here on, and releases it when it is freed.
pub fn setUpTreeWalker(
    walker: *runtime.Instance,
    root: *runtime.Instance,
    what_to_show: u32,
    filter: ?*runtime.CallbackWrapper,
) !void {
    const set_up = tree_walker orelse return error.NotSupported;
    return set_up(walker, root, what_to_show, filter);
}

test "set-up without an installed implementation reports NotSupported" {
    const std = @import("std");
    const saved_iterator = node_iterator;
    const saved_walker = tree_walker;
    defer node_iterator = saved_iterator;
    defer tree_walker = saved_walker;
    node_iterator = null;
    tree_walker = null;
    // Never dereferenced: with nothing installed the calls do not reach them.
    var object: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, setUpNodeIterator(&object, &object, 0, null, &object));
    try std.testing.expectError(error.NotSupported, setUpTreeWalker(&object, &object, 0, null));
}
