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

test "XPathNode - DOM node creation" {
    var node: NodeBase = undefined;
    const xpath_node = XPathNode{ .dom_node = &node };
    
    try testing.expect(xpath_node.isDomNode());
    try testing.expect(!xpath_node.isNamespaceNode());
    try testing.expect(xpath_node.asDomNode() == &node);
    try testing.expect(xpath_node.asNamespaceNode() == null);
}

test "XPathNode - namespace node creation" {
    const allocator = testing.allocator;
    var parent: NodeBase = undefined;
    
    const ns_node = try NamespaceNode.init(
        allocator,
        "foo",
        "http://example.com",
        &parent,
    );
    defer ns_node.deinit();
    
    const xpath_node = XPathNode{ .namespace_node = ns_node };
    
    try testing.expect(!xpath_node.isDomNode());
    try testing.expect(xpath_node.isNamespaceNode());
    try testing.expect(xpath_node.asDomNode() == null);
    try testing.expect(xpath_node.asNamespaceNode() == ns_node);
}

test "XPathNode - getParent for DOM node" {
    var parent: NodeBase = undefined;
    var child: NodeBase = undefined;
    child.parent_node = &parent;
    
    const xpath_node = XPathNode{ .dom_node = &child };
    try testing.expect(xpath_node.getParent() == &parent);
}

test "XPathNode - getParent for namespace node" {
    const allocator = testing.allocator;
    var parent: NodeBase = undefined;
    
    const ns_node = try NamespaceNode.init(
        allocator,
        "foo",
        "http://example.com",
        &parent,
    );
    defer ns_node.deinit();
    
    const xpath_node = XPathNode{ .namespace_node = ns_node };
    try testing.expect(xpath_node.getParent() == &parent);
}

test "XPathNode - equality for DOM nodes" {
    var node1: NodeBase = undefined;
    var node2: NodeBase = undefined;
    
    const xpath1 = XPathNode{ .dom_node = &node1 };
    const xpath2 = XPathNode{ .dom_node = &node1 };
    const xpath3 = XPathNode{ .dom_node = &node2 };
    
    try testing.expect(xpath1.eql(xpath2));
    try testing.expect(!xpath1.eql(xpath3));
}

test "XPathNode - equality for namespace nodes" {
    const allocator = testing.allocator;
    var parent: NodeBase = undefined;
    
    const ns1 = try NamespaceNode.init(allocator, "foo", "http://example.com", &parent);
    defer ns1.deinit();
    const ns2 = try NamespaceNode.init(allocator, "foo", "http://example.com", &parent);
    defer ns2.deinit();
    const ns3 = try NamespaceNode.init(allocator, "bar", "http://example.com", &parent);
    defer ns3.deinit();
    
    const xpath1 = XPathNode{ .namespace_node = ns1 };
    const xpath2 = XPathNode{ .namespace_node = ns2 };
    const xpath3 = XPathNode{ .namespace_node = ns3 };
    
    try testing.expect(xpath1.eql(xpath2)); // Same prefix and parent
    try testing.expect(!xpath1.eql(xpath3)); // Different prefix
}

test "XPathNode - mixed type inequality" {
    const allocator = testing.allocator;
    var node: NodeBase = undefined;
    
    const ns = try NamespaceNode.init(allocator, "foo", "http://example.com", &node);
    defer ns.deinit();
    
    const xpath_dom = XPathNode{ .dom_node = &node };
    const xpath_ns = XPathNode{ .namespace_node = ns };
    
    try testing.expect(!xpath_dom.eql(xpath_ns));
}
