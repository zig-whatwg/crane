//! Implementation for ParentNode mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-parentnode
//!
//! This impl contains the actual logic for ParentNode methods. The mixin file
//! delegates to these functions.
//!
//! The ParentNode mixin defines:
//! - children (HTMLCollection of child elements)
//! - firstElementChild
//! - lastElementChild
//! - childElementCount
//! - prepend(nodes...)
//! - append(nodes...)
//! - replaceChildren(nodes...)
//! - querySelector(selectors)
//! - querySelectorAll(selectors)

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");

const live_collections = @import("dom").live_collections;
const dom = @import("dom");
const NodeBase = dom.NodeBase;

// Node-tree reads go through Node's generated interface (AGENTS.md "The impls
// boundary"). Each getter forwards verbatim to Node's own (no brand check, no
// conversion, no reaction scope: interfaces/Node.zig), so these cost what the
// impl helpers they replace did; a node with no Node state reads as null.
fn firstChild(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_firstChild(node) catch null;
}
fn lastChild(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_lastChild(node) catch null;
}
fn nextSibling(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_nextSibling(node) catch null;
}
fn previousSibling(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_previousSibling(node) catch null;
}
fn parentNode(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_parentNode(node) catch null;
}
fn nodeType(node: *runtime.Instance) ?u16 {
    return interfaces.Node.get_nodeType(node) catch null;
}

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SyntaxError,
    OutOfMemory,
    HierarchyRequestError,
    NotFoundError,
};

/// Union type for nodes or strings (used in variadic node methods)
/// Spec: https://dom.spec.whatwg.org/#converting-nodes-into-a-node
pub const NodeOrString = union(enum) {
    node: *runtime.Instance,
    string: []const u8,
};

/// Internal state for ParentNode mixin
/// Per DOM spec, ParentNode mixin doesn't define any internal slots.
/// It operates on the node's existing children (from Node interface).
/// This struct exists for compatibility with the interface State pattern.
pub const InternalState = struct {};

// =============================================================================
// ParentNode Attribute Getters
// =============================================================================

/// Get the first child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-firstelementchild
pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var child = firstChild(instance);
    while (child) |c| {
        const node_type = nodeType(c) orelse 0;
        if (node_type == interfaces.Node.get_ELEMENT_NODE()) {
            return c;
        }
        child = nextSibling(c);
    }
    return null;
}

/// Get the last child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-lastelementchild
pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var last_element: ?*runtime.Instance = null;

    var child = firstChild(instance);
    while (child) |c| {
        const node_type = nodeType(c) orelse 0;
        if (node_type == interfaces.Node.get_ELEMENT_NODE()) {
            last_element = c;
        }
        child = nextSibling(c);
    }

    return last_element;
}

/// Get the number of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
    var count: u32 = 0;

    var child = firstChild(instance);
    while (child) |c| {
        const node_type = nodeType(c) orelse 0;
        if (node_type == interfaces.Node.get_ELEMENT_NODE()) {
            count += 1;
        }
        child = nextSibling(c);
    }

    return count;
}

/// Create an HTMLCollection of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-children
pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const allocator = instance.ctx.getAllocator();

    const collection = interfaces.HTMLCollection.init(
        allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);

    // DOM: "an HTMLCollection collection rooted at this matching only element
    // children" - live, so it answers for the tree as it is when read. The
    // filter is HTMLCollection's, reached through dom.live_collections.
    try live_collections.elementChildren(collection, instance);
    return collection;
}

// =============================================================================
// Selector Matching (querySelector, querySelectorAll)
// =============================================================================

/// querySelector(selectors): DOM "scope-match a selectors string" against
/// this, the first result or null. The matching is dom.selector_matching's,
/// shared with Element's matches() and closest().
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
    return dom.selector_matching.querySelector(instance, selectors.asSlice());
}

/// querySelectorAll(selectors): the static result of "scope-match a
/// selectors string" against this.
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!*runtime.Instance {
    const allocator = instance.ctx.getAllocator();
    // The matching elements, in tree order - collected first, then made the
    // static list's in one step, which holds them for as long as the list
    // lives (dom.node_lists.setStaticBasesWithin: every match descends from
    // this node, so their tree's root is found once).
    var collected: std.ArrayList(*NodeBase) = .empty;
    defer collected.deinit(allocator);
    const root_base = dom.instance_bridge.getNodeBase(@ptrCast(instance)) orelse return error.InvalidStateError;
    try dom.selector_matching.querySelectorAll(allocator, instance, selectors.asSlice(), &collected);

    const node_list = interfaces.NodeList.init(
        allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.NodeList.deinit(node_list);
    try dom.node_lists.setStaticBasesWithin(node_list, collected.items, root_base);

    return node_list;
}

// =============================================================================
// ParentNode Mutation Methods
// =============================================================================

/// prepend(...nodes)
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-prepend
pub fn call_prepend(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Step 1: "Let node be the result of converting nodes into a node given
    // nodes and this's node document."
    const node = try dom.mutation.convertNodesIntoNode(nodes, nodeDocument(instance));

    // Step 2: "Pre-insert node into this before this's first child."
    try dom.mutation.preInsertNode(node, instance, firstChild(instance));
}

/// append(...nodes)
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-append
pub fn call_append(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Step 1: "Let node be the result of converting nodes into a node given
    // nodes and this's node document."
    const node = try dom.mutation.convertNodesIntoNode(nodes, nodeDocument(instance));

    // Step 2: "Append node to this."
    try dom.mutation.appendNode(node, instance);
}

/// replaceChildren(...nodes)
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-replacechildren
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // Step 1: "Let node be the result of converting nodes into a node given
    // nodes and this's node document."
    const node = try dom.mutation.convertNodesIntoNode(nodes, nodeDocument(instance));

    // Step 2: ensure pre-insert validity, excluding this's current children.
    const parent_base = dom.instance_bridge.getNodeBase(instance) orelse return error.InvalidStateError;
    const node_base = dom.instance_bridge.getNodeBase(node) orelse return error.InvalidStateError;
    try dom.mutation.ensureReplaceChildrenValidity(node_base, parent_base);
    // Step 3: replace all with node within this.
    try dom.mutation.replaceAll(@as(?*NodeBase, node_base), parent_base);
}

/// moveBefore - Moves a node into this parent before child, preserving state
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
///
/// Deviation: step 3 is DOM "move", which keeps node's state; this removes
/// node and inserts it again, running the removing and insertion steps.
/// `mutation.move` in src/dom/ is a draft that has never compiled - it is
/// written against `interfaces.Node` and sibling pointers, not `NodeBase` -
/// so it cannot be called yet.
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
    // Step 1: Let referenceChild be child
    var reference_child = child;

    // Step 2: If referenceChild is node, set to node's next sibling
    if (reference_child == node) {
        reference_child = nextSibling(node);
    }

    // Validate: node must already be in a tree (have a parent)
    const old_parent = parentNode(node) orelse return error.HierarchyRequestError;

    // Validate: child (if non-null) must be a child of parent
    if (reference_child) |rc| {
        const rc_parent = parentNode(rc);
        if (rc_parent != instance) {
            return error.NotFoundError;
        }
    }

    // Validate: node cannot be an ancestor of parent
    var ancestor: ?*runtime.Instance = instance;
    while (ancestor) |anc| {
        if (anc == node) return error.HierarchyRequestError;
        ancestor = parentNode(anc);
    }

    // Check if already at correct position
    if (old_parent == instance) {
        if (reference_child) |rc| {
            const prev = previousSibling(rc);
            if (prev == node) return;
        } else {
            const last = lastChild(instance);
            if (last == node) return;
        }
    }

    // Remove from old position
    dom.mutation.removeNode(node) catch return error.HierarchyRequestError;

    // Insert at new position (use interface per Golden Rule #13)
    if (reference_child) |rc| {
        _ = interfaces.Node.call_insertBefore(instance, node, rc) catch return error.HierarchyRequestError;
    } else {
        _ = interfaces.Node.call_appendChild(instance, node) catch return error.HierarchyRequestError;
    }
}

/// This's node document: a document is its own.
fn nodeDocument(instance: *runtime.Instance) *runtime.Instance {
    return (interfaces.Node.get_ownerDocument(instance) catch null) orelse instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance's owned resources here (strings, arrays, etc.)
}

pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}
