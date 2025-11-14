//! XPath Node Union
//!
//! Wrapper type that can hold either DOM nodes or virtual namespace nodes.
//! This allows XPath operations to work with both real DOM nodes and
//! XPath-specific virtual nodes without polluting the DOM tree.

const std = @import("std");
const NodeBase = @import("../node_base.zig").NodeBase;
const NamespaceNode = @import("namespace_node.zig").NamespaceNode;

/// XPath node - can be either a DOM node or a virtual namespace node
pub const XPathNode = union(enum) {
    dom_node: *NodeBase,
    namespace_node: *NamespaceNode,
    
    /// Check if this is a namespace node
    pub fn isNamespaceNode(self: XPathNode) bool {
        return self == .namespace_node;
    }
    
    /// Check if this is a DOM node
    pub fn isDomNode(self: XPathNode) bool {
        return self == .dom_node;
    }
    
    /// Get as DOM node (returns null if namespace node)
    pub fn asDomNode(self: XPathNode) ?*NodeBase {
        return switch (self) {
            .dom_node => |n| n,
            .namespace_node => null,
        };
    }
    
    /// Get as namespace node (returns null if DOM node)
    pub fn asNamespaceNode(self: XPathNode) ?*NamespaceNode {
        return switch (self) {
            .dom_node => null,
            .namespace_node => |n| n,
        };
    }
    
    /// Get parent node (works for both types)
    pub fn getParent(self: XPathNode) ?*NodeBase {
        return switch (self) {
            .dom_node => |n| n.parent_node,
            .namespace_node => |n| n.getParent(),
        };
    }
    
    /// Check equality
    pub fn eql(self: XPathNode, other: XPathNode) bool {
        return switch (self) {
            .dom_node => |dn| {
                if (other == .dom_node) {
                    return dn == other.dom_node;
                }
                return false;
            },
            .namespace_node => |nsn| {
                if (other == .namespace_node) {
                    const other_ns = other.namespace_node;
                    // Same if same prefix and parent element
                    return nsn.parent_element == other_ns.parent_element and
                           std.mem.eql(u8, nsn.prefix, other_ns.prefix);
                }
                return false;
            },
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;







