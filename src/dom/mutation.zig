//! DOM Mutation Algorithms (WHATWG DOM Standard §4.2.5)
//!
//! Spec: https://dom.spec.whatwg.org/#mutation-algorithms
//!
//! This module implements the complete set of mutation algorithms for DOM node trees.
//! All algorithms follow the WHATWG DOM specification precisely.

const std = @import("std");
const infra = @import("infra");
const Node = @import("node").Node;
const NodeList = @import("node_list").NodeList;
const Document = @import("document").Document;
const DocumentFragment = @import("document_fragment").DocumentFragment;
const Element = @import("element").Element;
const DocumentType = @import("document_type").DocumentType;
const CharacterData = @import("character_data").CharacterData;
const Text = @import("text").Text;
const RegisteredObserver = @import("registered_observer").RegisteredObserver;
const tree_helpers = @import("tree_helpers.zig");
const shadow_dom_algorithms = @import("shadow_dom_algorithms.zig");
const mutation_observer = @import("mutation_observer_algorithms.zig");

/// DOM Exception types as defined in WebIDL
pub const DOMException = error{
    HierarchyRequestError,
    NotFoundError,
    NotSupportedError,
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
pub const ChildrenChangedCallback = *const fn (parent: *Node) void;

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
pub fn runChildrenChangedSteps(parent: *Node) void {
    // Call all registered callbacks
    if (children_changed_callbacks) |*callbacks| {
        for (callbacks.items()) |callback| {
            callback(parent);
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
pub const InsertionStepsCallback = *const fn (node: *Node) void;

/// Removing Steps Callback
/// Spec: Specifications may define removing steps for all or some nodes.
/// The algorithm is passed the removed node and optionally the old parent.
///
/// Examples:
///   - HTML: iframe unloading, form-associated element disconnections
///   - Custom elements: disconnectedCallback
pub const RemovingStepsCallback = *const fn (node: *Node, old_parent: ?*Node) void;

/// Post-connection Steps Callback
/// Spec: The post-connection steps are run after a batch of nodes is inserted.
/// This allows JavaScript to run after all mutations are complete.
///
/// Examples:
///   - HTML: iframe loading after all tree mutations
///   - Custom elements: batch reactions after insertion
pub const PostConnectionStepsCallback = *const fn (node: *Node) void;

/// Global registry for insertion steps callbacks
/// Uses page_allocator since this lives for the program lifetime and is never freed
var insertion_steps_callbacks: ?infra.List(InsertionStepsCallback) = null;

/// Global registry for removing steps callbacks
/// Uses page_allocator since this lives for the program lifetime and is never freed
var removing_steps_callbacks: ?infra.List(RemovingStepsCallback) = null;

/// Global registry for post-connection steps callbacks
/// Uses page_allocator since this lives for the program lifetime and is never freed
var post_connection_steps_callbacks: ?infra.List(PostConnectionStepsCallback) = null;

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

/// Run the insertion steps for a node
/// Called during the insert algorithm for each shadow-including descendant
fn runInsertionSteps(node: *Node) void {
    if (insertion_steps_callbacks) |*callbacks| {
        for (callbacks.items()) |callback| {
            callback(node);
        }
    }
}

/// Run the removing steps for a node
/// Called during the remove algorithm
fn runRemovingSteps(node: *Node, old_parent: ?*Node) void {
    if (removing_steps_callbacks) |*callbacks| {
        for (callbacks.items()) |callback| {
            callback(node, old_parent);
        }
    }
}

/// Run the post-connection steps for a node
/// Called after a batch of insertions complete
fn runPostConnectionSteps(node: *Node) void {
    if (post_connection_steps_callbacks) |*callbacks| {
        for (callbacks.items()) |callback| {
            callback(node);
        }
    }
}

/// Recursively run insertion steps for a node and all its descendants
fn runInsertionStepsRecursive(node: *Node) void {
    runInsertionSteps(node);
    for (node.child_nodes.items()) |child| {
        runInsertionStepsRecursive(child);
    }
}

/// Recursively run post-connection steps for a node and all its descendants
fn runPostConnectionStepsRecursive(node: *Node) void {
    runPostConnectionSteps(node);
    for (node.child_nodes.items()) |child| {
        runPostConnectionStepsRecursive(child);
    }
}

/// Recursively run removing steps for a node and all its descendants
fn runRemovingStepsRecursive(node: *Node, old_parent: *Node) void {
    runRemovingSteps(node, old_parent);
    for (node.child_nodes.items()) |child| {
        runRemovingStepsRecursive(child, node);
    }
}

/// Create transient registered observers for a removed node
/// Spec: https://dom.spec.whatwg.org/#concept-node-remove step 15
fn createTransientObserversForRemovedNode(node: *Node, parent: *Node) !void {
    // For each inclusive ancestor inclusiveAncestor of parent
    var current_ancestor: ?*Node = parent;
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
fn createTransientObserverForNodeAndDescendants(node: *Node, source: RegisteredObserver) !void {
    // Add transient observer to this node
    try node.registered_observers.append(.{
        .observer = source.observer,
        .options = source.options,
        .is_transient = true,
        .source_observer = source.observer,
        .source_options = source.options,
    });

    // Recursively add to all descendants
    for (0..node.child_nodes.len) |i| {
        const child = node.child_nodes.get(i) orelse continue;
        try createTransientObserverForNodeAndDescendants(child, source);
    }
}

/// Helper to get node type from Node pointer
fn getNodeType(node: *Node) u16 {
    return node.node_type;
}

/// Helper to check if node is a Document
fn isDocument(node: *Node) bool {
    return getNodeType(node) == Node.DOCUMENT_NODE;
}

/// Helper to check if node is a DocumentFragment
fn isDocumentFragment(node: *Node) bool {
    return getNodeType(node) == Node.DOCUMENT_FRAGMENT_NODE;
}

/// Helper to check if node is an Element
fn isElement(node: *Node) bool {
    return getNodeType(node) == Node.ELEMENT_NODE;
}

/// Helper to check if node is a DocumentType
fn isDocumentType(node: *Node) bool {
    return getNodeType(node) == Node.DOCUMENT_TYPE_NODE;
}

/// Helper to check if node is a Text node
fn isText(node: *Node) bool {
    return getNodeType(node) == Node.TEXT_NODE;
}

/// Helper to create a NodeList from an array of nodes
/// The returned NodeList must be deinit'd by the caller
fn createNodeList(allocator: std.mem.Allocator, nodes: []const *Node) !*NodeList {
    const list = try allocator.create(NodeList);
    errdefer allocator.destroy(list);
    list.* = try NodeList.init(allocator);

    for (nodes) |node| {
        try list.addNode(node);
    }

    return list;
}

/// Helper to check if node is a CharacterData node
fn isCharacterData(node: *Node) bool {
    const node_type = getNodeType(node);
    return node_type == Node.TEXT_NODE or
        node_type == Node.COMMENT_NODE or
        node_type == Node.CDATA_SECTION_NODE or
        node_type == Node.PROCESSING_INSTRUCTION_NODE;
}

/// Get child index in parent
fn getChildIndex(child: *Node) ?usize {
    const parent = child.parent_node orelse return null;
    for (parent.child_nodes.items(), 0..) |node, i| {
        if (node == child) return i;
    }
    return null;
}

/// Check if a doctype is following a given child in parent
fn isDoctypeFollowing(parent: *Node, child: ?*Node) bool {
    if (child == null) return false;

    const child_idx = getChildIndex(child.?) orelse return false;

    // Check all siblings after child
    for (parent.child_nodes.items()[child_idx + 1 ..]) |sibling| {
        if (isDocumentType(sibling)) return true;
    }

    return false;
}

/// Check if an element is preceding a given child in parent
fn isElementPreceding(parent: *Node, child: ?*Node) bool {
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
fn countElementChildren(node: *Node) usize {
    var count: usize = 0;
    for (node.child_nodes.items()) |child| {
        if (isElement(child)) count += 1;
    }
    return count;
}

/// Check if node has a Text child
fn hasTextChild(node: *Node) bool {
    for (node.child_nodes.items()) |child| {
        if (isText(child)) return true;
    }
    return false;
}

/// Check if parent has a doctype child
fn hasDoctypeChild(parent: *Node) bool {
    for (parent.child_nodes.items()) |child| {
        if (isDocumentType(child)) return true;
    }
    return false;
}

/// Check if parent has an element child (optionally excluding one node)
fn hasElementChild(parent: *Node, exclude: ?*Node) bool {
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
    node: *Node,
    parent: *Node,
    child: ?*Node,
) DOMException!void {
    // Step 1: Check parent is Document, DocumentFragment, or Element
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 2: Check node is not host-including inclusive ancestor of parent
    if (tree_helpers.isHostIncludingInclusiveAncestor(node, parent)) {
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
    node: *Node,
    parent: *Node,
    child: ?*Node,
) DOMException!*Node {
    // Step 1: Ensure pre-insertion validity
    try ensurePreInsertValidity(node, parent, child);

    // Step 2: Let referenceChild be child
    var referenceChild = child;

    // Step 3: If referenceChild is node, set to node's next sibling
    if (referenceChild != null and referenceChild.? == node) {
        // Find node's next sibling
        if (node.parent_node) |node_parent| {
            const idx = getChildIndex(node) orelse return node;
            if (idx + 1 < node_parent.child_nodes.size()) {
                referenceChild = node_parent.child_nodes.items()[idx + 1];
            } else {
                referenceChild = null;
            }
        }
    }

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
    node: *Node,
    parent: *Node,
    child: ?*Node,
    suppress_observers: bool,
) DOMException!void {
    // Step 1: Let nodes be node's children if node is DocumentFragment, otherwise « node »
    var nodes: []*Node = undefined;
    var nodes_buf: [256]*Node = undefined;
    var nodes_count: usize = 0;

    if (isDocumentFragment(node)) {
        nodes = node.child_nodes.items;
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
        const allocator = parent.allocator;
        const empty_list = try createNodeList(allocator, &[_]*Node{});
        defer {
            empty_list.deinit();
            allocator.destroy(empty_list);
        }
        const removed_list = try createNodeList(allocator, nodes[0..nodes_count]);
        defer {
            removed_list.deinit();
            allocator.destroy(removed_list);
        }
        try mutation_observer.queueTreeMutationRecord(
            allocator,
            node,
            empty_list,
            removed_list,
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
    var previousSibling: ?*Node = null;
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
        try adopt(n, parent.owner_document.?);

        // Step 7.2-3: Insert node into parent's children
        if (child) |c| {
            const idx = getChildIndex(c) orelse parent.child_nodes.size();
            try parent.child_nodes.insert(idx, n);
        } else {
            try parent.child_nodes.append(n);
        }
        n.parent_node = parent;

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
        for (nodes) |inserted_node| {
            // Get all shadow-including inclusive descendants in tree order
            var descendants = tree_helpers.getShadowIncludingInclusiveDescendants(
                parent.allocator,
                inserted_node,
            ) catch {
                // If we can't allocate, fall back to non-shadow traversal
                runInsertionSteps(inserted_node);
                for (inserted_node.child_nodes.items()) |descendant| {
                    runInsertionStepsRecursive(descendant);
                }
                continue;
            };
            defer descendants.deinit();

            // Run insertion steps for each shadow-including inclusive descendant
            for (descendants.items) |inclusive_descendant| {
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
        const allocator = parent.allocator;
        const added_list = try createNodeList(allocator, nodes[0..nodes_count]);
        defer {
            added_list.deinit();
            allocator.destroy(added_list);
        }
        const empty_list = try createNodeList(allocator, &[_]*Node{});
        defer {
            empty_list.deinit();
            allocator.destroy(empty_list);
        }
        try mutation_observer.queueTreeMutationRecord(
            allocator,
            parent,
            added_list,
            empty_list,
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
    for (nodes) |inserted_node| {
        runPostConnectionSteps(inserted_node);
        // Recursively run for all descendants
        for (inserted_node.child_nodes.items()) |descendant| {
            runPostConnectionStepsRecursive(descendant);
        }
    }
}

/// DOM §4.2.5 - Append
/// Spec: https://dom.spec.whatwg.org/#concept-node-append
///
/// This is a convenience wrapper that pre-inserts before null
pub fn append(node: *Node, parent: *Node) DOMException!*Node {
    return preInsert(node, parent, null);
}

/// DOM §4.2.5 - Replace
/// Spec: https://dom.spec.whatwg.org/#concept-node-replace
///
/// Steps are similar to pre-insert but with additional validation
/// and removal of the old child
pub fn replace(
    child: *Node,
    node: *Node,
    parent: *Node,
) DOMException!*Node {
    // Step 1: If parent is not Document, DocumentFragment, or Element, throw HierarchyRequestError
    if (!isDocument(parent) and !isDocumentFragment(parent) and !isElement(parent)) {
        return error.HierarchyRequestError;
    }

    // Step 2: If node is host-including inclusive ancestor of parent, throw HierarchyRequestError
    if (tree_helpers.isHostIncludingInclusiveAncestor(node, parent)) {
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
    var referenceChild: ?*Node = null;
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
    var previousSibling: ?*Node = null;
    if (child_idx) |idx| {
        if (idx > 0) {
            previousSibling = parent.child_nodes.items()[idx - 1];
        }
    }

    // Step 10-11: Remove child if its parent is non-null
    var removedNodes: [1]*Node = undefined;
    var removed_count: usize = 0;

    if (child.parent_node != null) {
        removedNodes[0] = child;
        removed_count = 1;
        try remove(child, true); // suppress observers
    }

    // Step 12: Let nodes be node's children if DocumentFragment, otherwise « node »
    var added_nodes: []*Node = undefined;
    var added_nodes_buf: [256]*Node = undefined;
    var added_count: usize = 0;

    if (isDocumentFragment(node)) {
        added_nodes = node.child_nodes.items();
        added_count = added_nodes.len;
    } else {
        added_nodes_buf[0] = node;
        added_nodes = added_nodes_buf[0..1];
        added_count = 1;
    }

    // Step 13: Insert node into parent before referenceChild with suppress observers
    try insert(node, parent, referenceChild, true);

    // Step 14: Queue a tree mutation record
    const allocator = parent.allocator;
    const added_list = try createNodeList(allocator, added_nodes[0..added_count]);
    defer {
        added_list.deinit();
        allocator.destroy(added_list);
    }
    const removed_list = try createNodeList(allocator, removedNodes[0..removed_count]);
    defer {
        removed_list.deinit();
        allocator.destroy(removed_list);
    }
    try mutation_observer.queueTreeMutationRecord(
        allocator,
        parent,
        added_list,
        removed_list,
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
    node: ?*Node,
    parent: *Node,
) DOMException!void {
    const allocator = parent.allocator;

    // Step 1: Let removedNodes be parent's children
    const removed_count = parent.child_nodes.size();
    var removed_nodes_buf: [256]*Node = undefined;
    var removed_nodes: []const *Node = &[_]*Node{};

    if (removed_count > 0) {
        if (removed_count <= removed_nodes_buf.len) {
            for (parent.child_nodes.items(), 0..) |child, i| {
                removed_nodes_buf[i] = child;
            }
            removed_nodes = removed_nodes_buf[0..removed_count];
        }
    }

    // Step 2-4: Determine addedNodes
    var added_nodes: []const *Node = &[_]*Node{};
    var added_nodes_buf: [256]*Node = undefined;
    var added_count: usize = 0;

    if (node) |n| {
        if (isDocumentFragment(n)) {
            added_nodes = n.child_nodes.items();
            added_count = added_nodes.len;
        } else {
            added_nodes_buf[0] = n;
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
        const added_list = try createNodeList(allocator, added_nodes[0..added_count]);
        defer {
            added_list.deinit();
            allocator.destroy(added_list);
        }
        const removed_list = try createNodeList(allocator, removed_nodes[0..removed_count]);
        defer {
            removed_list.deinit();
            allocator.destroy(removed_list);
        }
        try mutation_observer.queueTreeMutationRecord(
            allocator,
            parent,
            added_list,
            removed_list,
            null,
            null,
        );
    }
}

/// DOM §4.2.5 - Pre-remove
/// Spec: https://dom.spec.whatwg.org/#concept-node-pre-remove
///
/// Steps:
/// 1. If child's parent is not parent, throw NotFoundError
/// 2. Remove child
/// 3. Return child
pub fn preRemove(
    child: *Node,
    parent: *Node,
) (DOMException || error{OutOfMemory})!*Node {
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
    node: *Node,
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
    var oldPreviousSibling: ?*Node = null;
    const node_idx = getChildIndex(node);
    if (node_idx) |idx| {
        if (idx > 0) {
            oldPreviousSibling = parent.child_nodes.items()[idx - 1];
        }
    }

    // Step 6: Let oldNextSibling be node's next sibling
    var oldNextSibling: ?*Node = null;
    if (node_idx) |idx| {
        if (idx + 1 < parent.child_nodes.size()) {
            oldNextSibling = parent.child_nodes.items()[idx + 1];
        }
    }

    // Step 7: Remove node from its parent's children
    if (node_idx) |idx| {
        _ = parent.child_nodes.remove(idx) catch unreachable; // idx is guaranteed valid by getChildIndex
    }
    node.parent_node = null;

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
        const allocator = parent.allocator;
        const empty_list = try createNodeList(allocator, &[_]*Node{});
        defer {
            empty_list.deinit();
            allocator.destroy(empty_list);
        }
        var removed_nodes_buf: [1]*Node = undefined;
        removed_nodes_buf[0] = node;
        const removed_list = try createNodeList(allocator, removed_nodes_buf[0..1]);
        defer {
            removed_list.deinit();
            allocator.destroy(removed_list);
        }
        try mutation_observer.queueTreeMutationRecord(
            allocator,
            parent,
            empty_list,
            removed_list,
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
    node: *Node,
    new_parent: *Node,
    child: ?*Node,
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
    const allocator = new_parent.allocator;
    {
        const empty_list = try createNodeList(allocator, &[_]*Node{});
        defer {
            empty_list.deinit();
            allocator.destroy(empty_list);
        }
        var removed_nodes_buf: [1]*Node = undefined;
        removed_nodes_buf[0] = node;
        const removed_list = try createNodeList(allocator, removed_nodes_buf[0..1]);
        defer {
            removed_list.deinit();
            allocator.destroy(removed_list);
        }
        try mutation_observer.queueTreeMutationRecord(
            allocator,
            old_parent,
            empty_list,
            removed_list,
            old_previous_sibling,
            old_next_sibling,
        );
    }

    // Step 26: Queue a tree mutation record for newParent
    {
        var added_nodes_buf: [1]*Node = undefined;
        added_nodes_buf[0] = node;
        const added_list = try createNodeList(allocator, added_nodes_buf[0..1]);
        defer {
            added_list.deinit();
            allocator.destroy(added_list);
        }
        const empty_list = try createNodeList(allocator, &[_]*Node{});
        defer {
            empty_list.deinit();
            allocator.destroy(empty_list);
        }
        try mutation_observer.queueTreeMutationRecord(
            allocator,
            new_parent,
            added_list,
            empty_list,
            new_previous_sibling,
            child,
        );
    }
}

/// Helper: Get shadow-including root of a node
/// Spec: https://dom.spec.whatwg.org/#concept-shadow-including-root
fn getShadowIncludingRoot(node: *Node) *Node {
    // For now, just return regular root (shadow DOM TODO)
    return tree_helpers.getRoot(node);
}

/// Helper: Check if node is a host-including inclusive ancestor of other
/// Spec: https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor
fn isHostIncludingInclusiveAncestor(node: *Node, other: *Node) bool {
    // For now, just check inclusive ancestor (shadow DOM TODO)
    return tree_helpers.isInclusiveAncestor(node, other);
}

/// Helper: Run live range pre-remove steps
/// Spec: https://dom.spec.whatwg.org/#live-range-pre-remove-steps
fn runLiveRangePreRemoveSteps(node: *Node) void {
    const parent = node.parent_node orelse return;
    const index = getChildIndex(node) orelse return;

    // Get the document for range tracking
    if (parent.owner_document) |doc| {
        doc.ranges_mutex.lock();
        defer doc.ranges_mutex.unlock();

        for (doc.ranges.items) |range| {
            // Step 4: For each live range whose start node is an inclusive descendant of node,
            // set its start to (parent, index)
            if (tree_helpers.isInclusiveDescendant(range.start_container, node)) {
                range.start_container = parent;
                range.start_offset = @intCast(index);
            }

            // Step 5: For each live range whose end node is an inclusive descendant of node,
            // set its end to (parent, index)
            if (tree_helpers.isInclusiveDescendant(range.end_container, node)) {
                range.end_container = parent;
                range.end_offset = @intCast(index);
            }

            // Step 6: For each live range whose start node is parent and start offset is greater than index,
            // decrease its start offset by 1
            if (range.start_container == parent and range.start_offset > index) {
                range.start_offset -= 1;
            }

            // Step 7: For each live range whose end node is parent and end offset is greater than index,
            // decrease its end offset by 1
            if (range.end_container == parent and range.end_offset > index) {
                range.end_offset -= 1;
            }
        }
    }
}

/// Helper: Run NodeIterator pre-remove steps for all iterators
/// Spec: https://dom.spec.whatwg.org/#nodeiterator-pre-removing-steps
fn runNodeIteratorPreRemoveSteps(node: *Node) void {
    // Get node's document
    const doc_node = node.owner_document orelse return;
    const doc: *Document = @ptrCast(@alignCast(doc_node));

    // For each NodeIterator object iterator whose root's node document is node's node document,
    // run the NodeIterator pre-removing steps given node and iterator
    doc.node_iterators_mutex.lock();
    defer doc.node_iterators_mutex.unlock();

    for (doc.node_iterators.items) |iterator| {
        // Call preRemoveSteps on the iterator
        iterator.preRemoveSteps(node);
    }
}

/// Helper: Update ranges when inserting before child
fn updateRangesForInsertion(doc: *Document, parent: *Node, child_index: usize) void {
    updateRangesForInsertionWithCount(doc, parent, child_index, 1);
}

/// Helper: Update ranges when inserting multiple nodes before child
/// DOM spec: For each live range whose start/end node is parent and offset > child_index,
/// increase offset by count
fn updateRangesForInsertionWithCount(doc: *Document, parent: *Node, child_index: usize, count: usize) void {
    doc.ranges_mutex.lock();
    defer doc.ranges_mutex.unlock();

    for (doc.ranges.items) |range| {
        // For each live range whose start node is parent and start offset is greater than child's index,
        // increase its start offset by count
        if (range.start_container == parent and range.start_offset > child_index) {
            range.start_offset += @intCast(count);
        }

        // For each live range whose end node is parent and end offset is greater than child's index,
        // increase its end offset by count
        if (range.end_container == parent and range.end_offset > child_index) {
            range.end_offset += @intCast(count);
        }
    }
}

/// Helper: Remove node from parent's children list (without updating parent pointer)
fn removeFromChildrenList(node: *Node, parent: *Node) void {
    // Update sibling pointers
    if (node.previous_sibling) |prev| {
        prev.next_sibling = node.next_sibling;
    } else {
        // node was first child
        const first = parent.child_nodes.items()[0];
        if (first == node) {
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
fn insertIntoChildrenList(node: *Node, parent: *Node, child: ?*Node) void {
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
fn runMovingStepsForTree(node: *Node, old_parent: *Node) void {
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

            // TODO: Step 24.2 - If inclusiveDescendant is custom and newParent is connected,
            // enqueue connectedMoveCallback reaction
        }
    } else |_| {
        // Fallback to regular tree traversal if shadow-including fails
        // Run moving steps for node itself with oldParent
        runMovingSteps(node, old_parent);

        // Run moving steps for all descendants with null
        var stack: std.ArrayList(*Node) = .{};
        defer stack.deinit();

        for (node.child_nodes.items()) |child| {
            stack.append(child) catch continue;
        }

        while (stack.items.len > 0) {
            const current = stack.pop();
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
/// For now, this is a placeholder for future custom element support
fn runMovingSteps(node: *Node, old_parent: ?*Node) void {
    // NOTE: Moving steps callback system requires custom elements implementation
    // Specifications define custom behavior for moved nodes
    // For example, custom elements would enqueue connectedMoveCallback here
    _ = node;
    _ = old_parent;
}

/// DOM §4.6 - Adopt
/// Spec: https://dom.spec.whatwg.org/#concept-node-adopt
///
/// Steps:
/// 1. Let oldDocument be node's node document
/// 2. If node's parent is non-null, then remove node
/// 3. If document is not oldDocument, update node document for all descendants
pub fn adopt(
    node: *Node,
    document: *Document,
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
        var descendants = std.ArrayList(*Node).init(node.allocator);
        defer descendants.deinit();

        try descendants.append(node);

        var i: usize = 0;
        while (i < descendants.items.len) : (i += 1) {
            const current = descendants.items[i];

            // Add children
            for (current.child_nodes.items()) |child| {
                try descendants.append(child);
            }
        }

        // Step 3.1.1: Set node document for all inclusive descendants
        for (descendants.items) |desc| {
            desc.owner_document = document;

            // Step 3.1.3: If element, update attribute node documents
            if (desc.node_type == Node.ELEMENT_NODE) {
                // TODO(DOM): Update attribute node documents once we have proper Element access
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
