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
const process_start = @import("process_start.zig");
const Hook = @import("hook.zig").Hook;

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

pub const NodeIteratorSteps = struct {
    set_up: NodeIteratorSetUp,
    pre_remove: *const fn (*runtime.Instance, *runtime.Instance) void,
};

// process-wide: immutable NodeIterator algorithms installed by installNodeIterator at process start, with no instance state
var node_iterator: Hook(?NodeIteratorSteps) = .init(null);
var tree_walker: Hook(?TreeWalkerSetUp) = .init(null);

/// Called by NodeIterator's installHooks, once, at process start (process_start.zig).
pub fn installNodeIterator(steps: NodeIteratorSteps) void {
    node_iterator.install(steps);
}

/// Called by TreeWalker's installHooks, once, at process start (process_start.zig).
pub fn installTreeWalker(set_up: TreeWalkerSetUp) void {
    tree_walker.install(set_up);
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
    const steps = node_iterator.get() orelse return error.NotSupported;
    return steps.set_up(iterator, root, what_to_show, filter, document);
}

/// DOM removal invokes the iterator owner's pre-removing steps.
pub fn preRemoveNodeIterator(iterator: *runtime.Instance, removed: *runtime.Instance) void {
    const steps = node_iterator.get() orelse return;
    steps.pre_remove(iterator, removed);
}

/// Set up a TreeWalker the caller has just created. The walker owns `filter`
/// from here on, and releases it when it is freed.
pub fn setUpTreeWalker(
    walker: *runtime.Instance,
    root: *runtime.Instance,
    what_to_show: u32,
    filter: ?*runtime.CallbackWrapper,
) !void {
    const set_up = tree_walker.get() orelse return error.NotSupported;
    return set_up(walker, root, what_to_show, filter);
}

test "set-up without an installed implementation reports NotSupported" {
    const std = @import("std");
    const iterator_override = node_iterator.overrideForTest(null);
    defer iterator_override.restore();
    const walker_override = tree_walker.overrideForTest(null);
    defer walker_override.restore();
    // Never dereferenced: with nothing installed the calls do not reach them.
    var object: runtime.Instance = undefined;
    try std.testing.expectError(error.NotSupported, setUpNodeIterator(&object, &object, 0, null, &object));
    try std.testing.expectError(error.NotSupported, setUpTreeWalker(&object, &object, 0, null));
}
