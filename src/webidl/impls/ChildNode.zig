//! Implementation for ChildNode mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-childnode
//!
//! CharacterData, DocumentType and Element include ChildNode and inherit these
//! members by alias. Every includer is a Node: its tree is read through Node's
//! interface, and changed by DOM's mutation algorithms (src/dom/mutation.zig),
//! never by Node's [CEReactions] members (see "The mutation algorithms on
//! platform objects" there).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const mixins = @import("mixins");
const mutation = @import("dom").mutation;

pub const State = interfaces.ChildNode.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    HierarchyRequestError,
    OutOfMemory,
};

const NodeOrString = mixins.ParentNode.NodeOrString;

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

// =============================================================================
// ChildNode Methods
// =============================================================================

/// before(...nodes)
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-before
pub fn call_before(instance: *runtime.Instance, nodes: []const NodeOrString) anyerror!void {
    // Steps 1-2: "Let parent be this's parent. If parent is null, then return."
    const parent = (interfaces.Node.get_parentNode(instance) catch null) orelse return;

    // Step 3: "Let viablePreviousSibling be this's first preceding sibling not
    // in nodes; otherwise null."
    var viable_previous_sibling = interfaces.Node.get_previousSibling(instance) catch null;
    while (viable_previous_sibling) |sibling| : (viable_previous_sibling = interfaces.Node.get_previousSibling(sibling) catch null) {
        if (!inNodes(nodes, sibling)) break;
    }

    // Step 4: "Let node be the result of converting nodes into a node, given
    // nodes and this's node document."
    const node = try mutation.convertNodesIntoNode(nodes, try nodeDocument(instance));

    // Step 5: "If viablePreviousSibling is null, then set it to parent's first
    // child; otherwise to viablePreviousSibling's next sibling." Read after
    // step 4, which may have moved nodes out of this position.
    const reference = if (viable_previous_sibling) |sibling| (interfaces.Node.get_nextSibling(sibling) catch null) else (interfaces.Node.get_firstChild(parent) catch null);

    // Step 6: "Pre-insert node into parent before viablePreviousSibling."
    try mutation.preInsertNode(node, parent, reference);
}

/// after(...nodes)
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-after
pub fn call_after(instance: *runtime.Instance, nodes: []const NodeOrString) anyerror!void {
    // Steps 1-2: "Let parent be this's parent. If parent is null, then return."
    const parent = (interfaces.Node.get_parentNode(instance) catch null) orelse return;

    // Step 3: "Let viableNextSibling be this's first following sibling not in
    // nodes; otherwise null."
    const viable_next_sibling = firstFollowingSiblingNotIn(instance, nodes);

    // Step 4: "Let node be the result of converting nodes into a node, given
    // nodes and this's node document."
    const node = try mutation.convertNodesIntoNode(nodes, try nodeDocument(instance));

    // Step 5: "Pre-insert node into parent before viableNextSibling."
    try mutation.preInsertNode(node, parent, viable_next_sibling);
}

/// replaceWith(...nodes)
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-replacewith
pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const NodeOrString) anyerror!void {
    // Steps 1-2: "Let parent be this's parent. If parent is null, then return."
    const parent = (interfaces.Node.get_parentNode(instance) catch null) orelse return;

    // Step 3: "Let viableNextSibling be this's first following sibling not in
    // nodes; otherwise null."
    const viable_next_sibling = firstFollowingSiblingNotIn(instance, nodes);

    // Step 4: "Let node be the result of converting nodes into a node, given
    // nodes and this's node document."
    const node = try mutation.convertNodesIntoNode(nodes, try nodeDocument(instance));

    if ((interfaces.Node.get_parentNode(instance) catch null) == parent) {
        // Step 5: "If this's parent is parent, replace this with node within
        // parent." (This could have been inserted into node.)
        try mutation.replaceNode(instance, node, parent);
    } else {
        // Step 6: "Otherwise, pre-insert node into parent before
        // viableNextSibling."
        try mutation.preInsertNode(node, parent, viable_next_sibling);
    }
}

/// remove()
/// Spec: https://dom.spec.whatwg.org/#dom-childnode-remove
pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    // Step 1: "If this's parent is null, then return."
    if ((interfaces.Node.get_parentNode(instance) catch null) == null) return;

    // Step 2: "Remove this."
    try mutation.removeNode(instance);
}

// =============================================================================
// Helpers
// =============================================================================

/// This's node document: every includer is a non-document node, so it is the
/// owner document.
fn nodeDocument(instance: *runtime.Instance) !*runtime.Instance {
    return (interfaces.Node.get_ownerDocument(instance) catch null) orelse error.InvalidStateError;
}

/// Whether `candidate` is one of the nodes (not strings) in `nodes`.
fn inNodes(nodes: []const NodeOrString, candidate: *runtime.Instance) bool {
    for (nodes) |item| switch (item) {
        .node => |node| if (node == candidate) return true,
        .string => {},
    };
    return false;
}

/// This's first following sibling not in `nodes`, or null.
fn firstFollowingSiblingNotIn(instance: *runtime.Instance, nodes: []const NodeOrString) ?*runtime.Instance {
    var sibling = interfaces.Node.get_nextSibling(instance) catch null;
    while (sibling) |s| : (sibling = interfaces.Node.get_nextSibling(s) catch null) {
        if (!inNodes(nodes, s)) return s;
    }
    return null;
}
