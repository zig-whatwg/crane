//! AttrWithBase - Temporary Attr implementation with NodeBase
//!
//! This is a temporary type that demonstrates the NodeBase pattern for Attr nodes.
//! Attributes in XPath 1.0 are treated as nodes with special properties.
//!
//! Key difference from webidl/generated/dom/attr.zig:
//! - Has `base: NodeBase` as the FIRST field (critical for safe casting)
//! - Allows safe downcasting from NodeBase* to AttrWithBase*
//! - Enables XPath to access attribute values from NodeBase* pointers
//!
//! TODO: Remove this file once webidl codegen generates NodeBase pattern automatically

const std = @import("std");
const node_base = @import("node_base.zig");
const Allocator = std.mem.Allocator;

pub const NodeBase = node_base.NodeBase;

/// Attribute node with NodeBase integration
/// Represents an attribute on an element (XPath 1.0 §5.2)
pub const AttrWithBase = struct {
    // ========================================================================
    // CRITICAL: NodeBase MUST be the first field for safe @ptrCast
    // ========================================================================
    base: NodeBase,

    // ========================================================================
    // Attr-specific fields
    // ========================================================================

    /// The attribute's local name (a non-empty string)
    local_name: []const u8,

    /// The attribute's value (a string)
    value: []const u8,

    /// The attribute's namespace URI (null or a non-empty string)
    namespace_uri: ?[]const u8,

    /// The attribute's namespace prefix (null or a non-empty string)
    prefix: ?[]const u8,

    /// The element this attribute belongs to (weak reference)
    owner_element: ?*anyopaque,

    /// Initialize a new Attr node
    pub fn init(
        allocator: Allocator,
        local_name: []const u8,
        value: []const u8,
        namespace_uri: ?[]const u8,
        prefix: ?[]const u8,
    ) !AttrWithBase {
        // Build the node name (with prefix if present)
        const node_name = if (prefix) |p|
            try std.fmt.allocPrint(allocator, "{s}:{s}", .{ p, local_name })
        else
            try allocator.dupe(u8, local_name);

        return .{
            .base = NodeBase{
                .allocator = allocator,
                .node_type = NodeBase.ATTRIBUTE_NODE,
                .node_name = node_name,
                .parent_node = null,
                .child_nodes = @import("infra").List(*NodeBase).init(allocator),
                .owner_document = null,
                .registered_observers = std.ArrayList(node_base.RegisteredObserverType){},
            },
            .local_name = try allocator.dupe(u8, local_name),
            .value = try allocator.dupe(u8, value),
            .namespace_uri = if (namespace_uri) |ns| try allocator.dupe(u8, ns) else null,
            .prefix = if (prefix) |p| try allocator.dupe(u8, p) else null,
            .owner_element = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *AttrWithBase) void {
        self.base.allocator.free(self.base.node_name);
        self.base.allocator.free(self.local_name);
        self.base.allocator.free(self.value);
        if (self.namespace_uri) |ns| self.base.allocator.free(ns);
        if (self.prefix) |p| self.base.allocator.free(p);
        self.base.child_nodes.deinit();
        self.base.registered_observers.deinit(self.base.allocator);
    }

    /// Upcast Attr to NodeBase
    pub fn asNode(self: *AttrWithBase) *NodeBase {
        return &self.base;
    }

    /// Upcast Attr to const NodeBase
    pub fn asNodeConst(self: *const AttrWithBase) *const NodeBase {
        return &self.base;
    }

    /// Get the qualified name (prefix:localName or just localName)
    pub fn getQualifiedName(self: *const AttrWithBase) []const u8 {
        return self.base.node_name;
    }

    /// Get the attribute's local name
    pub fn getLocalName(self: *const AttrWithBase) []const u8 {
        return self.local_name;
    }

    /// Get the attribute's value
    pub fn getValue(self: *const AttrWithBase) []const u8 {
        return self.value;
    }

    /// Set the attribute's value
    pub fn setValue(self: *AttrWithBase, new_value: []const u8) !void {
        self.base.allocator.free(self.value);
        self.value = try self.base.allocator.dupe(u8, new_value);
    }

    /// Get the attribute's namespace URI
    pub fn getNamespaceURI(self: *const AttrWithBase) ?[]const u8 {
        return self.namespace_uri;
    }

    /// Get the attribute's prefix
    pub fn getPrefix(self: *const AttrWithBase) ?[]const u8 {
        return self.prefix;
    }
};
