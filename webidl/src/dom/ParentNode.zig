// DOM Standard: Interface Mixin ParentNode (§4.3.2)
// https://dom.spec.whatwg.org/#interface-parentnode

const std = @import("std");
const webidl = @import("../../root.zig");
const dom_types = @import("dom_types.zig");
const dom = @import("dom");

// Forward declarations
const Element = @import("Element.zig").Element;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const NodeList = @import("NodeList.zig").NodeList;

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
    pub fn get_children(self: anytype) *HTMLCollection {
        _ = self;
        // TODO: Implement DOM §4.3.2 children getter
        // 1. Return HTMLCollection rooted at this
        // 2. Collection matches only element children (not text, comment, etc.)
        @panic("ParentNode.children() not yet implemented");
    }

    /// DOM §4.3.2 - ParentNode.firstElementChild
    /// Returns the first child that is an element; otherwise null.
    ///
    /// The firstElementChild getter steps are to return the first child that is
    /// an element; otherwise null.
    pub fn get_firstElementChild(self: anytype) ?*Element {
        _ = self;
        // TODO: Implement DOM §4.3.2 firstElementChild getter
        // 1. Iterate through children (in tree order)
        // 2. Return first child that is an Element
        // 3. Return null if no element children
        @panic("ParentNode.firstElementChild() not yet implemented");
    }

    /// DOM §4.3.2 - ParentNode.lastElementChild
    /// Returns the last child that is an element; otherwise null.
    ///
    /// The lastElementChild getter steps are to return the last child that is
    /// an element; otherwise null.
    pub fn get_lastElementChild(self: anytype) ?*Element {
        _ = self;
        // TODO: Implement DOM §4.3.2 lastElementChild getter
        // 1. Iterate through children (in reverse tree order)
        // 2. Return last child that is an Element
        // 3. Return null if no element children
        @panic("ParentNode.lastElementChild() not yet implemented");
    }

    /// DOM §4.3.2 - ParentNode.childElementCount
    /// Returns the number of children that are elements.
    ///
    /// The childElementCount getter steps are to return the number of children
    /// of this that are elements.
    pub fn get_childElementCount(self: anytype) u32 {
        _ = self;
        // TODO: Implement DOM §4.3.2 childElementCount getter
        // 1. Count children that are Elements
        // 2. Return count as unsigned long (u32)
        @panic("ParentNode.childElementCount() not yet implemented");
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
        _ = self;
        _ = nodes;
        // TODO: Implement DOM §4.3.2 prepend() algorithm
        // Step 1: Convert nodes into a node (see convertNodesIntoNode helper)
        // Step 2: Pre-insert node before first child (from mutation.zig)
        @panic("ParentNode.prepend() not yet implemented");
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
        _ = self;
        _ = nodes;
        // TODO: Implement DOM §4.3.2 append() algorithm
        // Step 1: Convert nodes into a node (see convertNodesIntoNode helper)
        // Step 2: Append node to this (from mutation.zig)
        @panic("ParentNode.append() not yet implemented");
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
        _ = self;
        _ = nodes;
        // TODO: Implement DOM §4.3.2 replaceChildren() algorithm
        // Step 1: Convert nodes into a node (see convertNodesIntoNode helper)
        // Step 2: Ensure pre-insert validity (from mutation.zig)
        // Step 3: Replace all (from mutation.zig)
        @panic("ParentNode.replaceChildren() not yet implemented");
    }

    /// DOM §4.3.2 - ParentNode.moveBefore()
    /// Moves, without first removing, movedNode into this after child.
    /// This method preserves state associated with movedNode.
    ///
    /// Steps:
    /// 1. Let referenceChild be child.
    /// 2. If referenceChild is node, then set referenceChild to node's next sibling.
    /// 3. Move node into this before referenceChild.
    ///
    /// Throws HierarchyRequestError if constraints violated, or state cannot be preserved.
    pub fn call_moveBefore(self: anytype, node: anytype, child: anytype) !void {
        _ = self;
        _ = node;
        _ = child;
        // TODO: Implement DOM §4.3.2 moveBefore() algorithm
        // Step 1: Set referenceChild to child
        // Step 2: If referenceChild is node, adjust to node's next sibling
        // Step 3: Call move algorithm (from mutation.zig - when implemented)
        @panic("ParentNode.moveBefore() not yet implemented");
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

        // TODO: Convert ArrayList to NodeList (static snapshot)
        // For now, stub - need to implement NodeList creation from matches
        if (matches.items.len == 0) {
            @panic("ParentNode.querySelectorAll() - NodeList conversion not yet implemented");
        }
        @panic("ParentNode.querySelectorAll() - NodeList conversion not yet implemented");
    }
});

// ============================================================================
// Helper Algorithms (DOM §4.3.2)
// ============================================================================

/// DOM §4.3.2 - convert nodes into a node
/// Given nodes and document, run these steps:
///
/// 1. Let node be null.
/// 2. Replace each string in nodes with a new Text node whose data is the string
///    and node document is document.
/// 3. If nodes contains one node, then set node to nodes[0].
/// 4. Otherwise, set node to a new DocumentFragment node whose node document is
///    document, and then append each node in nodes, if any, to it.
/// 5. Return node.
///
/// This helper is used by ParentNode (prepend, append, replaceChildren) and
/// ChildNode (before, after, replaceWith) methods.
pub fn convertNodesIntoNode(
    allocator: std.mem.Allocator,
    nodes: []const dom_types.NodeOrDOMString,
    document: anytype,
) !*anyopaque {
    _ = allocator;
    _ = nodes;
    _ = document;
    // TODO: Implement "convert nodes into a node" algorithm (DOM §4.3.2)
    // Step 1: Let node be null
    // Step 2: Replace strings with Text nodes
    // Step 3: If single node, return it
    // Step 4: If multiple, create DocumentFragment and append all
    // Step 5: Return node
    @panic("convertNodesIntoNode helper not yet implemented");
}

test "ParentNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(ParentNode);
    try std.testing.expect(T != void);
}
