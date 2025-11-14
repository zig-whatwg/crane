//! XPath Namespace Node
//!
//! Virtual namespace nodes for XPath 1.0 namespace axis.
//! These nodes don't exist in the DOM - they're XPath-specific.
//!
//! ## XPath 1.0 Specification
//! - **§5.4 Namespace Nodes**: https://www.w3.org/TR/xpath-10/#namespace-nodes
//!
//! From XPath 1.0 §5.4:
//! - Every element has namespace nodes (one for each in-scope namespace)
//! - Namespace node has expanded-name (the prefix)
//! - Namespace node has string-value (the namespace URI)
//! - Parent is the element node
//! - No children

const std = @import("std");
const Allocator = std.mem.Allocator;
const NodeBase = @import("../node_base.zig").NodeBase;

/// Virtual namespace node for XPath namespace axis
///
/// Represents a namespace binding (prefix → URI) associated with an element.
/// These nodes are created on-demand when the namespace axis is evaluated.
pub const NamespaceNode = struct {
    allocator: Allocator,
    
    /// The prefix (empty string for default namespace)
    prefix: []const u8,
    
    /// The namespace URI
    namespace_uri: []const u8,
    
    /// Parent element (for XPath parent axis)
    parent_element: *NodeBase,
    
    /// Create a new namespace node
    pub fn init(
        allocator: Allocator,
        prefix: []const u8,
        namespace_uri: []const u8,
        parent_element: *NodeBase,
    ) !*NamespaceNode {
        const node = try allocator.create(NamespaceNode);
        errdefer allocator.destroy(node);
        
        node.* = .{
            .allocator = allocator,
            .prefix = try allocator.dupe(u8, prefix),
            .namespace_uri = try allocator.dupe(u8, namespace_uri),
            .parent_element = parent_element,
        };
        return node;
    }
    
    /// Clean up namespace node
    pub fn deinit(self: *NamespaceNode) void {
        self.allocator.free(self.prefix);
        self.allocator.free(self.namespace_uri);
        self.allocator.destroy(self);
    }
    
    /// Get expanded-name (the prefix)
    /// XPath 1.0 §5.4: The expanded-name of a namespace node is its prefix
    pub fn getExpandedName(self: *const NamespaceNode) []const u8 {
        return self.prefix;
    }
    
    /// Get string-value (the namespace URI)
    /// XPath 1.0 §5.4: The string-value is the namespace URI
    pub fn getStringValue(self: *const NamespaceNode) []const u8 {
        return self.namespace_uri;
    }
    
    /// Get parent element
    pub fn getParent(self: *const NamespaceNode) *NodeBase {
        return self.parent_element;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;





