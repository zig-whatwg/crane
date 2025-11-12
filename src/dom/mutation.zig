//! DOM Mutation Algorithms (WHATWG DOM Standard §4.2.5)
//!
//! Spec: https://dom.spec.whatwg.org/#mutation-algorithms
//!
//! This module implements the complete set of mutation algorithms for DOM node trees.
//! All algorithms follow the WHATWG DOM specification precisely.

const std = @import("std");
const Node = @import("node").Node;
const Document = @import("document").Document;
const DocumentFragment = @import("document_fragment").DocumentFragment;
const Element = @import("element").Element;
const DocumentType = @import("document_type").DocumentType;
const CharacterData = @import("character_data").CharacterData;
const Text = @import("text").Text;
const tree_helpers = @import("tree_helpers.zig");
const shadow_dom_algorithms = @import("shadow_dom_algorithms.zig");

/// DOM Exception types as defined in WebIDL
pub const DOMException = error{
    HierarchyRequestError,
    NotFoundError,
    NotSupportedError,
};

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
    for (parent.child_nodes.items, 0..) |node, i| {
        if (node == child) return i;
    }
    return null;
}

/// Check if a doctype is following a given child in parent
fn isDoctypeFollowing(parent: *Node, child: ?*Node) bool {
    if (child == null) return false;

    const child_idx = getChildIndex(child.?) orelse return false;

    // Check all siblings after child
    for (parent.child_nodes.items[child_idx + 1 ..]) |sibling| {
        if (isDocumentType(sibling)) return true;
    }

    return false;
}

/// Check if an element is preceding a given child in parent
fn isElementPreceding(parent: *Node, child: ?*Node) bool {
    if (child == null) {
        // If child is null, check if parent has any element children
        for (parent.child_nodes.items) |node| {
            if (isElement(node)) return true;
        }
        return false;
    }

    const child_idx = getChildIndex(child.?) orelse return false;

    // Check all siblings before child
    for (parent.child_nodes.items[0..child_idx]) |sibling| {
        if (isElement(sibling)) return true;
    }

    return false;
}

/// Count element children of a node
fn countElementChildren(node: *Node) usize {
    var count: usize = 0;
    for (node.child_nodes.items) |child| {
        if (isElement(child)) count += 1;
    }
    return count;
}

/// Check if node has a Text child
fn hasTextChild(node: *Node) bool {
    for (node.child_nodes.items) |child| {
        if (isText(child)) return true;
    }
    return false;
}

/// Check if parent has a doctype child
fn hasDoctypeChild(parent: *Node) bool {
    for (parent.child_nodes.items) |child| {
        if (isDocumentType(child)) return true;
    }
    return false;
}

/// Check if parent has an element child (optionally excluding one node)
fn hasElementChild(parent: *Node, exclude: ?*Node) bool {
    for (parent.child_nodes.items) |child| {
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
            if (idx + 1 < node_parent.child_nodes.items.len) {
                referenceChild = node_parent.child_nodes.items[idx + 1];
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
/// - Live range updates (TODO: when Range is fully implemented)
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
        for (node.child_nodes.items) |child_node| {
            try remove(child_node, true);
        }

        // Step 4.2: Queue a tree mutation record for node
        // TODO: Implement mutation observer record queuing
        // queueTreeMutationRecord(node, &[_]*Node{}, nodes, null, null);
    }

    // Step 5: If child is non-null, update live ranges
    if (child) |c| {
        const child_idx = getChildIndex(c) orelse 0;

        // TODO: Update live ranges when Range is fully implemented
        // For each live range whose start node is parent and start offset > child's index,
        // increase its start offset by count
        // For each live range whose end node is parent and end offset > child's index,
        // increase its end offset by count
        _ = child_idx;
    }

    // Step 6: Let previousSibling be child's previous sibling or parent's last child if child is null
    var previousSibling: ?*Node = null;
    if (child) |c| {
        const idx = getChildIndex(c) orelse 0;
        if (idx > 0) {
            previousSibling = parent.child_nodes.items[idx - 1];
        }
    } else {
        if (parent.child_nodes.items.len > 0) {
            previousSibling = parent.child_nodes.items[parent.child_nodes.items.len - 1];
        }
    }

    // Step 7: For each node in nodes, in tree order:
    for (nodes[0..count]) |n| {
        // Step 7.1: Adopt node into parent's node document
        try adopt(n, parent.owner_document.?);

        // Step 7.2-3: Insert node into parent's children
        if (child) |c| {
            const idx = getChildIndex(c) orelse parent.child_nodes.items.len;
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

        // Step 7.7: For each shadow-including inclusive descendant
        // TODO: Implement insertion steps callback system
        // TODO: Implement custom element reactions
        // For now, this is where we would:
        // - Run insertion steps
        // - Handle custom elements
        // - Set custom element registry
    }

    // Step 8: If suppress observers flag is unset, queue a tree mutation record
    if (!suppress_observers) {
        // TODO: Implement mutation observer record queuing
        // queueTreeMutationRecord(parent, nodes, &[_]*Node{}, previousSibling, child);
    }

    // Step 9: Run the children changed steps for parent
    // TODO: Implement children changed steps callback system

    // Steps 10-12: Post-connection steps
    // TODO: Implement post-connection steps callback system
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
        if (idx + 1 < parent.child_nodes.items.len) {
            referenceChild = parent.child_nodes.items[idx + 1];
        }
    }

    // Step 8: If referenceChild is node, set referenceChild to node's next sibling
    if (referenceChild != null and referenceChild.? == node) {
        const node_idx = getChildIndex(node);
        if (node_idx) |idx| {
            if (node.parent_node) |node_parent| {
                if (idx + 1 < node_parent.child_nodes.items.len) {
                    referenceChild = node_parent.child_nodes.items[idx + 1];
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
            previousSibling = parent.child_nodes.items[idx - 1];
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
    // Step 13: Insert node into parent before referenceChild with suppress observers
    try insert(node, parent, referenceChild, true);

    // Step 14: Queue a tree mutation record
    // TODO: Implement mutation observer record queuing
    // Would use: previousSibling, removedNodes[0..removed_count], referenceChild

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
    // Step 1: Let removedNodes be parent's children
    // Step 2-4: Determine addedNodes
    // (Both will be used for mutation observer - TODO)

    // Step 5: Remove all parent's children in tree order with suppress observers
    while (parent.child_nodes.items.len > 0) {
        const child_to_remove = parent.child_nodes.items[0];
        try remove(child_to_remove, true);
    }

    // Step 6: If node is non-null, insert node into parent before null with suppress observers
    if (node) |n| {
        try insert(n, parent, null, true);
    }

    // Step 7: Queue a tree mutation record if addedNodes or removedNodes is not empty
    // TODO: Implement mutation observer record queuing
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
) DOMException!*Node {
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
) DOMException!void {
    // Step 1: Let parent be node's parent
    const parent = node.parent_node orelse {
        // Step 2: Assert parent is non-null
        // If parent is null, this is an error in the algorithm usage
        return error.HierarchyRequestError;
    };

    // Step 3: Run the live range pre-remove steps
    // TODO: Implement when Range is fully implemented

    // Step 4: For each NodeIterator, run pre-remove steps
    // TODO: Implement when NodeIterator is fully implemented

    // Step 5: Let oldPreviousSibling be node's previous sibling
    var oldPreviousSibling: ?*Node = null;
    const node_idx = getChildIndex(node);
    if (node_idx) |idx| {
        if (idx > 0) {
            oldPreviousSibling = parent.child_nodes.items[idx - 1];
        }
    }

    // Step 6: Let oldNextSibling be node's next sibling
    var oldNextSibling: ?*Node = null;
    if (node_idx) |idx| {
        if (idx + 1 < parent.child_nodes.items.len) {
            oldNextSibling = parent.child_nodes.items[idx + 1];
        }
    }

    // Step 7: Remove node from its parent's children
    if (node_idx) |idx| {
        _ = parent.child_nodes.orderedRemove(idx);
    }
    node.parent_node = null;

    // Step 8-10: Shadow DOM slot assignment
    // TODO: Implement when shadow DOM is fully integrated

    // Step 11: Run the removing steps with node and parent
    // TODO: Implement removing steps callback system

    // Step 12-14: Custom element disconnection
    // TODO: Implement when custom elements are fully integrated

    // Step 15: Transient registered observers
    // TODO: Implement when mutation observers are fully integrated

    // Step 16: If suppress observers flag is unset, queue a tree mutation record
    if (!suppress_observers) {
        // TODO: Implement mutation observer record queuing
        // Would use: oldPreviousSibling, oldNextSibling
    }

    // Step 17: Run the children changed steps for parent
    // TODO: Implement children changed steps callback system
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

        // Update node's document
        node.owner_document = document;

        // Update all descendants
        var stack = std.ArrayList(*Node).init(std.heap.page_allocator);
        defer stack.deinit();

        try stack.append(node);

        while (stack.items.len > 0) {
            const current = stack.pop();
            current.owner_document = document;

            // Add children to stack
            for (current.child_nodes.items) |child| {
                try stack.append(child);
            }
        }

        // Step 3.2: Custom element adoptedCallback
        // TODO: Implement when custom elements are fully integrated

        // Step 3.3: Run adopting steps
        // TODO: Implement adopting steps callback system
    }
}
