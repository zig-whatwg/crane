//! NodeFilter interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-nodefilter

const std = @import("std");
const Node = @import("node").Node;

/// DOM §6.1 - NodeFilter callback interface
///
/// NodeFilter objects can be used as filter for NodeIterator and TreeWalker objects
/// and also provide constants for their whatToShow bitmask.
///
/// In Zig, we implement this as a namespace with constants and a function pointer type
/// since Zig doesn't have callback interfaces like JavaScript.
pub const NodeFilter = struct {
    // ========================================================================
    // Filter return value constants
    // ========================================================================

    /// Accept the node. Navigation methods return this node.
    pub const FILTER_ACCEPT: u16 = 1;

    /// Reject the node and its children. Navigation methods skip this subtree.
    pub const FILTER_REJECT: u16 = 2;

    /// Skip the node. Navigation methods skip this node but not its children.
    pub const FILTER_SKIP: u16 = 3;

    // ========================================================================
    // whatToShow bitmask constants
    // ========================================================================

    /// Show all nodes (all bits set)
    pub const SHOW_ALL: u32 = 0xFFFFFFFF;

    /// Show Element nodes
    pub const SHOW_ELEMENT: u32 = 0x1;

    /// Show Attr nodes (historical - attributes are not in tree)
    pub const SHOW_ATTRIBUTE: u32 = 0x2;

    /// Show Text nodes
    pub const SHOW_TEXT: u32 = 0x4;

    /// Show CDATASection nodes
    pub const SHOW_CDATA_SECTION: u32 = 0x8;

    /// Show EntityReference nodes (legacy - no longer used)
    pub const SHOW_ENTITY_REFERENCE: u32 = 0x10;

    /// Show Entity nodes (legacy - no longer used)
    pub const SHOW_ENTITY: u32 = 0x20;

    /// Show ProcessingInstruction nodes
    pub const SHOW_PROCESSING_INSTRUCTION: u32 = 0x40;

    /// Show Comment nodes
    pub const SHOW_COMMENT: u32 = 0x80;

    /// Show Document nodes
    pub const SHOW_DOCUMENT: u32 = 0x100;

    /// Show DocumentType nodes
    pub const SHOW_DOCUMENT_TYPE: u32 = 0x200;

    /// Show DocumentFragment nodes
    pub const SHOW_DOCUMENT_FRAGMENT: u32 = 0x400;

    /// Show Notation nodes (legacy - no longer used)
    pub const SHOW_NOTATION: u32 = 0x800;

    // ========================================================================
    // Filter callback type
    // ========================================================================

    /// Function pointer type for filter callbacks
    /// Returns one of FILTER_ACCEPT, FILTER_REJECT, or FILTER_SKIP
    pub const AcceptNodeFn = *const fn (node: *Node) u16;

    /// Optional filter callback (can be null for no filtering beyond whatToShow)
    pub const OptionalAcceptNodeFn = ?AcceptNodeFn;

    // ========================================================================
    // Helper functions
    // ========================================================================

    /// Check if a node type is included in the whatToShow bitmask
    /// Per spec: whatToShow is a bitmask that specifies which node types to show
    pub fn isNodeTypeShown(whatToShow: u32, nodeType: u16) bool {
        // Map node type to whatToShow bit
        const bit: u32 = switch (nodeType) {
            Node.ELEMENT_NODE => SHOW_ELEMENT,
            Node.ATTRIBUTE_NODE => SHOW_ATTRIBUTE,
            Node.TEXT_NODE => SHOW_TEXT,
            Node.CDATA_SECTION_NODE => SHOW_CDATA_SECTION,
            Node.PROCESSING_INSTRUCTION_NODE => SHOW_PROCESSING_INSTRUCTION,
            Node.COMMENT_NODE => SHOW_COMMENT,
            Node.DOCUMENT_NODE => SHOW_DOCUMENT,
            Node.DOCUMENT_TYPE_NODE => SHOW_DOCUMENT_TYPE,
            Node.DOCUMENT_FRAGMENT_NODE => SHOW_DOCUMENT_FRAGMENT,
            else => 0, // Unknown node types are not shown
        };

        return (whatToShow & bit) != 0;
    }

    /// Filter a node through whatToShow and optional callback
    /// Returns FILTER_ACCEPT, FILTER_REJECT, or FILTER_SKIP
    /// This is the main filtering logic used by NodeIterator and TreeWalker
    pub fn filterNode(whatToShow: u32, filter: OptionalAcceptNodeFn, node: *Node) u16 {
        // Step 1: Check whatToShow bitmask
        if (!isNodeTypeShown(whatToShow, node.node_type)) {
            return FILTER_SKIP;
        }

        // Step 2: If no filter callback, accept the node
        if (filter == null) {
            return FILTER_ACCEPT;
        }

        // Step 3: Call filter callback
        return filter.?(node);
    }
};

// Test to ensure constants are exported
test "NodeFilter constants" {
    const testing = std.testing;

    // Filter return values
    try testing.expectEqual(@as(u16, 1), NodeFilter.FILTER_ACCEPT);
    try testing.expectEqual(@as(u16, 2), NodeFilter.FILTER_REJECT);
    try testing.expectEqual(@as(u16, 3), NodeFilter.FILTER_SKIP);

    // whatToShow bitmask constants
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), NodeFilter.SHOW_ALL);
    try testing.expectEqual(@as(u32, 0x1), NodeFilter.SHOW_ELEMENT);
    try testing.expectEqual(@as(u32, 0x4), NodeFilter.SHOW_TEXT);
    try testing.expectEqual(@as(u32, 0x80), NodeFilter.SHOW_COMMENT);
}
