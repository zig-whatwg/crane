//! DOM Mutation Algorithms (WHATWG DOM Standard §4.2.5)
//!
//! Spec: https://dom.spec.whatwg.org/#mutation-algorithms
//!
//! This module implements the complete set of mutation algorithms for DOM node trees.
//! All algorithms follow the WHATWG DOM specification precisely.
//!
//! ARCHITECTURE: This module operates on NodeBase - the single source of truth for
//! DOM tree structure. WebIDL impls delegate all tree operations here.

const std = @import("std");
const infra = @import("infra");
const runtime = @import("runtime");

// NodeBase is THE source of truth for DOM tree structure
const node_base = @import("node_base.zig");
const NodeBase = node_base.NodeBase;

// Node type constants from NodeBase
const ELEMENT_NODE = NodeBase.ELEMENT_NODE;
const ATTRIBUTE_NODE = NodeBase.ATTRIBUTE_NODE;
const TEXT_NODE = NodeBase.TEXT_NODE;
const CDATA_SECTION_NODE = NodeBase.CDATA_SECTION_NODE;
const PROCESSING_INSTRUCTION_NODE = NodeBase.PROCESSING_INSTRUCTION_NODE;
const COMMENT_NODE = NodeBase.COMMENT_NODE;
const DOCUMENT_NODE = NodeBase.DOCUMENT_NODE;
const DOCUMENT_TYPE_NODE = NodeBase.DOCUMENT_TYPE_NODE;
const DOCUMENT_FRAGMENT_NODE = NodeBase.DOCUMENT_FRAGMENT_NODE;

// Local DOM modules
const RegisteredObserver = @import("registered_observer.zig").RegisteredObserver;
const tree_helpers = @import("tree_helpers.zig");
const shadow_dom_algorithms = @import("shadow_dom_algorithms.zig");
const mutation_observer = @import("mutation_observer_algorithms.zig");
const document_internals = @import("document_internals.zig");
const element_with_base = @import("element_with_base.zig");
const attr_with_base = @import("attr_with_base.zig");
const instance_bridge = @import("instance_bridge.zig");

// Interface types needed for mutation observer integration
const interfaces = @import("interfaces");
const NodeList = interfaces.NodeList;
const Node = interfaces.Node;
const Document = interfaces.Document;

// Implementation modules for creating NodeLists
const impls = @import("impls");
const NodeListImpl = impls.NodeList;
const RangeImpl = impls.Range;
const NodeIteratorImpl = impls.NodeIterator;

/// DOM Exception types as defined in WebIDL
pub const DOMException = error{
    HierarchyRequestError,
    NotFoundError,
    NotSupportedError,
    OutOfMemory,
    IndexOutOfBounds,
};

/// Children Changed Steps Callback
/// Spec: https://dom.spec.whatwg.org/#concept-node-children-changed-ext
///
/// Specifications (like HTML) may define children changed steps for all or some nodes.
/// The algorithm is passed the parent node and is called from insert, remove, and replace data.
///
/// Example usage (to be implemented by HTML spec):
///   - Slot assignment algorithm (Shadow DOM)
///   - Form-associated element connections
///   - Custom element reactions
///
/// This is an extension point for specifications to hook into DOM mutations.
pub const ChildrenChangedCallback = *const fn (parent: *NodeBase) void;

/// Global registry for children changed steps callbacks
/// This allows specifications (like HTML) to register their hooks
/// Uses page_allocator since this lives for the program lifetime and is never freed
var children_changed_callbacks: ?infra.List(ChildrenChangedCallback) = null;

/// Register a callback to be invoked when children change
/// This should be called during initialization by specifications that need to hook into mutations
pub fn registerChildrenChangedCallback(callback: ChildrenChangedCallback) !void {
    if (children_changed_callbacks == null) {
        children_changed_callbacks = infra.List(ChildrenChangedCallback).init(std.heap.page_allocator);
    }
    try children_changed_callbacks.?.append(callback);
}

/// Run the children changed steps for a parent node
/// Spec: https://dom.spec.whatwg.org/#concept-node-children-changed-ext
///
/// Called from:
/// - insert (step 9)
/// - remove (step 17)
/// - replace data in CharacterData (step 12)
pub fn runChildrenChangedSteps(parent: anytype) void {
    // Cast to *NodeBase for callbacks (all DOM types have Node fields duplicated)
    const parent_node: *NodeBase = @ptrCast(parent);

    // Call all registered callbacks
    if (children_changed_callbacks) |*callbacks| {
        for (callbacks.items()) |callback| {
            callback(parent_node);
        }
    }

    // Note: If no callbacks are registered, this is a no-op
    // This is expected until HTML or other specifications register their hooks
}

/// Insertion Steps Callback
/// Spec: Specifications may define insertion steps for all or some nodes.
/// The algorithm is passed the inserted node.
///
/// Examples:
///   - HTML: iframe loading, form-associated element connections
///   - Custom elements: connectedCallback
pub const InsertionStepsCallback = *const fn (node: *NodeBase) void;

/// Removing Steps Callback
/// Spec: Specifications may define removing steps for all or some nodes.
/// The algorithm is passed the removed node and optionally the old parent.
///
/// Examples:
///   - HTML: iframe unloading, form-associated element disconnections
///   - Custom elements: disconnectedCallback
pub const RemovingStepsCallback = *const fn (node: *NodeBase, old_parent: ?*NodeBase) void;

/// Post-connection Steps Callback
/// Spec: The post-connection steps are run after a batch of nodes is inserted.
/// This allows JavaScript to run after all mutations are complete.
///
/// Examples:
///   - HTML: iframe loading after all tree mutations
///   - Custom elements: batch reactions after insertion
pub const PostConnectionStepsCallback = *const fn (node: *NodeBase) void;

/// Moving Steps Callback
/// Spec: Specifications may define moving steps for all or some nodes.
/// The algorithm is passed the moved node and optionally the old parent.
///
/// Examples:
///   - Custom elements: connectedMoveCallback
///   - HTML: element relocation handling
pub const MovingStepsCallback = *const fn (node: *NodeBase, old_parent: ?*NodeBase) void;

/// Global registry for insertion steps callbacks
/// Uses page_allocator since this lives for the program lifetime and is never freed
var insertion_steps_callbacks: ?infra.List(InsertionStepsCallback) = null;

/// Global registry for removing steps callbacks
/// Uses page_allocator since this lives for the program lifetime and is never freed
var removing_steps_callbacks: ?infra.List(RemovingStepsCallback) = null;

/// Global registry for post-connection steps callbacks
/// Uses page_allocator since this lives for the program lifetime and is never freed
var post_connection_steps_callbacks: ?infra.List(PostConnectionStepsCallback) = null;

/// Global registry for moving steps callbacks
/// Uses page_allocator since this lives for the program lifetime and is never freed
var moving_steps_callbacks: ?infra.List(MovingStepsCallback) = null;

/// Register a callback for insertion steps
pub fn registerInsertionStepsCallback(callback: InsertionStepsCallback) !void {
    if (insertion_steps_callbacks == null) {
        insertion_steps_callbacks = infra.List(InsertionStepsCallback).init(std.heap.page_allocator);
    }
    try insertion_steps_callbacks.?.append(callback);
}

/// Register a callback for removing steps
pub fn registerRemovingStepsCallback(callback: RemovingStepsCallback) !void {
    if (removing_steps_callbacks == null) {
        removing_steps_callbacks = infra.List(RemovingStepsCallback).init(std.heap.page_allocator);
    }
    try removing_steps_callbacks.?.append(callback);
}

/// Register a callback for post-connection steps
pub fn registerPostConnectionStepsCallback(callback: PostConnectionStepsCallback) !void {
    if (post_connection_steps_callbacks == null) {
        post_connection_steps_callbacks = infra.List(PostConnectionStepsCallback).init(std.heap.page_allocator);
    }
    try post_connection_steps_callbacks.?.append(callback);
}

/// Register a callback for moving steps
pub fn registerMovingStepsCallback(callback: MovingStepsCallback) !void {
    if (moving_steps_callbacks == null) {
        moving_steps_callbacks = infra.List(MovingStepsCallback).init(std.heap.page_allocator);
    }
    try moving_steps_callbacks.?.append(callback);
}

/// Run the insertion steps for a node
/// Called during the insert algorithm for each shadow-including descendant
fn runInsertionSteps(node: anytype) void {
    // Fast path: if no callbacks are registered, skip entirely
    const callbacks = insertion_steps_callbacks orelse return;
    if (callbacks.size() == 0) return;

    const node_ptr: *NodeBase = @ptrCast(node);
    for (callbacks.items()) |callback| {
        callback(node_ptr);
    }
}

/// Check if there are any insertion steps callbacks registered
/// Used to skip expensive descendant traversal when no callbacks exist
pub fn hasInsertionStepsCallbacks() bool {
    const callbacks = insertion_steps_callbacks orelse return false;
    return callbacks.size() > 0;
}

/// Run the removing steps for a node
/// Called during the remove algorithm
fn runRemovingSteps(node: anytype, old_parent: anytype) void {
    const node_ptr: *NodeBase = @ptrCast(node);
    // Handle optional or non-optional old_parent
    const old_parent_ptr: ?*NodeBase = if (@TypeOf(old_parent) == @TypeOf(null))
        null
    else if (@typeInfo(@TypeOf(old_parent)) == .optional)
        if (old_parent) |p| @ptrCast(p) else null
    else
        @ptrCast(old_parent);

    if (removing_steps_callbacks) |*callbacks| {
        for (callbacks.items()) |callback| {
            callback(node_ptr, old_parent_ptr);
        }
    }
}

/// Run the post-connection steps for a node
/// Called after a batch of insertions complete
fn runPostConnectionSteps(node: anytype) void {
    // Fast path: if no callbacks are registered, skip entirely
    const callbacks = post_connection_steps_callbacks orelse return;
    if (callbacks.size() == 0) return;

    const node_ptr: *NodeBase = @ptrCast(node);
    for (callbacks.items()) |callback| {
        callback(node_ptr);
    }
}

/// Check if there are any post-connection steps callbacks registered
/// Used to skip expensive descendant traversal when no callbacks exist
pub fn hasPostConnectionStepsCallbacks() bool {
    const callbacks = post_connection_steps_callbacks orelse return false;
    return callbacks.size() > 0;
}

/// Recursively run insertion steps for a node and all its descendants
fn runInsertionStepsRecursive(node: anytype) void {
    runInsertionSteps(node);
    for (node.child_nodes.items()) |child| {
        runInsertionStepsRecursive(child);
    }
}

/// Recursively run post-connection steps for a node and all its descendants
fn runPostConnectionStepsRecursive(node: anytype) void {
    runPostConnectionSteps(node);
    for (node.child_nodes.items()) |child| {
        runPostConnectionStepsRecursive(child);
    }
}

/// Recursively run removing steps for a node and all its descendants
fn runRemovingStepsRecursive(node: anytype, old_parent: anytype) void {
    runRemovingSteps(node, old_parent);
    for (node.child_nodes.items()) |child| {
        runRemovingStepsRecursive(child, node);
    }
}

/// Recursively set the is_connected flag for a node and all its descendants
/// Called during insert (connected=true) and remove (connected=false) operations
/// Uses sibling pointers instead of child_nodes.items() for safety during tree construction
fn setConnectedRecursive(node: anytype, connected: bool) void {
    node.is_connected = connected;
    // Use first_child/next_sibling which are always safely initialized to null
    var child = node.first_child;
    while (child) |c| {
        setConnectedRecursive(c, connected);
        child = c.next_sibling;
    }
}

/// Create transient registered observers for a removed node
/// Spec: https://dom.spec.whatwg.org/#concept-node-remove step 15
fn createTransientObserversForRemovedNode(node: anytype, parent: anytype) !void {
    // For each inclusive ancestor inclusiveAncestor of parent
    var current_ancestor: ?*NodeBase = @ptrCast(parent);
    while (current_ancestor) |ancestor| {
        // For each registered observer obs in inclusiveAncestor's registered observer list
        for (0..ancestor.registered_observers.len) |i| {
            const source_obs = ancestor.registered_observers.get(i) orelse continue;
            // If obs's options["subtree"] is true
            if (source_obs.options.subtree) {
                // For each node inclusiveDescendant of node's inclusive descendants
                // (node itself and all its descendants)
                try createTransientObserverForNodeAndDescendants(node, source_obs);
            }
        }

        // Move to next ancestor
        current_ancestor = ancestor.parent_node;
    }
}

/// Helper: Create transient observer for a node and all its descendants
/// TODO(Phase 6 - whatwg-9wkz8): Implement transient observers per DOM spec §4.3.3
/// This requires adding is_transient, source_observer, source_options fields to RegisteredObserver
fn createTransientObserverForNodeAndDescendants(node: anytype, source: RegisteredObserver) !void {
    // Stub: Transient observers will be implemented in Phase 6 (MutationObserver integration)
    // Per spec, transient observers are created when a node is removed while being observed
    // with subtree: true, to continue observing the removed subtree.
    _ = node;
    _ = source;
}

/// Helper to get node type from any node-like type
fn getNodeType(node: anytype) u16 {
    return node.node_type;
}

/// Helper to check if node is a Document
fn isDocument(node: anytype) bool {
    return getNodeType(node) == DOCUMENT_NODE;
}

/// Helper to check if node is a DocumentFragment
fn isDocumentFragment(node: anytype) bool {
    return getNodeType(node) == DOCUMENT_FRAGMENT_NODE;
}

/// Helper to check if node is an Element
fn isElement(node: anytype) bool {
    return getNodeType(node) == ELEMENT_NODE;
}

/// Helper to check if node is a DocumentType
fn isDocumentType(node: anytype) bool {
    return getNodeType(node) == DOCUMENT_TYPE_NODE;
}

/// Helper to check if node is a Text node
fn isText(node: anytype) bool {
    return getNodeType(node) == TEXT_NODE;
}

/// Queue a tree mutation record for MutationObserver notifications
///
/// This function bridges the NodeBase-based mutation algorithms with the
/// WebIDL MutationObserver system. It converts NodeBase arrays to NodeLists
/// and calls the mutation observer algorithm.
///
/// Spec: https://dom.spec.whatwg.org/#queue-a-tree-mutation-record
///
/// @param allocator - Allocator for creating NodeLists
/// @param target - The parent node that was mutated (NodeBase)
/// @param added_nodes - Array of NodeBase pointers that were added
/// @param removed_nodes - Array of NodeBase pointers that were removed
/// @param previous_sibling - The sibling before the mutation (or null)
/// @param next_sibling - The sibling after the mutation (or null)
fn queueTreeMutationRecord(
    allocator: std.mem.Allocator,
    target: anytype,
    added_nodes: []const *NodeBase,
    removed_nodes: []const *NodeBase,
    previous_sibling: ?*NodeBase,
    next_sibling: ?*NodeBase,
) void {
    // Early return if both arrays are empty (spec step 1 assertion would fail)
    if (added_nodes.len == 0 and removed_nodes.len == 0) return;

    // Get the target as a runtime.Instance via the instance bridge
    const target_nodebase: *NodeBase = @ptrCast(target);
    const target_instance_ptr = instance_bridge.getInstance(target_nodebase) orelse {
        // Target is not a registered runtime.Instance - cannot queue mutation record
        // This can happen for nodes created purely through NodeBase (e.g., during parsing)
        return;
    };
    const target_instance: *runtime.Instance = @ptrCast(@alignCast(target_instance_ptr));

    // Get runtime context from the instance
    // The context is needed for creating NodeLists
    const ctx = target_instance.ctx;

    // Create NodeList for added nodes
    const added_list = createNodeListFromBases(allocator, ctx, added_nodes) catch {
        // If we can't create the NodeList, skip the mutation record
        return;
    };

    // Create NodeList for removed nodes
    const removed_list = createNodeListFromBases(allocator, ctx, removed_nodes) catch {
        // Clean up added_list if we fail
        NodeListImpl.deinit(added_list);
        return;
    };

    // Convert previous_sibling and next_sibling to runtime.Instance
    const prev_instance: ?*runtime.Instance = if (previous_sibling) |prev| blk: {
        const prev_inst_ptr = instance_bridge.getInstance(prev) orelse break :blk null;
        break :blk @ptrCast(@alignCast(prev_inst_ptr));
    } else null;

    const next_instance: ?*runtime.Instance = if (next_sibling) |next| blk: {
        const next_inst_ptr = instance_bridge.getInstance(next) orelse break :blk null;
        break :blk @ptrCast(@alignCast(next_inst_ptr));
    } else null;

    // Call the mutation observer algorithm
    mutation_observer.queueTreeMutationRecord(
        allocator,
        target_instance,
        added_list,
        removed_list,
        prev_instance,
        next_instance,
    ) catch {
        // If queueing fails, clean up the NodeLists
        NodeListImpl.deinit(added_list);
        NodeListImpl.deinit(removed_list);
    };
}

/// Create a NodeList from an array of NodeBase pointers
///
/// This converts NodeBase pointers to runtime.Instance pointers via the
/// instance bridge and creates a static NodeList containing them.
///
/// @param allocator - Allocator for the NodeList
/// @param ctx - Runtime context for NodeList creation
/// @param nodes - Array of NodeBase pointers to include
/// @returns A NodeList instance, or error if creation fails
fn createNodeListFromBases(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    nodes: []const *NodeBase,
) !*runtime.Instance {
    // Collect instances from the NodeBase array
    var instances: std.ArrayList(*runtime.Instance) = .{};
    defer instances.deinit(allocator);

    for (nodes) |node_base_ptr| {
        if (instance_bridge.getInstance(node_base_ptr)) |instance_ptr| {
            // Cast anyopaque to *runtime.Instance
            const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));
            try instances.append(allocator, instance);
        }
        // Skip nodes that aren't registered as runtime instances
        // This handles internal nodes that may not have WebIDL wrappers
    }

    // Create a static NodeList from the collected instances
    return NodeListImpl.createFromSlice(allocator, ctx, instances.items);
}

/// Helper to check if node is a CharacterData node
fn isCharacterData(node: anytype) bool {
    const node_type = getNodeType(node);
    return node_type == TEXT_NODE or
        node_type == COMMENT_NODE or
        node_type == CDATA_SECTION_NODE or
        node_type == PROCESSING_INSTRUCTION_NODE;
}

/// Get child index in parent
fn getChildIndex(child: anytype) ?usize {
    const parent = child.parent_node orelse return null;
    // Cast child to *NodeBase for comparison with child_nodes array
    const child_node: *NodeBase = @ptrCast(child);
    for (parent.child_nodes.items(), 0..) |node, i| {
        if (node == child_node) return i;
    }
    return null;
}

/// Check if a doctype is following a given child in parent
fn isDoctypeFollowing(parent: *NodeBase, child: ?*NodeBase) bool {
    const c = child orelse return false;

    const child_idx = getChildIndex(c) orelse return false;

    // Check all siblings after child
    for (parent.child_nodes.items()[child_idx + 1 ..]) |sibling| {
        if (isDocumentType(sibling)) return true;
    }

    return false;
}

/// Check if an element is preceding a given child in parent
fn isElementPreceding(parent: *NodeBase, child: ?*NodeBase) bool {
    if (child == null) {
        // If child is null, check if parent has any element children
        for (parent.child_nodes.items()) |node| {
            if (isElement(node)) return true;
        }
        return false;
    }

    const child_idx = getChildIndex(child.?) orelse return false;

    // Check all siblings before child
    for (parent.child_nodes.items()[0..child_idx]) |sibling| {
        if (isElement(sibling)) return true;
    }

    return false;
}

/// Count element children of a node
fn countElementChildren(node: anytype) usize {
    var count: usize = 0;
    for (node.child_nodes.items()) |child| {
        if (isElement(child)) count += 1;
    }
    return count;
}

/// Check if node has a Text child
fn hasTextChild(node: anytype) bool {
    for (node.child_nodes.items()) |child| {
        if (isText(child)) return true;
    }
    return false;
}

/// Check if parent has a doctype child
fn hasDoctypeChild(parent: anytype) bool {
    for (parent.child_nodes.items()) |child| {
        if (isDocumentType(child)) return true;
    }
    return false;
}

/// Check if parent has an element child (optionally excluding one node)
fn hasElementChild(parent: *NodeBase, exclude: ?*NodeBase) bool {
    for (parent.child_nodes.items()) |child| {
        if (exclude) |ex| {
            if (child == ex) continue;
        }
        if (isElement(child)) return true;
    }
    return false;
}

/// DOM §4.2.5 - Ensure pre-insertion validity
/// Spec: https://dom.spec.whatwg.org/#concept-node-ensure-pre-insertion-validity
///
/// Steps:
/// 1. If parent is not a Document, DocumentFragment, or Element node, throw HierarchyRequestError
/// 2. If node is a host-including inclusive ancestor of parent, throw HierarchyRequestError
/// 3. If child is non-null and its parent is not parent, throw NotFoundError
/// 4. If node is not a DocumentFragment, DocumentType, Element, or CharacterData node, throw HierarchyRequestError
/// 5. If either node is a Text node and parent is a document, or node is a doctype and parent is not a document, throw HierarchyRequestError
/// 6. If parent is a document, perform additional validation based on node type
pub fn ensurePreInsertValidity(
    node: anytype,
    parent: anytype,
    child: anytype,
) DOMException!void {
    // Step 1: Check parent is Document, DocumentFragment, or Element
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 2: Check node is not host-including inclusive ancestor of parent
    if (isHostIncludingInclusiveAncestor(node, parent)) {
        return error.HierarchyRequestError;
    }

    // Step 3: If child is non-null, check child's parent is parent
    if (child) |c| {
        if (c.parent_node != parent) {
            return error.NotFoundError;
        }
    }

    // Step 4: Check node is valid type
    if (!isDocumentFragment(node) and !isDocumentType(node) and
        !isElement(node) and !isCharacterData(node))
    {
        return error.HierarchyRequestError;
    }

    // Step 5: Check Text/doctype constraints
    if (isText(node) and isDocument(parent)) {
        return error.HierarchyRequestError;
    }
    if (isDocumentType(node) and !isDocument(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 6: If parent is a document, check additional constraints
    if (isDocument(parent)) {
        if (isDocumentFragment(node)) {
            // Check DocumentFragment constraints
            const element_count = countElementChildren(node);

            if (element_count > 1 or hasTextChild(node)) {
                return error.HierarchyRequestError;
            }

            if (element_count == 1) {
                if (hasElementChild(parent, null) or
                    isDoctypeFollowing(parent, child) or
                    (child != null and isDocumentType(child.?)))
                {
                    return error.HierarchyRequestError;
                }
            }
        } else if (isElement(node)) {
            // Check Element constraints
            if (hasElementChild(parent, null) or
                isDoctypeFollowing(parent, child) or
                (child != null and isDocumentType(child.?)))
            {
                return error.HierarchyRequestError;
            }
        } else if (isDocumentType(node)) {
            // Check DocumentType constraints
            if (hasDoctypeChild(parent) or
                isElementPreceding(parent, child) or
                (child == null and hasElementChild(parent, null)))
            {
                return error.HierarchyRequestError;
            }
        }
    }
}

/// DOM §4.2.5 - Pre-insert
/// Spec: https://dom.spec.whatwg.org/#concept-node-pre-insert
///
/// Steps:
/// 1. Ensure pre-insertion validity of node into parent before child
/// 2. Let referenceChild be child
/// 3. If referenceChild is node, then set referenceChild to node's next sibling
/// 4. Insert node into parent before referenceChild
/// 5. Return node
pub fn preInsert(
    node: anytype,
    parent: anytype,
    child: anytype,
) DOMException!@TypeOf(node) {
    // Step 1: Ensure pre-insertion validity
    try ensurePreInsertValidity(node, parent, child);

    // Step 2: Let referenceChild be child
    // Step 3: If referenceChild is node, set to node's next sibling
    const referenceChild = if (child != null and child.? == node) blk: {
        // Find node's next sibling
        if (node.parent_node) |node_parent| {
            const idx = getChildIndex(node) orelse break :blk null;
            if (idx + 1 < node_parent.child_nodes.size()) {
                break :blk node_parent.child_nodes.items()[idx + 1];
            }
        }
        break :blk null;
    } else child;

    // Step 4: Insert node into parent before referenceChild
    try insert(node, parent, referenceChild, false);

    // Step 5: Return node
    return node;
}

/// DOM §4.2.5 - Insert
/// Spec: https://dom.spec.whatwg.org/#concept-node-insert
///
/// This is the core insertion algorithm. It handles:
/// - DocumentFragment unwrapping
/// - Live range updates
/// - Node adoption
/// - Shadow DOM slot assignment
/// - Insertion steps callbacks
/// - Mutation observer notifications
pub fn insert(
    node: anytype,
    parent: anytype,
    child: anytype,
    suppress_observers: bool,
) DOMException!void {
    // Step 1: Let nodes be node's children if node is DocumentFragment, otherwise « node »
    var nodes: []*NodeBase = undefined;
    var nodes_buf: [256]*NodeBase = undefined;
    var nodes_count: usize = 0;

    if (isDocumentFragment(node)) {
        nodes = node.child_nodes.toSliceMut();
        nodes_count = nodes.len;
    } else {
        nodes_buf[0] = node;
        nodes = nodes_buf[0..1];
        nodes_count = 1;
    }

    // Step 2: Let count be nodes's size
    const count = nodes_count;

    // Step 3: If count is 0, then return
    if (count == 0) return;

    // Step 4: If node is a DocumentFragment node:
    if (isDocumentFragment(node)) {
        // Step 4.1: Remove its children with suppress observers flag set
        for (node.child_nodes.items()) |child_node| {
            try remove(child_node, true);
        }

        // Step 4.2: Queue a tree mutation record for node
        // addedNodes is empty, removedNodes is the children that were removed
        queueTreeMutationRecord(
            parent.allocator,
            node,
            &[_]*NodeBase{},
            nodes[0..nodes_count],
            null,
            null,
        );
    }

    // Step 5: If child is non-null, update live ranges
    if (child) |c| {
        const child_idx = getChildIndex(c) orelse 0;

        // Update live ranges: For each live range whose start/end node is parent
        // and offset > child's index, increase offset by count
        if (parent.owner_document) |doc| {
            updateRangesForInsertionWithCount(doc, parent, child_idx, count);
        }
    }

    // Step 6: Let previousSibling be child's previous sibling or parent's last child if child is null
    var previousSibling: ?*NodeBase = null;
    if (child) |c| {
        const idx = getChildIndex(c) orelse 0;
        if (idx > 0) {
            previousSibling = parent.child_nodes.items()[idx - 1];
        }
    } else {
        if (parent.child_nodes.size() > 0) {
            previousSibling = parent.child_nodes.items()[parent.child_nodes.size() - 1];
        }
    }

    // Step 7: For each node in nodes, in tree order:
    for (nodes[0..count]) |n| {
        // Step 7.1: Adopt node into parent's node document
        // Per DOM spec, a Document's node document is itself (ownerDocument returns null but
        // internally the document is its own node document for adoption purposes).
        // For Document nodes, we skip adoption since the document owns itself.
        if (parent.owner_document) |doc| {
            try adopt(n, doc);
        } else if (parent.node_type == DOCUMENT_NODE) {
            // Parent is a Document - set node's owner_document to the parent (cast to Document)
            // This is safe because Document has NodeBase as its first field
            const doc: *interfaces.Document = @ptrCast(@alignCast(parent));
            try adopt(n, doc);
        }
        // else: no owner document and not a document - shouldn't happen but skip adoption

        // Step 7.2-3: Insert node into parent's children
        // Phase 2: Maintain BOTH child_nodes list AND sibling pointers

        if (child) |c| {
            // Insert before child
            const idx = getChildIndex(c) orelse parent.child_nodes.size();
            try parent.child_nodes.insert(idx, n);

            // Update sibling pointers (Phase 2)
            n.next_sibling = c;
            n.previous_sibling = c.previous_sibling;

            if (c.previous_sibling) |prev| {
                prev.next_sibling = n;
            } else {
                parent.first_child = n;
            }
            c.previous_sibling = n;
        } else {
            // Append at end
            try parent.child_nodes.append(n);

            // Update sibling pointers (Phase 2)
            n.previous_sibling = parent.last_child;
            n.next_sibling = null;

            if (parent.last_child) |last| {
                last.next_sibling = n;
            } else {
                parent.first_child = n;
            }
            parent.last_child = n;
        }

        // Cast parent to *NodeBase when assigning (all DOM types have Node fields duplicated)
        n.parent_node = @ptrCast(parent);

        // Update is_connected for the inserted node and all its descendants
        // A node is connected if its root is a Document
        // Per DOM spec: parent is connected if it's a Document or its root is a Document
        const parent_is_connected = parent.is_connected or parent.node_type == DOCUMENT_NODE;
        if (parent_is_connected) {
            setConnectedRecursive(n, true);
        }

        // Step 7.4: If parent is a shadow host and node is slottable, assign a slot
        // TODO: Implement when shadow DOM is fully integrated
        // if (isShadowHost(parent) and isSlottable(n)) {
        //     shadow_dom_algorithms.assignSlot(n);
        // }

        // Step 7.5: If parent's root is shadow root and parent is slot, signal slot change
        // TODO: Implement when shadow DOM is fully integrated

        // Step 7.6: Run assign slottables for a tree with node's root
        // TODO: Implement when shadow DOM is fully integrated

        // Step 7.7: For each shadow-including inclusive descendant of node,
        // in shadow-including tree order, run the insertion steps
        // Spec: DOM §4.2.5 step 7.7
        // Note: We process only the current node `n`, not all nodes (that would be O(n²))
        //
        // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
        // During HTML parsing, there are typically no insertion steps callbacks,
        // so this saves significant overhead for large documents.
        if (hasInsertionStepsCallbacks()) {
            // Get all shadow-including inclusive descendants in tree order
            var descendants = tree_helpers.getShadowIncludingInclusiveDescendants(
                parent.allocator,
                n,
            ) catch {
                // If we can't allocate, fall back to non-shadow traversal
                runInsertionSteps(n);
                for (n.child_nodes.items()) |descendant| {
                    runInsertionStepsRecursive(descendant);
                }
                continue;
            };
            defer descendants.deinit();

            // Run insertion steps for each shadow-including inclusive descendant
            for (descendants.toSlice()) |inclusive_descendant| {
                runInsertionSteps(inclusive_descendant);

                // TODO: Step 7.7.2-4 - Custom element reactions
                // If inclusiveDescendant is not connected, then continue
                // If inclusiveDescendant is an element, handle custom element registry
                // If inclusiveDescendant is custom, enqueue connectedCallback
            }
        }

        // TODO: Step 10-12 - Post-connection steps
        // Collect all nodes in staticNodeList before calling post-connection steps
    }

    // Step 8: If suppress observers flag is unset, queue a tree mutation record
    if (!suppress_observers) {
        queueTreeMutationRecord(
            parent.allocator,
            parent,
            nodes[0..nodes_count],
            &[_]*NodeBase{},
            previousSibling,
            child,
        );
    }

    // Step 9: Run the children changed steps for parent
    runChildrenChangedSteps(parent);

    // Steps 10-12: Post-connection steps
    // Spec: The post-connection steps are run after a batch of nodes is inserted
    // This allows specifications to execute JavaScript or perform connection-related
    // operations after all tree mutations are complete
    //
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasPostConnectionStepsCallbacks()) {
        for (nodes) |inserted_node| {
            runPostConnectionSteps(inserted_node);
            // Recursively run for all descendants
            for (inserted_node.child_nodes.items()) |descendant| {
                runPostConnectionStepsRecursive(descendant);
            }
        }
    }
}

/// DOM §4.2.5 - Append
/// Spec: https://dom.spec.whatwg.org/#concept-node-append
///
/// This is a convenience wrapper that pre-inserts before null
pub fn append(node: anytype, parent: anytype) DOMException!@TypeOf(node) {
    return preInsert(node, parent, null);
}

/// Batch Child Insertion API - Performance Optimization
///
/// Appends multiple children to a parent in a single operation.
/// This is more efficient than calling append() repeatedly because:
/// - Single mutation observer notification instead of N notifications
/// - Single children-changed callback instead of N callbacks
/// - Batch update of sibling pointers
/// - Uses appendSlice for O(1) amortized insertion vs O(n) repeated appends
///
/// Use this when parsing HTML fragments or building DOM trees where
/// multiple children are known upfront.
///
/// Example:
///   var children: [3]*NodeBase = .{ text1, text2, text3 };
///   try appendChildren(parent, &children);
///
pub fn appendChildren(
    parent: anytype,
    children: []const *NodeBase,
) DOMException!void {
    // Early exit if no children to insert
    if (children.len == 0) return;

    // Step 1: Validate parent is a valid container
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 2: Validate all children and adopt them
    for (children) |child| {
        // Check child is not an ancestor of parent
        if (isHostIncludingInclusiveAncestor(child, parent)) {
            return error.HierarchyRequestError;
        }

        // Check child is valid type
        if (!isDocumentFragment(child) and !isDocumentType(child) and
            !isElement(child) and !isCharacterData(child))
        {
            return error.HierarchyRequestError;
        }

        // Text nodes cannot be children of documents
        if (isText(child) and isDocument(parent)) {
            return error.HierarchyRequestError;
        }

        // Remove child from its current parent if any
        if (child.parent_node != null) {
            try remove(child, true); // suppress observers for batch efficiency
        }

        // Adopt child into parent's document
        if (parent.owner_document) |doc| {
            try adopt(child, doc);
        }
    }

    // Step 3: Get previous sibling for mutation record (last child before insertion)
    var previousSibling: ?*NodeBase = null;
    if (parent.child_nodes.size() > 0) {
        previousSibling = parent.child_nodes.items()[parent.child_nodes.size() - 1];
    }

    // Step 4: Batch insert all children using appendSlice for O(1) amortized insertion
    try parent.child_nodes.appendSlice(children);

    // Step 5: Update parent pointers AND sibling pointers for all inserted children
    // Phase 2: Maintain sibling pointers during batch append
    var prev_child: ?*NodeBase = previousSibling; // Last child before insertion (or null)
    for (children) |child| {
        child.parent_node = @ptrCast(parent);

        // Update sibling pointers
        child.previous_sibling = prev_child;
        child.next_sibling = null; // Will be updated by next iteration if there is one

        if (prev_child) |prev| {
            prev.next_sibling = child;
        } else {
            // This is the first child being inserted AND parent had no children
            parent.first_child = child;
        }

        prev_child = child;
    }

    // The last inserted child becomes parent's last_child
    if (children.len > 0) {
        parent.last_child = children[children.len - 1];
    }

    // Step 6: Update live ranges if document is available
    if (parent.owner_document) |doc| {
        const start_idx = parent.child_nodes.size() - children.len;
        updateRangesForInsertionWithCount(doc, parent, start_idx, children.len);
    }

    // Step 7: Run insertion steps for all inserted nodes and their descendants
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasInsertionStepsCallbacks()) {
        for (children) |child| {
            // Get all shadow-including inclusive descendants in tree order
            var descendants = tree_helpers.getShadowIncludingInclusiveDescendants(
                parent.allocator,
                child,
            ) catch {
                // If we can't allocate, fall back to non-shadow traversal
                runInsertionSteps(child);
                for (child.child_nodes.items()) |descendant| {
                    runInsertionStepsRecursive(descendant);
                }
                continue;
            };
            defer descendants.deinit();

            // Run insertion steps for each shadow-including inclusive descendant
            for (descendants.toSlice()) |inclusive_descendant| {
                runInsertionSteps(inclusive_descendant);
            }
        }
    }

    // Step 8: Queue a single tree mutation record for all insertions
    // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
    queueTreeMutationRecord(
        parent.allocator,
        parent,
        children,
        &[_]*NodeBase{},
        previousSibling,
        null, // nextSibling is null since we're appending at end
    );

    // Step 9: Run children changed steps once for all insertions
    runChildrenChangedSteps(parent);

    // Step 10: Run post-connection steps for all inserted nodes
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasPostConnectionStepsCallbacks()) {
        for (children) |child| {
            runPostConnectionSteps(child);
            // Recursively run for all descendants
            for (child.child_nodes.items()) |descendant| {
                runPostConnectionStepsRecursive(descendant);
            }
        }
    }
}

/// Batch Insert Children Before - Performance Optimization
///
/// Inserts multiple children before a reference child in a single operation.
/// Similar to appendChildren but inserts at a specific position.
///
/// This is useful for fragment insertion where nodes need to be inserted
/// before an existing child rather than at the end.
pub fn insertChildrenBefore(
    parent: anytype,
    children: []const *NodeBase,
    reference_child: ?*NodeBase,
) DOMException!void {
    // If reference is null, this is equivalent to appendChildren
    if (reference_child == null) {
        return appendChildren(parent, children);
    }

    const ref_child = reference_child.?;

    // Early exit if no children to insert
    if (children.len == 0) return;

    // Validate reference child's parent
    if (ref_child.parent_node != @as(*NodeBase, @ptrCast(parent))) {
        return error.NotFoundError;
    }

    // Validate parent is a valid container
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // Get insertion index
    const insert_idx = getChildIndex(ref_child) orelse return error.NotFoundError;

    // Validate and adopt all children
    for (children) |child| {
        if (isHostIncludingInclusiveAncestor(child, parent)) {
            return error.HierarchyRequestError;
        }
        if (!isDocumentFragment(child) and !isDocumentType(child) and
            !isElement(child) and !isCharacterData(child))
        {
            return error.HierarchyRequestError;
        }
        if (isText(child) and isDocument(parent)) {
            return error.HierarchyRequestError;
        }
        if (child.parent_node != null) {
            try remove(child, true);
        }
        if (parent.owner_document) |doc| {
            try adopt(child, doc);
        }
    }

    // Get previous sibling for mutation record
    var previousSibling: ?*NodeBase = null;
    if (insert_idx > 0) {
        previousSibling = parent.child_nodes.items()[insert_idx - 1];
    }

    // Insert children one by one at the correct position
    // Note: We insert in reverse order so the final order is correct
    var i: usize = children.len;
    while (i > 0) {
        i -= 1;
        try parent.child_nodes.insert(insert_idx, children[i]);
        children[i].parent_node = @ptrCast(parent);
    }

    // Phase 2: Update sibling pointers for inserted children
    // After insertion, children are at indices [insert_idx, insert_idx + children.len)
    // They need to be linked together and connected to surrounding nodes
    if (children.len > 0) {
        const first_inserted = children[0];
        const last_inserted = children[children.len - 1];

        // Connect first inserted to previous sibling
        first_inserted.previous_sibling = previousSibling;
        if (previousSibling) |prev| {
            prev.next_sibling = first_inserted;
        } else {
            // First inserted becomes first child
            parent.first_child = first_inserted;
        }

        // Connect last inserted to reference child (next sibling)
        last_inserted.next_sibling = ref_child;
        ref_child.previous_sibling = last_inserted;

        // Link inserted children together (forward pass)
        var prev_child: ?*NodeBase = null;
        for (children) |child| {
            if (prev_child) |prev| {
                prev.next_sibling = child;
                child.previous_sibling = prev;
            }
            prev_child = child;
        }
    }

    // Update live ranges
    if (parent.owner_document) |doc| {
        updateRangesForInsertionWithCount(doc, parent, insert_idx, children.len);
    }

    // Run insertion steps for all inserted nodes
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasInsertionStepsCallbacks()) {
        for (children) |child| {
            var descendants = tree_helpers.getShadowIncludingInclusiveDescendants(
                parent.allocator,
                child,
            ) catch {
                runInsertionSteps(child);
                for (child.child_nodes.items()) |descendant| {
                    runInsertionStepsRecursive(descendant);
                }
                continue;
            };
            defer descendants.deinit();

            for (descendants.toSlice()) |inclusive_descendant| {
                runInsertionSteps(inclusive_descendant);
            }
        }
    }

    // Queue single mutation record
    // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
    queueTreeMutationRecord(
        parent.allocator,
        parent,
        children,
        &[_]*NodeBase{},
        previousSibling,
        ref_child,
    );

    // Run children changed steps once
    runChildrenChangedSteps(parent);

    // Run post-connection steps
    // OPTIMIZATION: Skip expensive descendant traversal if no callbacks registered.
    if (hasPostConnectionStepsCallbacks()) {
        for (children) |child| {
            runPostConnectionSteps(child);
            for (child.child_nodes.items()) |descendant| {
                runPostConnectionStepsRecursive(descendant);
            }
        }
    }
}

/// DOM §4.2.5 - Replace
/// Spec: https://dom.spec.whatwg.org/#concept-node-replace
///
/// Steps are similar to pre-insert but with additional validation
/// and removal of the old child
pub fn replace(
    child: anytype,
    node: anytype,
    parent: anytype,
) DOMException!@TypeOf(child) {
    // Step 1: If parent is not Document, DocumentFragment, or Element, throw HierarchyRequestError
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 2: If node is host-including inclusive ancestor of parent, throw HierarchyRequestError
    if (isHostIncludingInclusiveAncestor(node, parent)) {
        return error.HierarchyRequestError;
    }

    // Step 3: If child's parent is not parent, throw NotFoundError
    if (child.parent_node != parent) {
        return error.NotFoundError;
    }

    // Step 4: Check node is valid type
    if (!isDocumentFragment(node) and !isDocumentType(node) and
        !isElement(node) and !isCharacterData(node))
    {
        return error.HierarchyRequestError;
    }

    // Step 5: Check Text/doctype constraints
    if (isText(node) and isDocument(parent)) {
        return error.HierarchyRequestError;
    }
    if (isDocumentType(node) and !isDocument(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 6: If parent is document, check additional constraints
    if (isDocument(parent)) {
        if (isDocumentFragment(node)) {
            const element_count = countElementChildren(node);

            if (element_count > 1 or hasTextChild(node)) {
                return error.HierarchyRequestError;
            }

            if (element_count == 1) {
                if (hasElementChild(parent, child) or isDoctypeFollowing(parent, child)) {
                    return error.HierarchyRequestError;
                }
            }
        } else if (isElement(node)) {
            if (hasElementChild(parent, child) or isDoctypeFollowing(parent, child)) {
                return error.HierarchyRequestError;
            }
        } else if (isDocumentType(node)) {
            if (hasDoctypeChild(parent) or isElementPreceding(parent, child)) {
                return error.HierarchyRequestError;
            }
        }
    }

    // Step 7: Let referenceChild be child's next sibling
    var referenceChild: ?*NodeBase = null;
    const child_idx = getChildIndex(child);
    if (child_idx) |idx| {
        if (idx + 1 < parent.child_nodes.size()) {
            referenceChild = parent.child_nodes.items()[idx + 1];
        }
    }

    // Step 8: If referenceChild is node, set referenceChild to node's next sibling
    if (referenceChild != null and referenceChild.? == node) {
        const node_idx = getChildIndex(node);
        if (node_idx) |idx| {
            if (node.parent_node) |node_parent| {
                if (idx + 1 < node_parent.child_nodes.size()) {
                    referenceChild = node_parent.child_nodes.items()[idx + 1];
                } else {
                    referenceChild = null;
                }
            }
        }
    }

    // Step 9: Let previousSibling be child's previous sibling
    var previousSibling: ?*NodeBase = null;
    if (child_idx) |idx| {
        if (idx > 0) {
            previousSibling = parent.child_nodes.items()[idx - 1];
        }
    }

    // Step 10-11: Remove child if its parent is non-null
    var removedNodes: [1]*NodeBase = undefined;
    var removed_count: usize = 0;

    if (child.parent_node != null) {
        removedNodes[0] = child;
        removed_count = 1;
        try remove(child, true); // suppress observers
    }

    // Step 12: Let nodes be node's children if DocumentFragment, otherwise « node »
    var added_nodes: []*NodeBase = undefined;
    var added_nodes_buf: [256]*NodeBase = undefined;
    var added_count: usize = 0;

    if (isDocumentFragment(node)) {
        added_nodes = node.child_nodes.toSliceMut();
        added_count = added_nodes.len;
    } else {
        added_nodes_buf[0] = node;
        added_nodes = added_nodes_buf[0..1];
        added_count = 1;
    }

    // Step 13: Insert node into parent before referenceChild with suppress observers
    try insert(node, parent, referenceChild, true);

    // Step 14: Queue a tree mutation record
    // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
    queueTreeMutationRecord(
        parent.allocator,
        parent,
        added_nodes[0..added_count],
        removedNodes[0..removed_count],
        previousSibling,
        referenceChild,
    );

    // Step 15: Return child
    return child;
}

/// DOM §4.2.5 - Replace all
/// Spec: https://dom.spec.whatwg.org/#concept-node-replace-all
///
/// This algorithm removes all children and inserts node (if non-null)
pub fn replaceAll(
    node: anytype,
    parent: anytype,
) DOMException!void {
    const allocator = parent.allocator;

    // Step 1: Let removedNodes be parent's children
    const removed_count = parent.child_nodes.size();
    var removed_nodes_buf: [256]*NodeBase = undefined;
    var removed_nodes: []const *NodeBase = &[_]*NodeBase{};

    if (removed_count > 0) {
        if (removed_count <= removed_nodes_buf.len) {
            for (parent.child_nodes.items(), 0..) |child, i| {
                removed_nodes_buf[i] = child;
            }
            removed_nodes = removed_nodes_buf[0..removed_count];
        }
    }

    // Step 2-4: Determine addedNodes
    var added_nodes: []const *NodeBase = &[_]*NodeBase{};
    var added_nodes_buf: [256]*NodeBase = undefined;
    var added_count: usize = 0;

    if (node) |n| {
        if (isDocumentFragment(n)) {
            added_nodes = n.child_nodes.items();
            added_count = added_nodes.len;
        } else {
            const node_ptr: *NodeBase = @ptrCast(n);
            added_nodes_buf[0] = node_ptr;
            added_nodes = added_nodes_buf[0..1];
            added_count = 1;
        }
    }

    // Step 5: Remove all parent's children in tree order with suppress observers
    while (parent.child_nodes.size() > 0) {
        const child_to_remove = parent.child_nodes.items()[0];
        try remove(child_to_remove, true);
    }

    // Step 6: If node is non-null, insert node into parent before null with suppress observers
    if (node) |n| {
        try insert(n, parent, null, true);
    }

    // Step 7: Queue a tree mutation record if addedNodes or removedNodes is not empty
    if (added_count > 0 or removed_count > 0) {
        // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
        queueTreeMutationRecord(
            allocator,
            parent,
            added_nodes[0..added_count],
            removed_nodes[0..removed_count],
            null,
            null,
        );
    }
}

/// DOM §4.2.5 - Pre-remove
/// Spec: https://dom.spec.whatwg.org/#concept-node-pre-remove
///
/// Steps:
/// 1. If child's parent is not parent, then throw NotFoundError
/// 2. Remove child
/// 3. Return child
pub fn preRemove(
    child: anytype,
    parent: anytype,
) (DOMException || error{OutOfMemory})!@TypeOf(child) {
    // Step 1: If child's parent is not parent, throw NotFoundError
    if (child.parent_node != parent) {
        return error.NotFoundError;
    }

    // Step 2: Remove child
    try remove(child, false);

    // Step 3: Return child
    return child;
}

/// DOM §4.2.5 - Remove
/// Spec: https://dom.spec.whatwg.org/#concept-node-remove
///
/// This handles all the complex removal logic including:
/// - Live range updates
/// - NodeIterator updates
/// - Slot assignment
/// - Removing steps callbacks
/// - Custom element disconnection
/// - Mutation observer notifications
pub fn remove(
    node: anytype,
    suppress_observers: bool,
) (DOMException || error{OutOfMemory})!void {
    // Step 1: Let parent be node's parent
    const parent = node.parent_node orelse {
        // Step 2: Assert parent is non-null
        // If parent is null, this is an error in the algorithm usage
        return error.HierarchyRequestError;
    };

    // Step 3: Run the live range pre-remove steps
    runLiveRangePreRemoveSteps(node);

    // Step 4: For each NodeIterator, run pre-remove steps
    runNodeIteratorPreRemoveSteps(node);

    // Step 5: Let oldPreviousSibling be node's previous sibling
    var oldPreviousSibling: ?*NodeBase = null;
    const node_idx = getChildIndex(node);
    if (node_idx) |idx| {
        if (idx > 0) {
            oldPreviousSibling = parent.child_nodes.items()[idx - 1];
        }
    }

    // Step 6: Let oldNextSibling be node's next sibling
    var oldNextSibling: ?*NodeBase = null;
    if (node_idx) |idx| {
        if (idx + 1 < parent.child_nodes.size()) {
            oldNextSibling = parent.child_nodes.items()[idx + 1];
        }
    }

    // Step 7: Remove node from its parent's children
    // Phase 2: Update sibling pointers BEFORE removing from list
    if (node.previous_sibling) |prev| {
        prev.next_sibling = node.next_sibling;
    } else {
        // node was first child
        parent.first_child = node.next_sibling;
    }

    if (node.next_sibling) |next| {
        next.previous_sibling = node.previous_sibling;
    } else {
        // node was last child
        parent.last_child = node.previous_sibling;
    }

    // Clear node's sibling pointers
    node.previous_sibling = null;
    node.next_sibling = null;

    // Remove from child_nodes list
    if (node_idx) |idx| {
        _ = parent.child_nodes.remove(idx) catch unreachable; // idx is guaranteed valid by getChildIndex
    }
    node.parent_node = null;

    // Update is_connected for the removed node and all its descendants
    // A removed node is no longer connected to the document tree
    setConnectedRecursive(node, false);

    // Step 8-10: Shadow DOM slot assignment
    // TODO: Implement when shadow DOM is fully integrated

    // Step 11: Run the removing steps with node and parent
    // Spec: DOM §4.2.5 - Specifications may define removing steps
    runRemovingSteps(node, parent);

    // Step 12: Let isParentConnected be parent's connected
    // const isParentConnected = parent.isConnected();

    // TODO: Step 13 - If node is custom and isParentConnected is true,
    // enqueue disconnectedCallback

    // Step 14: For each shadow-including descendant of node,
    // in shadow-including tree order, run removing steps
    // Spec: DOM §4.2.5 step 14
    if (tree_helpers.getShadowIncludingDescendants(parent.allocator, node)) |descendants| {
        var mut_descendants = descendants;
        defer mut_descendants.deinit();

        // Step 14.1: Run the removing steps with descendant and null
        // Step 14.2: Custom element disconnectedCallback
        for (mut_descendants.items()) |descendant| {
            runRemovingSteps(descendant, null);

            // TODO: If descendant is custom and isParentConnected is true,
            // enqueue disconnectedCallback reaction
        }
    } else |_| {
        // If we can't allocate for shadow-including traversal,
        // fall back to regular descendant traversal
        for (node.child_nodes.items()) |descendant| {
            runRemovingStepsRecursive(descendant, node);
        }
    }

    // Step 15: Transient registered observers
    // For each inclusive ancestor of parent that has registered observers with subtree=true,
    // create transient observers on node and its inclusive descendants
    try createTransientObserversForRemovedNode(node, parent);

    // Step 16: If suppress observers flag is unset, queue a tree mutation record
    if (!suppress_observers) {
        var removed_nodes_buf: [1]*NodeBase = undefined;
        removed_nodes_buf[0] = node;
        // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
        queueTreeMutationRecord(
            parent.allocator,
            parent,
            &[_]*NodeBase{},
            removed_nodes_buf[0..1],
            oldPreviousSibling,
            oldNextSibling,
        );
    }

    // Step 17: Run the children changed steps for parent
    runChildrenChangedSteps(parent);
}

/// DOM §4.2.5 - Move
/// Spec: https://dom.spec.whatwg.org/#concept-node-move
///
/// To move a node into a node newParent before a node-or-null child:
///
/// This is distinct from remove + insert. It preserves state and is more efficient.
/// The move algorithm is used by ParentNode.moveBefore().
///
/// Steps:
/// 1. If newParent's shadow-including root is not the same as node's shadow-including root, throw HierarchyRequestError
/// 2. If node is a host-including inclusive ancestor of newParent, throw HierarchyRequestError
/// 3. If child is non-null and its parent is not newParent, throw NotFoundError
/// 4. If node is not an Element or CharacterData node, throw HierarchyRequestError
/// 5. If node is a Text node and newParent is a document, throw HierarchyRequestError
/// 6. If newParent is a document, validate element constraints
/// 7. Let oldParent be node's parent
/// 8. Assert: oldParent is non-null
/// 9. Run the live range pre-remove steps
/// 10. Run NodeIterator pre-remove steps for all iterators
/// 11-12. Capture old siblings
/// 13. Remove node from oldParent's children
/// 14-16. Shadow DOM slot assignment
/// 17. Update live ranges in newParent (if child is non-null)
/// 18. Determine newPreviousSibling
/// 19-20. Insert node into newParent's children
/// 21-22. Shadow DOM slot assignment for newParent
/// 23. Run assign slottables for tree
/// 24. Run moving steps for all shadow-including inclusive descendants
/// 25-26. Queue tree mutation records
pub fn move(
    node: anytype,
    new_parent: anytype,
    child: anytype,
) DOMException!void {
    // Step 1: If newParent's shadow-including root is not the same as node's shadow-including root,
    // throw HierarchyRequestError
    const node_root = getShadowIncludingRoot(node);
    const new_parent_root = getShadowIncludingRoot(new_parent);
    if (node_root != new_parent_root) {
        return DOMException.HierarchyRequestError;
    }

    // Step 2: If node is a host-including inclusive ancestor of newParent, throw HierarchyRequestError
    if (isHostIncludingInclusiveAncestor(node, new_parent)) {
        return DOMException.HierarchyRequestError;
    }

    // Step 3: If child is non-null and its parent is not newParent, throw NotFoundError
    if (child) |c| {
        if (c.parent_node != new_parent) {
            return DOMException.NotFoundError;
        }
    }

    // Step 4: If node is not an Element or CharacterData node, throw HierarchyRequestError
    if (!isElement(node) and !isCharacterData(node)) {
        return DOMException.HierarchyRequestError;
    }

    // Step 5: If node is a Text node and newParent is a document, throw HierarchyRequestError
    if (isText(node) and isDocument(new_parent)) {
        return DOMException.HierarchyRequestError;
    }

    // Step 6: If newParent is a document, validate element constraints
    if (isDocument(new_parent)) {
        if (isElement(node)) {
            // Check if newParent has an element child
            if (hasElementChild(new_parent)) {
                return DOMException.HierarchyRequestError;
            }

            // Check if child is a doctype
            if (child) |c| {
                if (isDocumentType(c)) {
                    return DOMException.HierarchyRequestError;
                }

                // Check if a doctype is following child
                if (isDoctypeFollowing(new_parent, child)) {
                    return DOMException.HierarchyRequestError;
                }
            }
        }
    }

    // Step 7: Let oldParent be node's parent
    const old_parent = node.parent_node orelse {
        // If node has no parent, this is an error (move requires node to already be in tree)
        return DOMException.HierarchyRequestError;
    };

    // Step 8: Assert: oldParent is non-null (checked above)

    // Step 9: Run the live range pre-remove steps, given node
    runLiveRangePreRemoveSteps(node);

    // Step 10: For each NodeIterator object iterator whose root's node document is node's node document,
    // run the NodeIterator pre-remove steps given node and iterator
    runNodeIteratorPreRemoveSteps(node);

    // Step 11: Let oldPreviousSibling be node's previous sibling
    const old_previous_sibling = tree_helpers.getPreviousSibling(node);

    // Step 12: Let oldNextSibling be node's next sibling
    const old_next_sibling = tree_helpers.getNextSibling(node);

    // Step 13: Remove node from oldParent's children
    removeFromChildrenList(node, old_parent);

    // Step 13.1: Run children changed steps for oldParent
    // (Node was removed from oldParent's children)
    runChildrenChangedSteps(old_parent);

    // Step 14: If node is assigned, then run assign slottables for node's assigned slot
    // TODO: Shadow DOM - check if node is assigned and run assign slottables

    // Step 15: If oldParent's root is a shadow root, and oldParent is a slot whose assigned nodes is empty,
    // then run signal a slot change for oldParent
    // TODO: Shadow DOM - implement slot change signaling

    // Step 16: If node has an inclusive descendant that is a slot:
    // TODO: Shadow DOM - run assign slottables for tree

    // Step 17: If child is non-null:
    if (child) |c| {
        const child_index = getChildIndex(c) orelse 0;

        // Get the document for range tracking
        if (new_parent.owner_document) |doc| {
            // Step 17.1: For each live range whose start node is newParent and start offset
            // is greater than child's index, increase its start offset by 1
            updateRangesForInsertion(doc, new_parent, child_index);
        }
    }

    // Step 18: Let newPreviousSibling be child's previous sibling if child is non-null,
    // and newParent's last child otherwise
    const new_previous_sibling = if (child) |c|
        tree_helpers.getPreviousSibling(c)
    else
        tree_helpers.getLastChild(new_parent);

    // Step 19: If child is null, then append node to newParent's children
    // Step 20: Otherwise, insert node into newParent's children before child's index
    insertIntoChildrenList(node, new_parent, child);

    // Step 20.1: Run children changed steps for newParent
    // (Node was added to newParent's children)
    runChildrenChangedSteps(new_parent);

    // Step 21: If newParent is a shadow host whose shadow root's slot assignment is "named"
    // and node is a slottable, then assign a slot for node
    // TODO: Shadow DOM - implement slot assignment

    // Step 22: If newParent's root is a shadow root, and newParent is a slot whose assigned nodes is empty,
    // then run signal a slot change for newParent
    // TODO: Shadow DOM - implement slot change signaling

    // Step 23: Run assign slottables for a tree with node's root
    // TODO: Shadow DOM - implement assign slottables for tree

    // Step 24: For each shadow-including inclusive descendant of node, in shadow-including tree order
    // Run moving steps (handles shadow-including traversal internally)
    runMovingStepsForTree(node, old_parent);

    // Step 25: Queue a tree mutation record for oldParent
    // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
    {
        var removed_nodes_buf: [1]*NodeBase = undefined;
        removed_nodes_buf[0] = node;
        queueTreeMutationRecord(
            new_parent.allocator,
            old_parent,
            &[_]*NodeBase{},
            removed_nodes_buf[0..1],
            old_previous_sibling,
            old_next_sibling,
        );
    }

    // Step 26: Queue a tree mutation record for newParent
    // TODO: Phase 6 (whatwg-9wkz8) - MutationObserver integration
    {
        var added_nodes_buf: [1]*NodeBase = undefined;
        added_nodes_buf[0] = node;
        queueTreeMutationRecord(
            new_parent.allocator,
            new_parent,
            added_nodes_buf[0..1],
            &[_]*NodeBase{},
            new_previous_sibling,
            child,
        );
    }
}

/// Helper: Get shadow-including root of a node
/// Spec: https://dom.spec.whatwg.org/#concept-shadow-including-root
fn getShadowIncludingRoot(node: anytype) @TypeOf(node) {
    // For now, just return regular root (shadow DOM TODO)
    return tree_helpers.getRoot(node);
}

/// Helper: Check if node is a host-including inclusive ancestor of other
/// Spec: https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor
fn isHostIncludingInclusiveAncestor(node: anytype, other: anytype) bool {
    // For now, just check inclusive ancestor (shadow DOM TODO)
    const node_ptr: *const NodeBase = @ptrCast(node);
    const other_ptr: *const NodeBase = @ptrCast(other);
    return tree_helpers.isInclusiveAncestor(node_ptr, other_ptr);
}

/// Stub: Queue tree mutation record for NodeBase nodes
///
/// TODO: MutationObserver integration is stubbed out during unified DOM tree refactoring.
/// The mutation_observer_algorithms.queueTreeMutationRecord function expects:
///   - target: *Node (WebIDL interface)
///   - added_nodes: *NodeList (WebIDL interface)
///   - removed_nodes: *NodeList (WebIDL interface)
/// Helper: Run live range pre-remove steps
/// Spec: https://dom.spec.whatwg.org/#concept-node-remove steps 4-7
fn runLiveRangePreRemoveSteps(node: anytype) void {
    // Get the node's document to access the list of live ranges
    const doc = node.owner_document orelse return;
    const doc_instance: *runtime.Instance = @ptrCast(@alignCast(doc));

    // Get the parent and index for updating boundary points
    const parent = node.parent_node orelse return;
    const index = getChildIndex(node) orelse return;

    // Access the document's internal state to get the ranges list
    const internal = document_internals.getInternal(doc_instance) orelse return;

    // Iterate through all live ranges registered with this document
    for (internal.ranges.items) |range| {
        // Get range boundary points (containers only - offsets read when needed)
        const start_container = RangeImpl.getStartContainer(range);
        const end_container = RangeImpl.getEndContainer(range);

        // Step 4: For each live range whose start node is an inclusive descendant of node,
        // set its start to (parent, index)
        if (start_container) |start_node| {
            // Get the NodeBase from the start container using instance bridge
            if (instance_bridge.getNodeBase(start_node)) |start_base| {
                const node_ptr: *const NodeBase = @ptrCast(node);
                if (tree_helpers.isInclusiveDescendant(node_ptr, start_base)) {
                    // Cast parent to runtime.Instance
                    if (instance_bridge.getInstance(parent)) |parent_instance| {
                        RangeImpl.setStartBoundary(range, @ptrCast(@alignCast(parent_instance)), @intCast(index));
                    }
                }
            }
        }

        // Step 5: For each live range whose end node is an inclusive descendant of node,
        // set its end to (parent, index)
        if (end_container) |end_node| {
            // Get the NodeBase from the end container using instance bridge
            if (instance_bridge.getNodeBase(end_node)) |end_base| {
                const node_ptr: *const NodeBase = @ptrCast(node);
                if (tree_helpers.isInclusiveDescendant(node_ptr, end_base)) {
                    // Cast parent to runtime.Instance
                    if (instance_bridge.getInstance(parent)) |parent_instance| {
                        RangeImpl.setEndBoundary(range, @ptrCast(@alignCast(parent_instance)), @intCast(index));
                    }
                }
            }
        }

        // Re-read boundary points after potential updates
        const current_start = RangeImpl.getStartContainer(range);
        const current_end = RangeImpl.getEndContainer(range);

        // Step 6: For each live range whose start node is parent and start offset is greater than index,
        // decrease its start offset by 1
        if (current_start) |start_node| {
            if (instance_bridge.getNodeBase(start_node)) |start_base| {
                if (start_base == parent) {
                    const current_start_offset = RangeImpl.getStartOffset(range);
                    if (current_start_offset > index) {
                        RangeImpl.setStartOffset(range, @intCast(current_start_offset - 1));
                    }
                }
            }
        }

        // Step 7: For each live range whose end node is parent and end offset is greater than index,
        // decrease its end offset by 1
        if (current_end) |end_node| {
            if (instance_bridge.getNodeBase(end_node)) |end_base| {
                if (end_base == parent) {
                    const current_end_offset = RangeImpl.getEndOffset(range);
                    if (current_end_offset > index) {
                        RangeImpl.setEndOffset(range, @intCast(current_end_offset - 1));
                    }
                }
            }
        }
    }
}

/// Helper: Run NodeIterator pre-remove steps for all iterators
/// Spec: https://dom.spec.whatwg.org/#nodeiterator-pre-removing-steps
fn runNodeIteratorPreRemoveSteps(node: anytype) void {
    // Get the node's document to access the list of NodeIterators
    const doc = node.owner_document orelse return;
    const doc_instance: *runtime.Instance = @ptrCast(@alignCast(doc));

    // Access the document's internal state to get the node_iterators list
    const internal = document_internals.getInternal(doc_instance) orelse return;

    // Get the node as a runtime.Instance for passing to NodeIterator.preRemoveSteps
    const node_base_ptr: *NodeBase = @ptrCast(node);
    const node_instance = instance_bridge.getInstance(node_base_ptr) orelse return;
    const node_runtime: *runtime.Instance = @ptrCast(@alignCast(node_instance));

    // For each NodeIterator object iterator whose root's node document is node's node document,
    // run the NodeIterator pre-removing steps given node and iterator.
    for (internal.node_iterators.items) |iterator| {
        NodeIteratorImpl.preRemoveSteps(iterator, node_runtime);
    }
}

/// Helper: Update ranges when inserting before child
fn updateRangesForInsertion(doc: anytype, parent: anytype, child_index: usize) void {
    updateRangesForInsertionWithCount(doc, parent, child_index, 1);
}

/// Helper: Update ranges when inserting multiple nodes before child
/// Spec: https://dom.spec.whatwg.org/#concept-node-insert step 5
/// For each live range whose start/end node is parent and offset > child_index,
/// increase offset by count
fn updateRangesForInsertionWithCount(doc: anytype, parent: anytype, child_index: usize, count: usize) void {
    // Cast document to runtime.Instance
    const doc_instance: *runtime.Instance = @ptrCast(@alignCast(doc));

    // Access the document's internal state to get the ranges list
    const internal = document_internals.getInternal(doc_instance) orelse return;

    // Get parent as a pointer for comparison
    const parent_base: *const NodeBase = @ptrCast(parent);

    // For each live range, update offsets if necessary
    for (internal.ranges.items) |range| {
        // Get range boundary points
        const start_container = RangeImpl.getStartContainer(range);
        const end_container = RangeImpl.getEndContainer(range);

        // For each live range whose start node is parent and start offset is greater than child's index,
        // increase its start offset by count.
        if (start_container) |start_node| {
            if (instance_bridge.getNodeBase(start_node)) |start_base| {
                if (start_base == parent_base) {
                    const start_offset = RangeImpl.getStartOffset(range);
                    if (start_offset > child_index) {
                        RangeImpl.setStartOffset(range, @intCast(start_offset + count));
                    }
                }
            }
        }

        // For each live range whose end node is parent and end offset is greater than child's index,
        // increase its end offset by count.
        if (end_container) |end_node| {
            if (instance_bridge.getNodeBase(end_node)) |end_base| {
                if (end_base == parent_base) {
                    const end_offset = RangeImpl.getEndOffset(range);
                    if (end_offset > child_index) {
                        RangeImpl.setEndOffset(range, @intCast(end_offset + count));
                    }
                }
            }
        }
    }
}

/// Helper: Remove node from parent's children list (without updating parent pointer)
fn removeFromChildrenList(node: anytype, parent: anytype) void {
    const node_ptr: *NodeBase = @ptrCast(node);
    // Update sibling pointers
    if (node.previous_sibling) |prev| {
        prev.next_sibling = node.next_sibling;
    } else {
        // node was first child
        const first = parent.child_nodes.items()[0];
        if (first == node_ptr) {
            if (node.next_sibling) |next| {
                parent.child_nodes.items()[0] = next;
            } else {
                // Was only child
                parent.child_nodes.clearRetainingCapacity();
                return;
            }
        }
    }

    if (node.next_sibling) |next| {
        next.previous_sibling = node.previous_sibling;
    }

    // Remove from parent's children array
    if (getChildIndex(node)) |idx| {
        _ = parent.child_nodes.remove(idx) catch unreachable; // idx is guaranteed valid by getChildIndex
    }

    // Clear node's sibling pointers (but not parent - that stays for the move)
    node.previous_sibling = null;
    node.next_sibling = null;
}

/// Helper: Insert node into parent's children list (updates parent pointer)
fn insertIntoChildrenList(node: anytype, parent: anytype, child: anytype) void {
    if (child) |c| {
        // Insert before child
        const child_idx = getChildIndex(c) orelse {
            // Child not found, append to end
            parent.child_nodes.append(node) catch return;
            node.parent_node = parent;
            node.previous_sibling = tree_helpers.getLastChild(parent);
            node.next_sibling = null;
            if (node.previous_sibling) |prev| {
                prev.next_sibling = node;
            }
            return;
        };

        // Insert at child_idx
        parent.child_nodes.insert(child_idx, node) catch return;

        // Update pointers
        node.parent_node = parent;
        node.next_sibling = c;
        node.previous_sibling = tree_helpers.getPreviousSibling(c);

        c.previous_sibling = node;
        if (node.previous_sibling) |prev| {
            prev.next_sibling = node;
        }
    } else {
        // Append to end
        parent.child_nodes.append(node) catch return;

        node.parent_node = parent;
        const last = tree_helpers.getLastChild(parent);
        node.previous_sibling = if (last == node) null else last;
        node.next_sibling = null;

        if (node.previous_sibling) |prev| {
            prev.next_sibling = node;
        }
    }
}

/// Helper: Run moving steps for node and all descendants
/// Spec: DOM §4.2.5 move algorithm step 24
/// For each shadow-including inclusive descendant, run moving steps
fn runMovingStepsForTree(node: *NodeBase, old_parent: *NodeBase) void {
    // Step 24: For each shadow-including inclusive descendant of node,
    // in shadow-including tree order

    // Try to use shadow-including traversal
    if (tree_helpers.getShadowIncludingInclusiveDescendants(
        node.allocator,
        node,
    )) |descendants| {
        defer descendants.deinit();

        // Step 24.1: If inclusiveDescendant is node, run moving steps with oldParent
        // Otherwise, run moving steps with null
        for (descendants.items, 0..) |descendant, i| {
            if (i == 0) {
                // First item is node itself
                runMovingSteps(descendant, old_parent);
            } else {
                // All other descendants get null
                runMovingSteps(descendant, null);
            }

            // Step 24.2: If inclusiveDescendant is custom and newParent is connected,
            // enqueue connectedMoveCallback reaction
            // Note: This is handled via moving steps callbacks (see registerMovingStepsCallback)
            // Custom element implementations should register a callback that checks:
            // - if (node.is_custom_element() and node.parent_node.?.root().is_connected()) {
            //     enqueue_connected_move_callback_reaction(node, old_parent);
            // }
        }
    } else |_| {
        // Fallback to regular tree traversal if shadow-including fails
        // Run moving steps for node itself with oldParent
        runMovingSteps(node, old_parent);

        // Run moving steps for all descendants with null
        var stack = infra.List(*NodeBase).init(node.allocator);
        defer stack.deinit();

        for (node.child_nodes.items()) |child| {
            stack.append(child) catch continue;
        }

        while (stack.len > 0) {
            const current = stack.get(stack.len - 1) orelse break;
            _ = stack.remove(stack.len - 1) catch break;
            runMovingSteps(current, null);

            // Add children to stack
            for (current.child_nodes.items()) |child| {
                stack.append(child) catch continue;
            }
        }
    }
}

/// Helper: Run moving steps hook for a node
/// Spec: Moving steps are defined by specifications
/// Called during the move algorithm for each shadow-including descendant
fn runMovingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    if (moving_steps_callbacks) |*callbacks| {
        for (callbacks.items()) |callback| {
            callback(node, old_parent);
        }
    }
}

/// DOM §4.2.5 - Adopt
/// Spec: https://dom.spec.whatwg.org/#concept-node-adopt
///
/// To adopt a node into a document:
/// 1. Let oldDocument be node's node document
/// 2. If node's parent is non-null, then remove node
/// 3. If document is not oldDocument:
///    a. For each shadow-including inclusive descendant:
///       - Set its node document to document
///       - If element, update attribute node documents
///    b. For each shadow-including inclusive descendant that is custom:
///       - Enqueue adoptedCallback reaction (future)
///    c. Run adopting steps for each descendant (future)
pub fn adopt(
    node: anytype,
    document: anytype,
) DOMException!void {
    // Step 1: Let oldDocument be node's node document
    const oldDocument = node.owner_document;

    // Step 2: If node's parent is non-null, then remove node
    if (node.parent_node != null) {
        try remove(node, false);
    }

    // Step 3: If document is not oldDocument
    if (document != oldDocument) {
        // Step 3.1: For each inclusiveDescendant in node's shadow-including inclusive descendants
        // For now, just update node itself and tree descendants (shadow DOM TODO)

        // Collect all descendants first
        var descendants = infra.List(*NodeBase).init(node.allocator);
        defer descendants.deinit();

        try descendants.append(node);

        var i: usize = 0;
        while (i < descendants.len) : (i += 1) {
            const current = descendants.get(i) orelse continue;

            // Add children
            for (current.child_nodes.items()) |child| {
                try descendants.append(child);
            }
        }

        // Step 3.1: For each shadow-including inclusive descendant in tree order
        for (0..descendants.len) |idx| {
            const desc = descendants.get(idx) orelse continue;

            // Step 3.1.1: Set node document to document
            desc.owner_document = document;

            // Step 3.1.2: If element, update attribute node documents
            if (desc.node_type == ELEMENT_NODE) {
                // Access element attributes via ElementWithBase if available
                // Cast to ElementWithBase since elements have NodeBase as first field
                const element = @as(*element_with_base.ElementWithBase, @ptrCast(desc));
                for (0..element.attributes.size()) |attr_idx| {
                    if (element.attributes.get(attr_idx)) |attr| {
                        attr.base.owner_document = document;
                    }
                }
            }
        }

        // Step 3.2: Enqueue custom element adoptedCallback for custom elements
        // TODO(HTML): Check if element is custom and enqueue adoptedCallback
        // For now, this is a no-op since we don't have custom elements

        // Step 3.3: Run adopting steps for each inclusive descendant
        // TODO(HTML): Adopting steps are an extension point for other specs
        // This would call HTML custom element adoption steps
        // For now, this is a no-op
    }
}
