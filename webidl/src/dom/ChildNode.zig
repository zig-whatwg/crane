// DOM Standard: Interface Mixin ChildNode (§4.3.4)
// https://dom.spec.whatwg.org/#interface-childnode

const std = @import("std");
const infra = @import("infra");
const webidl = @import("../../root.zig");
const dom_types = @import("dom_types");

/// ChildNode mixin provides methods for manipulating nodes relative to their siblings.
/// Included by: DocumentType, Element, CharacterData
///
/// WebIDL Definition:
/// ```
/// interface mixin ChildNode {
///   [CEReactions, Unscopable] undefined before((Node or DOMString)... nodes);
///   [CEReactions, Unscopable] undefined after((Node or DOMString)... nodes);
///   [CEReactions, Unscopable] undefined replaceWith((Node or DOMString)... nodes);
///   [CEReactions, Unscopable] undefined remove();
/// };
/// ```
pub const ChildNode = webidl.mixin(struct {
    // NOTE: This is a mixin - no fields, only methods to be included in other interfaces

    /// DOM §4.3.4 - ChildNode.before()
    /// Inserts nodes just before this node, while replacing strings with Text nodes.
    ///
    /// Steps:
    /// 1. Let parent be this's parent.
    /// 2. If parent is null, then return.
    /// 3. Let viablePreviousSibling be this's first preceding sibling not in nodes; otherwise null.
    /// 4. Let node be the result of converting nodes into a node, given nodes and this's node document.
    /// 5. If viablePreviousSibling is null, then set it to parent's first child; otherwise to viablePreviousSibling's next sibling.
    /// 6. Pre-insert node into parent before viablePreviousSibling.
    ///
    /// Throws HierarchyRequestError if constraints violated.
    pub fn call_before(self: anytype, nodes: []const dom_types.NodeOrDOMString) !void {
        const NodeType = @import("node").Node;
        const mutation = @import("dom").mutation;

        // Cast self to Node pointer
        const this_node = @as(*NodeType, @ptrCast(self));

        // Step 1: Let parent be this's parent
        const parent = this_node.parent_node;

        // Step 2: If parent is null, then return
        if (parent == null) {
            return;
        }

        // Step 3: Let viablePreviousSibling be this's first preceding sibling not in nodes; otherwise null
        var viable_previous_sibling: ?*NodeType = null;

        // Walk backwards through siblings to find first one not in nodes
        var current = this_node.get_previousSibling();
        while (current) |sibling| {
            // Check if this sibling is in the nodes array
            var found_in_nodes = false;
            for (nodes) |item| {
                if (item == .node and item.node == sibling) {
                    found_in_nodes = true;
                    break;
                }
            }

            if (!found_in_nodes) {
                viable_previous_sibling = sibling;
                break;
            }

            current = sibling.get_previousSibling();
        }

        // Step 4: Let node be the result of converting nodes into a node
        const document = this_node.owner_document orelse return error.NoDocument;
        const node = try ChildNode.convertNodesIntoNode(this_node.allocator, nodes, document);

        // Step 5: If viablePreviousSibling is null, set it to parent's first child;
        // otherwise to viablePreviousSibling's next sibling
        const reference_child = if (viable_previous_sibling) |vps|
            vps.get_nextSibling()
        else
            parent.?.get_firstChild();

        // Step 6: Pre-insert node into parent before viablePreviousSibling
        _ = try mutation.preInsert(node, parent.?, reference_child);
    }

    /// DOM §4.3.4 - ChildNode.after()
    /// Inserts nodes just after this node, while replacing strings with Text nodes.
    ///
    /// Steps:
    /// 1. Let parent be this's parent.
    /// 2. If parent is null, then return.
    /// 3. Let viableNextSibling be this's first following sibling not in nodes; otherwise null.
    /// 4. Let node be the result of converting nodes into a node, given nodes and this's node document.
    /// 5. Pre-insert node into parent before viableNextSibling.
    ///
    /// Throws HierarchyRequestError if constraints violated.
    pub fn call_after(self: anytype, nodes: []const dom_types.NodeOrDOMString) !void {
        const NodeType = @import("node").Node;
        const mutation = @import("dom").mutation;

        // Cast self to Node pointer
        const this_node = @as(*NodeType, @ptrCast(self));

        // Step 1: Let parent be this's parent
        const parent = this_node.parent_node;

        // Step 2: If parent is null, then return
        if (parent == null) {
            return;
        }

        // Step 3: Let viableNextSibling be this's first following sibling not in nodes; otherwise null
        var viable_next_sibling: ?*NodeType = null;

        // Walk forward through siblings to find first one not in nodes
        var current = this_node.get_nextSibling();
        while (current) |sibling| {
            // Check if this sibling is in the nodes array
            var found_in_nodes = false;
            for (nodes) |item| {
                if (item == .node and item.node == sibling) {
                    found_in_nodes = true;
                    break;
                }
            }

            if (!found_in_nodes) {
                viable_next_sibling = sibling;
                break;
            }

            current = sibling.get_nextSibling();
        }

        // Step 4: Let node be the result of converting nodes into a node
        const document = this_node.owner_document orelse return error.NoDocument;
        const node = try ChildNode.convertNodesIntoNode(this_node.allocator, nodes, document);

        // Step 5: Pre-insert node into parent before viableNextSibling
        _ = try mutation.preInsert(node, parent.?, viable_next_sibling);
    }

    /// DOM §4.3.4 - ChildNode.replaceWith()
    /// Replaces this node with nodes, while replacing strings with Text nodes.
    ///
    /// Steps:
    /// 1. Let parent be this's parent.
    /// 2. If parent is null, then return.
    /// 3. Let viableNextSibling be this's first following sibling not in nodes; otherwise null.
    /// 4. Let node be the result of converting nodes into a node, given nodes and this's node document.
    /// 5. If this's parent is parent, replace this with node within parent.
    /// 6. Otherwise, pre-insert node into parent before viableNextSibling.
    ///
    /// Throws HierarchyRequestError if constraints violated.
    pub fn call_replaceWith(self: anytype, nodes: []const dom_types.NodeOrDOMString) !void {
        const NodeType = @import("node").Node;
        const mutation = @import("dom").mutation;

        // Cast self to Node pointer
        const this_node = @as(*NodeType, @ptrCast(self));

        // Step 1: Let parent be this's parent
        const parent = this_node.parent_node;

        // Step 2: If parent is null, then return
        if (parent == null) {
            return;
        }

        // Step 3: Let viableNextSibling be this's first following sibling not in nodes; otherwise null
        var viable_next_sibling: ?*NodeType = null;

        // Walk forward through siblings to find first one not in nodes
        var current = this_node.get_nextSibling();
        while (current) |sibling| {
            // Check if this sibling is in the nodes array
            var found_in_nodes = false;
            for (nodes) |item| {
                if (item == .node and item.node == sibling) {
                    found_in_nodes = true;
                    break;
                }
            }

            if (!found_in_nodes) {
                viable_next_sibling = sibling;
                break;
            }

            current = sibling.get_nextSibling();
        }

        // Step 4: Let node be the result of converting nodes into a node
        const document = this_node.owner_document orelse return error.NoDocument;
        const node = try ChildNode.convertNodesIntoNode(this_node.allocator, nodes, document);

        // Step 5: If this's parent is parent, replace this with node within parent
        // Note: The parent could have changed during convertNodesIntoNode if one of the nodes
        // contained 'this' in its subtree
        if (this_node.parent_node == parent) {
            try mutation.replace(this_node, node, parent.?);
        } else {
            // Step 6: Otherwise, pre-insert node into parent before viableNextSibling
            _ = try mutation.preInsert(node, parent.?, viable_next_sibling);
        }
    }

    /// DOM §4.3.4 - ChildNode.remove()
    /// Removes this node from its parent.
    ///
    /// Steps:
    /// 1. If this's parent is null, then return.
    /// 2. Remove this.
    pub fn call_remove(self: anytype) !void {
        const NodeType = @import("node").Node;
        const mutation = @import("dom").mutation;

        // Cast self to Node pointer
        const node = @as(*NodeType, @ptrCast(self));

        // Step 1: If this's parent is null, then return
        if (node.parent_node == null) {
            return;
        }

        // Step 2: Remove this
        try mutation.remove(node, false);
    }
});

/// DOM §4.3.3 - convert nodes into a node
/// Given nodes and document, run these steps:
/// 1. Let node be null.
/// 2. Replace each string in nodes with a new Text node whose data is the string and node document is document.
/// 3. If nodes contains one node, then set node to nodes[0].
/// 4. Otherwise, set node to a new DocumentFragment node whose node document is document,
///    and then append each node in nodes, if any, to it.
/// 5. Return node.
pub fn convertNodesIntoNode(allocator: std.mem.Allocator, nodes: []const dom_types.NodeOrDOMString, document: *@import("document").Document) !*@import("node").Node {
    const NodeType = @import("node").Node;
    const Text = @import("text").Text;
    const DocumentFragment = @import("document_fragment").DocumentFragment;
    const mutation = @import("dom").mutation;

    // Step 1: Let node be null
    // Step 2: Build array of actual nodes (converting strings to Text nodes)
    var node_list = infra.List(*NodeType).init(allocator);
    defer node_list.deinit();

    for (nodes) |item| {
        switch (item) {
            .node => |n| try node_list.append(n),
            .string => |s| {
                // Create Text node with the string data
                const text = try Text.init(allocator, s);
                // Cast Text to Node (Text extends Node)
                const text_node = @as(*NodeType, @ptrCast(&text));
                text_node.owner_document = document;
                try node_list.append(text_node);
            },
        }
    }

    // Step 3: If nodes contains one node, return it
    if (node_list.items.len == 1) {
        return node_list.items[0];
    }

    // Step 4: Create DocumentFragment and append all nodes
    var fragment = try DocumentFragment.init(allocator);
    const fragment_node = @as(*NodeType, @ptrCast(&fragment));
    fragment_node.owner_document = document;

    for (node_list.items) |node| {
        try mutation.append(node, fragment_node);
    }

    // Step 5: Return the fragment node
    return fragment_node;
}

test "ChildNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(ChildNode);
    try std.testing.expect(T != void);
}
