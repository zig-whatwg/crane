// DOM Standard: Interface Mixin ParentNode (§4.3.2)
// https://dom.spec.whatwg.org/#interface-parentnode

const std = @import("std");
const webidl = @import("../../root.zig");
const dom_types = @import("dom_types");
const dom = @import("dom");

// Forward declarations
const Element = @import("element").Element;
const HTMLCollection = @import("html_collection").HTMLCollection;
const NodeList = @import("node_list").NodeList;

/// ParentNode mixin provides methods for manipulating child elements.
/// Included by: Document, DocumentFragment, Element
///
/// WebIDL Definition:
/// ```
/// interface mixin ParentNode {
///   [SameObject] readonly attribute HTMLCollection children;
///   readonly attribute Element? firstElementChild;
///   readonly attribute Element? lastElementChild;
///   readonly attribute unsigned long childElementCount;
///
///   [CEReactions, Unscopable] undefined prepend((Node or DOMString)... nodes);
///   [CEReactions, Unscopable] undefined append((Node or DOMString)... nodes);
///   [CEReactions, Unscopable] undefined replaceChildren((Node or DOMString)... nodes);
///
///   [CEReactions] undefined moveBefore(Node node, Node? child);
///
///   Element? querySelector(DOMString selectors);
///   [NewObject] NodeList querySelectorAll(DOMString selectors);
/// };
/// ```
pub const ParentNode = webidl.mixin(struct {
    // NOTE: This is a mixin - no fields, only methods/attributes to be included in other interfaces

    /// DOM §4.3.2 - ParentNode.children
    /// Returns the child elements.
    ///
    /// The children getter steps are to return an HTMLCollection collection rooted
    /// at this matching only element children.
    ///
    /// NOTE: This is a simplified implementation that returns a static snapshot.
    /// A full implementation would return a live HTMLCollection that updates
    /// automatically when the DOM changes.
    pub fn get_children(self: anytype) !*HTMLCollection {
        const NodeType = @import("node").Node;
        const allocator = self.allocator;

        // Create HTMLCollection
        const collection = try allocator.create(HTMLCollection);
        collection.* = try HTMLCollection.init(allocator);

        // Filter child_nodes for elements only (ELEMENT_NODE = 1)
        for (self.child_nodes.items) |child| {
            if (child.node_type == NodeType.ELEMENT_NODE) {
                const element: *Element = @ptrCast(child);
                try collection.addElement(element);
            }
        }

        return collection;
    }

    /// DOM §4.3.2 - ParentNode.firstElementChild
    /// Returns the first child that is an element; otherwise null.
    ///
    /// The firstElementChild getter steps are to return the first child that is
    /// an element; otherwise null.
    pub fn get_firstElementChild(self: anytype) ?*Element {
        // Node type will be available from module-level import in generated code
        const NodeType = @import("node").Node;

        // Iterate through children in tree order
        for (self.child_nodes.items) |child| {
            if (child.node_type == NodeType.ELEMENT_NODE) {
                return @ptrCast(child);
            }
        }

        return null;
    }

    /// DOM §4.3.2 - ParentNode.lastElementChild
    /// Returns the last child that is an element; otherwise null.
    ///
    /// The lastElementChild getter steps are to return the last child that is
    /// an element; otherwise null.
    pub fn get_lastElementChild(self: anytype) ?*Element {
        // Node type will be available from module-level import in generated code
        const NodeType = @import("node").Node;

        // Iterate through children in reverse tree order
        var i: usize = self.child_nodes.items.len;
        while (i > 0) {
            i -= 1;
            const child = self.child_nodes.items[i];
            if (child.node_type == NodeType.ELEMENT_NODE) {
                return @ptrCast(child);
            }
        }

        return null;
    }

    /// DOM §4.3.2 - ParentNode.childElementCount
    /// Returns the number of children that are elements.
    ///
    /// The childElementCount getter steps are to return the number of children
    /// of this that are elements.
    pub fn get_childElementCount(self: anytype) u32 {
        // Node type will be available from module-level import in generated code
        const NodeType = @import("node").Node;

        // Count children that are Elements
        var count: u32 = 0;
        for (self.child_nodes.items) |child| {
            if (child.node_type == NodeType.ELEMENT_NODE) {
                count += 1;
            }
        }

        return count;
    }

    /// DOM §4.3.2 - ParentNode.prepend()
    /// Inserts nodes before the first child, while replacing strings with Text nodes.
    ///
    /// Steps:
    /// 1. Let node be the result of converting nodes into a node given nodes and this's node document.
    /// 2. Pre-insert node into this before this's first child.
    ///
    /// Throws HierarchyRequestError if constraints violated.
    pub fn call_prepend(self: anytype, nodes: []const dom_types.NodeOrDOMString) !void {
        const NodeType = @import("node").Node;
        const mutation = @import("dom").mutation;
        const ChildNodeMixin = @import("child_node").ChildNode;

        // Cast self to Node pointer
        const this_node = @as(*NodeType, @ptrCast(self));

        // Step 1: Let node be the result of converting nodes into a node
        const document = this_node.owner_document orelse return error.NoDocument;
        const node = try ChildNodeMixin.convertNodesIntoNode(this_node.allocator, nodes, document);

        // Step 2: Pre-insert node into this before this's first child
        const first_child = this_node.get_firstChild();
        _ = try mutation.preInsert(node, this_node, first_child);
    }

    /// DOM §4.3.2 - ParentNode.append()
    /// Inserts nodes after the last child, while replacing strings with Text nodes.
    ///
    /// Steps:
    /// 1. Let node be the result of converting nodes into a node given nodes and this's node document.
    /// 2. Append node to this.
    ///
    /// Throws HierarchyRequestError if constraints violated.
    pub fn call_append(self: anytype, nodes: []const dom_types.NodeOrDOMString) !void {
        const NodeType = @import("node").Node;
        const mutation = @import("dom").mutation;
        const ChildNodeMixin = @import("child_node").ChildNode;

        // Cast self to Node pointer
        const this_node = @as(*NodeType, @ptrCast(self));

        // Step 1: Let node be the result of converting nodes into a node
        const document = this_node.owner_document orelse return error.NoDocument;
        const node = try ChildNodeMixin.convertNodesIntoNode(this_node.allocator, nodes, document);

        // Step 2: Append node to this
        _ = try mutation.append(node, this_node);
    }

    /// DOM §4.3.2 - ParentNode.replaceChildren()
    /// Replaces all children with nodes, while replacing strings with Text nodes.
    ///
    /// Steps:
    /// 1. Let node be the result of converting nodes into a node given nodes and this's node document.
    /// 2. Ensure pre-insert validity of node into this before null.
    /// 3. Replace all with node within this.
    ///
    /// Throws HierarchyRequestError if constraints violated.
    pub fn call_replaceChildren(self: anytype, nodes: []const dom_types.NodeOrDOMString) !void {
        const NodeType = @import("node").Node;
        const mutation = @import("dom").mutation;
        const ChildNodeMixin = @import("child_node").ChildNode;

        // Cast self to Node pointer
        const this_node = @as(*NodeType, @ptrCast(self));

        // Step 1: Let node be the result of converting nodes into a node
        const document = this_node.owner_document orelse return error.NoDocument;
        const node = try ChildNodeMixin.convertNodesIntoNode(this_node.allocator, nodes, document);

        // Step 2: Ensure pre-insert validity of node into this before null
        try mutation.ensurePreInsertValidity(node, this_node, null);

        // Step 3: Replace all with node within this
        try mutation.replaceAll(node, this_node);
    }

    /// DOM §4.3.2 - ParentNode.moveBefore()
    /// Moves, without first removing, movedNode into this after child.
    /// This method preserves state associated with movedNode.
    ///
    /// Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
    ///
    /// Steps:
    /// 1. Let referenceChild be child.
    /// 2. If referenceChild is node, then set referenceChild to node's next sibling.
    /// 3. Move node into this before referenceChild.
    ///
    /// Throws HierarchyRequestError if constraints violated, or state cannot be preserved.
    pub fn call_moveBefore(self: anytype, node: anytype, child: anytype) !void {
        const mutation = @import("dom").mutation;

        // Get Node pointers from the anytype parameters
        const parent_node = @as(*@import("node").Node, @ptrCast(self));
        const moved_node = @as(*@import("node").Node, @ptrCast(node));
        const child_node = if (child) |c| @as(?*@import("node").Node, @ptrCast(c)) else null;

        // Step 1: Let referenceChild be child
        var reference_child = child_node;

        // Step 2: If referenceChild is node, then set referenceChild to node's next sibling
        if (reference_child == moved_node) {
            reference_child = moved_node.next_sibling;
        }

        // Step 3: Move node into this before referenceChild
        try mutation.move(moved_node, parent_node, reference_child);
    }

    /// DOM §4.3.2 - ParentNode.querySelector()
    /// Returns the first element that is a descendant of this that matches selectors.
    ///
    /// The querySelector(selectors) method steps are to return the first result of
    /// running scope-match a selectors string selectors against this, if the result
    /// is not an empty list; otherwise null.
    ///
    /// Uses Selectors mock (basic support only).
    pub fn call_querySelector(self: anytype, allocator: std.mem.Allocator, selectors: []const u8) !?*Element {
        // Run scope-match a selectors string against this
        const matches = try dom.selectors.scopeMatchSelectorsString(allocator, selectors, self);
        defer matches.deinit();

        // Return first result if not empty; otherwise null
        if (matches.items.len > 0) {
            return matches.items[0];
        }

        return null;
    }

    /// DOM §4.3.2 - ParentNode.querySelectorAll()
    /// Returns all element descendants of this that match selectors.
    ///
    /// The querySelectorAll(selectors) method steps are to return the static result
    /// of running scope-match a selectors string selectors against this.
    ///
    /// Uses Selectors mock (basic support only).
    pub fn call_querySelectorAll(self: anytype, allocator: std.mem.Allocator, selectors: []const u8) !*NodeList {
        // Run scope-match a selectors string against this
        var matches = try dom.selectors.scopeMatchSelectorsString(allocator, selectors, self);
        defer matches.deinit();

        // Create NodeList and populate with matches (static snapshot)
        var node_list = try allocator.create(NodeList);
        node_list.* = try NodeList.init(allocator);

        // Add all matched elements to the NodeList
        for (matches.items) |element| {
            // Cast Element to Node
            const node = @as(*@import("node").Node, @ptrCast(element));
            try node_list.addNode(node);
        }

        return node_list;
    }
});

// ============================================================================
// Helper Algorithms (DOM §4.3.2)
// ============================================================================

// NOTE: convertNodesIntoNode() is implemented in ChildNode.zig and shared by both mixins

test "ParentNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(ParentNode);
    try std.testing.expect(T != void);
}
