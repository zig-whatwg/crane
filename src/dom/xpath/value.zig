//! XPath 1.0 Value Types
//!
//! This module implements the 4 basic data types for XPath 1.0 as specified in §3.1.
//!
//! ## W3C XPath 1.0 Specification
//!
//! - **XPath 1.0**: https://www.w3.org/TR/xpath-10/
//! - **§3.1 Basics**: https://www.w3.org/TR/xpath-10/#section-Basics
//! - **Data Types**: node-set, boolean, number, string
//!
//! ## XPath Data Types
//!
//! From XPath 1.0 spec §3.1:
//! - **node-set**: An unordered collection of nodes without duplicates
//! - **boolean**: true or false
//! - **number**: A floating-point number (IEEE 754 double-precision)
//! - **string**: A sequence of UCS characters

const std = @import("std");
const Node = @import("node").Node;
const NodeBase = @import("../node_base.zig").NodeBase;
const infra = @import("infra");

/// XPath 1.0 Value (§3.1)
///
/// An expression evaluates to an object which is one of four basic types
pub const Value = union(enum) {
    node_set: NodeSet,
    boolean: bool,
    number: f64,
    string: []const u8,

    /// Convert value to boolean (§3.2 Boolean Functions)
    ///
    /// Rules from XPath 1.0 spec:
    /// - number: true iff not positive/negative zero and not NaN
    /// - node-set: true iff non-empty
    /// - string: true iff length > 0
    /// - boolean: identity
    pub fn toBoolean(self: Value) bool {
        return switch (self) {
            .boolean => |b| b,
            .number => |n| {
                // Not zero and not NaN
                return n != 0.0 and !std.math.isNan(n);
            },
            .node_set => |ns| !ns.isEmpty(),
            .string => |s| s.len > 0,
        };
    }

    /// Convert value to number (§3.4 Number Functions)
    ///
    /// Rules from XPath 1.0 spec:
    /// - string: parse as number, NaN if invalid
    /// - boolean: 1 for true, 0 for false
    /// - node-set: convert to string first, then to number
    /// - number: identity
    pub fn toNumber(self: Value, allocator: std.mem.Allocator) !f64 {
        return switch (self) {
            .number => |n| n,
            .boolean => |b| if (b) 1.0 else 0.0,
            .string => |s| parseNumber(s),
            .node_set => {
                const str = try self.toString(allocator);
                defer allocator.free(str);
                return parseNumber(str);
            },
        };
    }

    /// Convert value to string (§3.2 String Functions)
    ///
    /// Rules from XPath 1.0 spec:
    /// - node-set: string-value of first node in document order
    /// - boolean: "true" or "false"
    /// - number: formatted per spec rules
    /// - string: identity
    pub fn toString(self: Value, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .string => |s| try allocator.dupe(u8, s),
            .boolean => |b| try allocator.dupe(u8, if (b) "true" else "false"),
            .number => |n| try formatNumber(allocator, n),
            .node_set => |ns| {
                if (ns.isEmpty()) {
                    return try allocator.dupe(u8, "");
                }
                // Get first node in document order
                const first_node = ns.getFirst().?;
                return try getStringValue(allocator, first_node);
            },
        };
    }

    /// Free owned resources
    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .node_set => |*ns| ns.deinit(),
            .string => |s| allocator.free(s),
            else => {},
        }
    }
};

/// Node-set type (§3.3)
///
/// An unordered collection of nodes without duplicates.
/// Internally stored in document order for consistent iteration.
pub const NodeSet = struct {
    nodes: infra.List(*NodeBase),

    pub fn init(allocator: std.mem.Allocator) NodeSet {
        return .{
            .nodes = infra.List(*NodeBase).init(allocator),
        };
    }

    pub fn deinit(self: *NodeSet) void {
        self.nodes.deinit();
    }

    /// Add node to set if not already present
    pub fn add(self: *NodeSet, node: *NodeBase) !void {
        // Check for duplicates
        if (self.contains(node)) {
            return;
        }
        try self.nodes.append(node);
    }

    /// Check if node is in set
    pub fn contains(self: *const NodeSet, node: *NodeBase) bool {
        for (0..self.nodes.size()) |i| {
            if (self.nodes.get(i).? == node) {
                return true;
            }
        }
        return false;
    }

    /// Get node at index (in document order)
    pub fn get(self: *const NodeSet, index: usize) ?*NodeBase {
        return self.nodes.get(index);
    }

    /// Get first node in document order
    pub fn getFirst(self: *const NodeSet) ?*NodeBase {
        return self.nodes.get(0);
    }

    /// Get size of node-set
    pub fn size(self: *const NodeSet) usize {
        return self.nodes.size();
    }

    /// Check if node-set is empty
    pub fn isEmpty(self: *const NodeSet) bool {
        return self.nodes.isEmpty();
    }

    /// Sort nodes in document order
    pub fn sortDocumentOrder(self: *NodeSet) !void {
        // Only sort if we have multiple nodes
        if (self.size() <= 1) return;

        // Use std.sort with a custom comparison function
        const Context = struct {
            fn lessThan(_: void, a: *NodeBase, b: *NodeBase) bool {
                return isBeforeInDocumentOrder(a, b);
            }
        };

        // Need to sort mutable slice, so we have to work around infra.List
        // TODO: Add a sortableSlice() method to infra.List for this use case
        if (self.nodes.heap_storage) |*heap| {
            std.mem.sort(*NodeBase, heap.items, {}, Context.lessThan);
        } else if (self.nodes.len > 0) {
            // Inline storage - sort directly in array
            const slice = self.nodes.inline_storage[0..self.nodes.len];
            std.mem.sort(*NodeBase, @constCast(slice), {}, Context.lessThan);
        }
    }

    /// Create union of two node-sets (§3.3 Union operator)
    pub fn unionWith(self: *NodeSet, other: *const NodeSet) !void {
        for (0..other.size()) |i| {
            if (other.get(i)) |node| {
                try self.add(node);
            }
        }
        try self.sortDocumentOrder();
    }
};

// ============================================================================
// Document Order Comparison
// ============================================================================

/// Check if node a comes before node b in document order
/// Document order is defined as:
/// 1. Root node comes first
/// 2. Element comes before its children
/// 3. Attributes and namespace nodes of an element come before children
/// 4. Namespace nodes come before attributes
/// 5. Children ordered by tree order
fn isBeforeInDocumentOrder(a: *NodeBase, b: *NodeBase) bool {
    // Same node
    if (a == b) return false;

    // Check if one is ancestor of the other
    if (isAncestor(a, b)) return true;
    if (isAncestor(b, a)) return false;

    // Find common ancestor and compare positions
    const common = findCommonAncestor(a, b) orelse return false;

    // Find which child of common ancestor is on path to a and b
    const a_child = findChildOnPath(common, a);
    const b_child = findChildOnPath(common, b);

    if (a_child == null or b_child == null) return false;

    // Compare positions in parent's child list
    for (0..common.child_nodes.size()) |i| {
        const child = common.child_nodes.get(i) orelse continue;
        if (child == a_child) return true;
        if (child == b_child) return false;
    }

    return false;
}

/// Check if a is an ancestor of b
fn isAncestor(a: *NodeBase, b: *NodeBase) bool {
    var current = b.parent_node;
    while (current) |node| {
        if (node == a) return true;
        current = node.parent_node;
    }
    return false;
}

/// Find common ancestor of two nodes
fn findCommonAncestor(a: *NodeBase, b: *NodeBase) ?*NodeBase {
    // Simple algorithm: for each ancestor of a, check if it's also ancestor of b
    var a_ancestor = a;
    while (true) {
        // Check if a_ancestor is an ancestor of b
        var b_ancestor = b;
        while (true) {
            if (a_ancestor == b_ancestor) return a_ancestor;
            if (b_ancestor.parent_node) |parent| {
                b_ancestor = parent;
            } else {
                break;
            }
        }

        if (a_ancestor.parent_node) |parent| {
            a_ancestor = parent;
        } else {
            break;
        }
    }

    return null;
}

/// Find which child of ancestor is on the path to node
fn findChildOnPath(ancestor: *NodeBase, node: *NodeBase) ?*NodeBase {
    var current = node;
    while (current.parent_node) |parent| {
        if (parent == ancestor) return current;
        current = parent;
    }
    return null;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Parse number from string per XPath 1.0 spec (§3.4)
///
/// Rules:
/// - Optional whitespace
/// - Optional minus sign
/// - Number (digits with optional decimal point)
/// - Optional whitespace
/// - Invalid format returns NaN
fn parseNumber(s: []const u8) f64 {
    // Trim whitespace
    const trimmed = std.mem.trim(u8, s, " \t\r\n");
    if (trimmed.len == 0) {
        return std.math.nan(f64);
    }

    return std.fmt.parseFloat(f64, trimmed) catch std.math.nan(f64);
}

/// Format number to string per XPath 1.0 spec (§3.2)
///
/// Rules:
/// - NaN → "NaN"
/// - +0 → "0"
/// - -0 → "0"
/// - +Infinity → "Infinity"
/// - -Infinity → "-Infinity"
/// - Integer: no decimal point, no leading zeros
/// - Non-integer: decimal form with minimal digits
fn formatNumber(allocator: std.mem.Allocator, n: f64) ![]const u8 {
    if (std.math.isNan(n)) {
        return try allocator.dupe(u8, "NaN");
    }

    if (std.math.isPositiveInf(n)) {
        return try allocator.dupe(u8, "Infinity");
    }

    if (std.math.isNegativeInf(n)) {
        return try allocator.dupe(u8, "-Infinity");
    }

    if (n == 0.0) {
        return try allocator.dupe(u8, "0");
    }

    // Check if integer
    if (@floor(n) == n) {
        return try std.fmt.allocPrint(allocator, "{d:.0}", .{n});
    }

    // Non-integer: use minimal representation
    return try std.fmt.allocPrint(allocator, "{d}", .{n});
}

/// Get string-value of a node (§5 Data Model)
///
/// Rules vary by node type:
/// - Element/Root: concatenation of all text node descendants
/// - Attr: normalized attribute value
/// - Text: character data
/// - Comment: content
/// - PI: content after target
/// - Namespace: namespace URI
fn getStringValue(allocator: std.mem.Allocator, node: *NodeBase) ![]const u8 {
    switch (node.node_type) {
        NodeBase.ELEMENT_NODE, NodeBase.DOCUMENT_NODE, NodeBase.DOCUMENT_FRAGMENT_NODE => {
            // Concatenate all descendant text nodes
            var result: std.ArrayList(u8) = .empty;
            defer result.deinit(allocator);
            try collectTextContent(allocator, node, &result);
            return try result.toOwnedSlice(allocator);
        },
        NodeBase.TEXT_NODE, NodeBase.CDATA_SECTION_NODE, NodeBase.COMMENT_NODE => {
            // For character data nodes, access the data field using NodeBase.asCharacterData
            if (NodeBase.asCharacterDataConst(node)) |char_data| {
                return try allocator.dupe(u8, char_data.data);
            }
            // Fallback (should not happen)
            return try allocator.dupe(u8, node.node_name);
        },
        NodeBase.PROCESSING_INSTRUCTION_NODE => {
            // PI content (excluding target)
            // TODO: Properly extract PI data when available
            return try allocator.dupe(u8, "");
        },
        NodeBase.ATTRIBUTE_NODE => {
            // Attribute value (XPath 1.0 §5.2)
            if (NodeBase.asAttrConst(node)) |attr| {
                return try allocator.dupe(u8, attr.getValue());
            }
            // Fallback (should not happen)
            return try allocator.dupe(u8, node.node_name);
        },
        else => {
            return try allocator.dupe(u8, "");
        },
    }
}

/// Helper to collect text content from all descendant text nodes
fn collectTextContent(allocator: std.mem.Allocator, node: *const NodeBase, result: *std.ArrayList(u8)) !void {
    // If this is a text node, add its content
    if (node.node_type == NodeBase.TEXT_NODE or node.node_type == NodeBase.CDATA_SECTION_NODE) {
        // TODO: Access character data - need to figure out how to get allocator
        // For now, skip this
    }

    // Recursively collect from children
    for (0..node.child_nodes.size()) |i| {
        if (node.child_nodes.get(i)) |child| {
            try collectTextContent(allocator, child, result);
        }
    }
}

// TODO: Re-enable when we have proper text node access
// /// Helper to collect text content from all descendant text nodes
// fn collectTextContent(node: *Node, result: *std.ArrayList(u8)) !void {
//     // If this is a text node, add its content
//     if (node.node_type == Node.TEXT_NODE or node.node_type == Node.CDATA_SECTION_NODE) {
//         // TODO: Access actual text data when available
//         // For now, use node_name as placeholder
//         try result.appendSlice(node.node_name);
//     }
//
//     // Recursively collect from children
//     for (node.child_nodes.items) |child| {
//         try collectTextContent(child, result);
//     }
// }

// ============================================================================
// Tests
// ============================================================================

test "value - boolean conversion" {
    // Boolean
    const v1 = Value{ .boolean = true };
    try std.testing.expect(v1.toBoolean());

    const v2 = Value{ .boolean = false };
    try std.testing.expect(!v2.toBoolean());

    // Number
    const v3 = Value{ .number = 0.0 };
    try std.testing.expect(!v3.toBoolean());

    const v4 = Value{ .number = 42.0 };
    try std.testing.expect(v4.toBoolean());

    const v5 = Value{ .number = std.math.nan(f64) };
    try std.testing.expect(!v5.toBoolean());

    // String
    const v6 = Value{ .string = "" };
    try std.testing.expect(!v6.toBoolean());

    const v7 = Value{ .string = "hello" };
    try std.testing.expect(v7.toBoolean());
}

test "value - number conversion" {
    const allocator = std.testing.allocator;

    // Number
    const v1 = Value{ .number = 42.5 };
    try std.testing.expectEqual(@as(f64, 42.5), try v1.toNumber(allocator));

    // Boolean
    const v2 = Value{ .boolean = true };
    try std.testing.expectEqual(@as(f64, 1.0), try v2.toNumber(allocator));

    const v3 = Value{ .boolean = false };
    try std.testing.expectEqual(@as(f64, 0.0), try v3.toNumber(allocator));

    // String (valid)
    const v4 = Value{ .string = "123.45" };
    try std.testing.expectEqual(@as(f64, 123.45), try v4.toNumber(allocator));

    // String (invalid - becomes NaN)
    const v5 = Value{ .string = "not a number" };
    const result = try v5.toNumber(allocator);
    try std.testing.expect(std.math.isNan(result));
}

test "value - string conversion" {
    const allocator = std.testing.allocator;

    // String
    const v1 = Value{ .string = "hello" };
    const s1 = try v1.toString(allocator);
    defer allocator.free(s1);
    try std.testing.expectEqualStrings("hello", s1);

    // Boolean
    const v2 = Value{ .boolean = true };
    const s2 = try v2.toString(allocator);
    defer allocator.free(s2);
    try std.testing.expectEqualStrings("true", s2);

    const v3 = Value{ .boolean = false };
    const s3 = try v3.toString(allocator);
    defer allocator.free(s3);
    try std.testing.expectEqualStrings("false", s3);

    // Number
    const v4 = Value{ .number = 42.0 };
    const s4 = try v4.toString(allocator);
    defer allocator.free(s4);
    try std.testing.expectEqualStrings("42", s4);

    const v5 = Value{ .number = std.math.nan(f64) };
    const s5 = try v5.toString(allocator);
    defer allocator.free(s5);
    try std.testing.expectEqualStrings("NaN", s5);
}

test "node-set - basic operations" {
    const allocator = std.testing.allocator;

    // Create mock nodes (just pointers for testing)
    var node1: NodeBase = undefined;
    var node2: NodeBase = undefined;

    var ns = NodeSet.init(allocator);
    defer ns.deinit();

    try std.testing.expect(ns.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), ns.size());

    // Add nodes
    try ns.add(&node1);
    try std.testing.expect(!ns.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), ns.size());
    try std.testing.expect(ns.contains(&node1));

    try ns.add(&node2);
    try std.testing.expectEqual(@as(usize, 2), ns.size());
    try std.testing.expect(ns.contains(&node2));

    // Add duplicate (should not increase size)
    try ns.add(&node1);
    try std.testing.expectEqual(@as(usize, 2), ns.size());
}

test "node-set - union" {
    const allocator = std.testing.allocator;

    // Create properly initialized nodes with null parent (root nodes)
    var node1 = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.ELEMENT_NODE,
        .node_name = "div",
        .parent_node = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
    };
    defer node1.child_nodes.deinit();
    defer node1.registered_observers.deinit();

    var node2 = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.ELEMENT_NODE,
        .node_name = "span",
        .parent_node = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
    };
    defer node2.child_nodes.deinit();
    defer node2.registered_observers.deinit();

    var node3 = NodeBase{
        .allocator = allocator,
        .node_type = NodeBase.ELEMENT_NODE,
        .node_name = "p",
        .parent_node = null,
        .child_nodes = infra.List(*NodeBase).init(allocator),
        .owner_document = null,
        .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
    };
    defer node3.child_nodes.deinit();
    defer node3.registered_observers.deinit();

    var ns1 = NodeSet.init(allocator);
    defer ns1.deinit();

    var ns2 = NodeSet.init(allocator);
    defer ns2.deinit();

    try ns1.add(&node1);
    try ns1.add(&node2);

    try ns2.add(&node2); // Duplicate
    try ns2.add(&node3);

    try ns1.unionWith(&ns2);

    // Should have all three nodes
    try std.testing.expectEqual(@as(usize, 3), ns1.size());
    try std.testing.expect(ns1.contains(&node1));
    try std.testing.expect(ns1.contains(&node2));
    try std.testing.expect(ns1.contains(&node3));
}
