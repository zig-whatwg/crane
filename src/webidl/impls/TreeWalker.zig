//! Implementation for TreeWalker interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-treewalker
//! WHATWG DOM Standard §6.3
//!
//! TreeWalker objects can be used to filter and traverse node trees.
//! Unlike NodeIterator, TreeWalker provides rich navigation methods
//! (parentNode, firstChild, lastChild, previousSibling, nextSibling)
//! and maintains a mutable currentNode pointer.
//!
//! Migrated from: webidl/src/dom/TreeWalker.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const TreeWalker = interfaces.TreeWalker;

// Re-use NodeFilter constants from NodeIterator
const NodeIteratorImpl = @import("NodeIterator.zig");
const NodeFilter = NodeIteratorImpl.NodeFilter;

// Import NodeImpl for tree navigation helpers
const NodeImpl = @import("Node.zig");

pub const State = TreeWalker.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Child traversal type
pub const ChildType = enum { first, last };

/// Sibling traversal type
pub const SiblingType = enum { next, previous };

/// Internal state for TreeWalker
/// Spec: https://dom.spec.whatwg.org/#concept-treewalker-state
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The root node of the walker (never changes)
    root: ?*runtime.Instance,

    /// The current node (mutable, can be changed by navigation or setter)
    current: ?*runtime.Instance,

    /// Bitmask indicating which node types to show
    what_to_show: u32,

    /// Optional filter callback
    /// TODO: Proper WebIDL callback support - for now store as opaque pointer
    filter: ?*anyopaque,

    /// Active flag to prevent recursive invocations
    active_flag: bool,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .root = null,
            .current = null,
            .what_to_show = NodeFilter.SHOW_ALL,
            .filter = null,
            .active_flag = false,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // No cleanup needed - we don't own the nodes
        _ = self;
    }
};

/// Helper to access internal state from instance
fn getInternal(instance: *runtime.Instance) *InternalState {
    const state = instance.getState(State);
    return @ptrCast(@alignCast(state.own._internal));
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
}

/// Create a TreeWalker with the given parameters
/// This is called by Document.createTreeWalker()
pub fn createTreeWalker(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    root: *runtime.Instance,
    what_to_show: u32,
    filter: ?*anyopaque,
) !*runtime.Instance {
    const instance = try init(allocator, State, &interfaces.TreeWalker.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance);
    internal.root = root;
    internal.current = root; // Start at root per spec
    internal.what_to_show = what_to_show;
    internal.filter = filter;

    return instance;
}

// ============================================================================
// Getters
// ============================================================================

/// DOM §6.3 - TreeWalker.root
/// Returns the root node
pub fn get_root(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.root orelse return error.NotImplemented;
}

/// DOM §6.3 - TreeWalker.whatToShow
/// Returns the whatToShow bitmask
pub fn get_whatToShow(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance);
    return internal.what_to_show;
}

/// DOM §6.3 - TreeWalker.filter
/// Returns the filter callback (may be null)
pub fn get_filter(instance: *runtime.Instance) anyerror!??*runtime.CallbackWrapper {
    const internal = getInternal(instance);
    // TODO: Return proper NodeFilter interface
    _ = internal;
    return null;
}

/// DOM §6.3 - TreeWalker.currentNode getter
/// Returns the current node
pub fn get_currentNode(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.current orelse return error.NotImplemented;
}

/// DOM §6.3 - TreeWalker.currentNode setter
/// Sets the current node to the given value
pub fn set_currentNode(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance);
    internal.current = value;
}

// ============================================================================
// Navigation methods
// ============================================================================

/// DOM §6.3 - TreeWalker.parentNode()
/// Move to parent node if it passes filter, return null otherwise
pub fn call_parentNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);

    // Step 1: Let node be this's current
    var node = internal.current orelse return null;

    // Step 2: While node is non-null and is not this's root
    while (internal.root == null or node != internal.root.?) {
        // Step 2.1: Set node to node's parent
        const parent = getParentNode(node) orelse break;
        node = parent;

        // Step 2.2: If node is non-null and filtering node returns FILTER_ACCEPT
        const result = try filterNode(instance, node);
        if (result == NodeFilter.FILTER_ACCEPT) {
            internal.current = node;
            return node;
        }
    }

    // Step 3: Return null
    return null;
}

/// DOM §6.3 - TreeWalker.firstChild()
/// Move to first child that passes filter
pub fn call_firstChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try traverseChildren(instance, .first);
}

/// DOM §6.3 - TreeWalker.lastChild()
/// Move to last child that passes filter
pub fn call_lastChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try traverseChildren(instance, .last);
}

/// DOM §6.3 - TreeWalker.previousSibling()
/// Move to previous sibling that passes filter
pub fn call_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try traverseSiblings(instance, .previous);
}

/// DOM §6.3 - TreeWalker.nextSibling()
/// Move to next sibling that passes filter
pub fn call_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try traverseSiblings(instance, .next);
}

/// DOM §6.3 - TreeWalker.previousNode()
/// Move to previous node in tree order that passes filter
pub fn call_previousNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);

    // Step 1: Let node be this's current
    var node = internal.current orelse return null;

    // Step 2: While node is not this's root
    while (internal.root == null or node != internal.root.?) {
        // Step 2.1: Let sibling be node's previous sibling
        var sibling = getPreviousSibling(node);

        // Step 2.2: While sibling is non-null
        while (sibling) |sib| {
            // Step 2.2.1: Set node to sibling
            node = sib;

            // Step 2.2.2: Let result be the result of filtering node
            var result = try filterNode(instance, node);

            // Step 2.2.3: While result is not FILTER_REJECT and node has a child
            while (result != NodeFilter.FILTER_REJECT and hasChildren(node)) {
                // Step 2.2.3.1: Set node to node's last child
                node = getLastChild(node) orelse break;

                // Step 2.2.3.2: Set result to the result of filtering node
                result = try filterNode(instance, node);
            }

            // Step 2.2.4: If result is FILTER_ACCEPT, set current and return
            if (result == NodeFilter.FILTER_ACCEPT) {
                internal.current = node;
                return node;
            }

            // Step 2.2.5: Set sibling to node's previous sibling
            sibling = getPreviousSibling(node);
        }

        // Step 2.3: If node is root or node's parent is null, return null
        if (internal.root != null and node == internal.root.?) {
            return null;
        }
        if (getParentNode(node) == null) {
            return null;
        }

        // Step 2.4: Set node to node's parent
        node = getParentNode(node).?;

        // Step 2.5: If filtering node returns FILTER_ACCEPT, set current and return
        const result = try filterNode(instance, node);
        if (result == NodeFilter.FILTER_ACCEPT) {
            internal.current = node;
            return node;
        }
    }

    // Step 3: Return null
    return null;
}

/// DOM §6.3 - TreeWalker.nextNode()
/// Move to next node in tree order that passes filter
pub fn call_nextNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);

    // Step 1: Let node be this's current
    var node = internal.current orelse return null;

    // Step 2: Let result be FILTER_ACCEPT
    var result: u16 = NodeFilter.FILTER_ACCEPT;

    // Step 3: While true
    while (true) {
        // Step 3.1: While result is not FILTER_REJECT and node has a child
        while (result != NodeFilter.FILTER_REJECT and hasChildren(node)) {
            // Step 3.1.1: Set node to its first child
            node = getFirstChild(node) orelse break;

            // Step 3.1.2: Set result to the result of filtering node
            result = try filterNode(instance, node);

            // Step 3.1.3: If result is FILTER_ACCEPT, set current and return
            if (result == NodeFilter.FILTER_ACCEPT) {
                internal.current = node;
                return node;
            }
        }

        // Step 3.2: Let sibling be null
        var sibling: ?*runtime.Instance = null;

        // Step 3.3: Let temporary be node
        var temporary: ?*runtime.Instance = node;

        // Step 3.4: While temporary is non-null
        while (temporary) |temp| {
            // Step 3.4.1: If temporary is root, return null
            if (internal.root != null and temp == internal.root.?) {
                return null;
            }

            // Step 3.4.2: Set sibling to temporary's next sibling
            sibling = getNextSibling(temp);

            // Step 3.4.3: If sibling is non-null, set node and break
            if (sibling) |sib| {
                node = sib;
                break;
            }

            // Step 3.4.4: Set temporary to temporary's parent
            temporary = getParentNode(temp);
        }

        // If we didn't find a sibling, return null
        if (sibling == null) {
            return null;
        }

        // Step 3.5: Set result to the result of filtering node
        result = try filterNode(instance, node);

        // Step 3.6: If result is FILTER_ACCEPT, set current and return
        if (result == NodeFilter.FILTER_ACCEPT) {
            internal.current = node;
            return node;
        }
    }
}

// ============================================================================
// Internal algorithms
// ============================================================================

/// DOM §6.3 - traverse children algorithm
fn traverseChildren(instance: *runtime.Instance, child_type: ChildType) ImplError!?*runtime.Instance {
    const internal = getInternal(instance);

    // Step 1: Let node be walker's current
    var node = internal.current orelse return null;

    // Step 2: Set node to node's first/last child
    node = switch (child_type) {
        .first => getFirstChild(node) orelse return null,
        .last => getLastChild(node) orelse return null,
    };

    // Step 3: While node is non-null
    while (true) {
        // Step 3.1: Let result be the result of filtering node
        const result = try filterNode(instance, node);

        // Step 3.2: If result is FILTER_ACCEPT, set current and return
        if (result == NodeFilter.FILTER_ACCEPT) {
            internal.current = node;
            return node;
        }

        // Step 3.3: If result is FILTER_SKIP
        if (result == NodeFilter.FILTER_SKIP) {
            // Step 3.3.1: Let child be node's first/last child
            const child = switch (child_type) {
                .first => getFirstChild(node),
                .last => getLastChild(node),
            };

            // Step 3.3.2: If child is non-null, set node and continue
            if (child) |c| {
                node = c;
                continue;
            }
        }

        // Step 3.4: While node is non-null
        while (true) {
            // Step 3.4.1: Let sibling be node's next/previous sibling
            const sibling = switch (child_type) {
                .first => getNextSibling(node),
                .last => getPreviousSibling(node),
            };

            // Step 3.4.2: If sibling is non-null, set node and break
            if (sibling) |sib| {
                node = sib;
                break;
            }

            // Step 3.4.3: Let parent be node's parent
            const parent = getParentNode(node) orelse return null;

            // Step 3.4.4: If parent is null, root, or current, return null
            if (internal.root != null and parent == internal.root.?) {
                return null;
            }
            if (parent == internal.current) {
                return null;
            }

            // Step 3.4.5: Set node to parent
            node = parent;
        }
    }
}

/// DOM §6.3 - traverse siblings algorithm
fn traverseSiblings(instance: *runtime.Instance, sibling_type: SiblingType) ImplError!?*runtime.Instance {
    const internal = getInternal(instance);

    // Step 1: Let node be walker's current
    var node = internal.current orelse return null;

    // Step 2: If node is root, return null
    if (internal.root != null and node == internal.root.?) {
        return null;
    }

    // Step 3: While true
    while (true) {
        // Step 3.1: Let sibling be node's next/previous sibling
        var sibling = switch (sibling_type) {
            .next => getNextSibling(node),
            .previous => getPreviousSibling(node),
        };

        // Step 3.2: While sibling is non-null
        while (sibling) |sib| {
            // Step 3.2.1: Set node to sibling
            node = sib;

            // Step 3.2.2: Let result be the result of filtering node
            const result = try filterNode(instance, node);

            // Step 3.2.3: If result is FILTER_ACCEPT, set current and return
            if (result == NodeFilter.FILTER_ACCEPT) {
                internal.current = node;
                return node;
            }

            // Step 3.2.4: Set sibling to node's first/last child
            sibling = switch (sibling_type) {
                .next => getFirstChild(node),
                .previous => getLastChild(node),
            };

            // Step 3.2.5: If result is FILTER_REJECT or sibling is null
            if (result == NodeFilter.FILTER_REJECT or sibling == null) {
                // Set sibling to node's next/previous sibling
                sibling = switch (sibling_type) {
                    .next => getNextSibling(node),
                    .previous => getPreviousSibling(node),
                };
            }
        }

        // Step 3.3: Set node to node's parent
        const parent = getParentNode(node);
        node = parent orelse return null;

        // Step 3.4: If node is null or root, return null
        if (internal.root != null and node == internal.root.?) {
            return null;
        }

        // Step 3.5: If filtering node returns FILTER_ACCEPT, return null
        const result = try filterNode(instance, node);
        if (result == NodeFilter.FILTER_ACCEPT) {
            return null;
        }
    }
}

/// DOM §6 - filter algorithm
/// Filter a node within this walker
fn filterNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!u16 {
    const internal = getInternal(instance);

    // Step 1: If traverser's active flag is set, throw InvalidStateError
    if (internal.active_flag) {
        return error.InvalidStateError;
    }

    // Step 2: Let n be node's nodeType attribute value − 1
    const node_type = getNodeType(node);
    const n: u8 = @intCast(node_type - 1);

    // Step 3: If the nth bit of whatToShow is not set, return FILTER_SKIP
    if (!NodeFilter.isNodeTypeShown(internal.what_to_show, n)) {
        return NodeFilter.FILTER_SKIP;
    }

    // Step 4: If filter is null, return FILTER_ACCEPT
    if (internal.filter == null) {
        return NodeFilter.FILTER_ACCEPT;
    }

    // Step 5: Set traverser's active flag
    internal.active_flag = true;

    // Step 6: Call filter callback
    // TODO: Implement proper WebIDL callback invocation when callback system is ready
    // For now, accept all nodes that pass whatToShow
    const result = NodeFilter.FILTER_ACCEPT;

    // Step 7: Unset traverser's active flag
    internal.active_flag = false;

    // Step 8: Return result
    return result;
}

// ============================================================================
// Tree traversal helpers (using NodeImpl)
// ============================================================================

fn getParentNode(node: *runtime.Instance) ?*runtime.Instance {
    return NodeImpl.getParent(node);
}

fn getFirstChild(node: *runtime.Instance) ?*runtime.Instance {
    return NodeImpl.getFirstChild(node);
}

fn getLastChild(node: *runtime.Instance) ?*runtime.Instance {
    return NodeImpl.getLastChild(node);
}

fn getNextSibling(node: *runtime.Instance) ?*runtime.Instance {
    return NodeImpl.getNextSibling(node);
}

fn getPreviousSibling(node: *runtime.Instance) ?*runtime.Instance {
    return NodeImpl.getPreviousSibling(node);
}

fn hasChildren(node: *runtime.Instance) bool {
    return NodeImpl.hasChildren(node);
}

/// Get the node type from a node instance
fn getNodeType(node: *runtime.Instance) u16 {
    return NodeImpl.getNodeType(node) orelse 1; // Default to ELEMENT_NODE
}
