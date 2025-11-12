//! ElementWithBase - Temporary Element implementation with NodeBase
//!
//! This is a temporary type that demonstrates the NodeBase pattern for Elements.
//! It will be replaced once the WebIDL codegen is updated to automatically
//! generate this structure.
//!
//! Key difference from webidl/generated/dom/element.zig:
//! - Has `base: NodeBase` as the FIRST field (critical for safe casting)
//! - Allows safe downcasting from NodeBase* to ElementWithBase*
//! - Enables XPath to access Element.attributes from NodeBase* pointers
//!
//! TODO: Remove this file once webidl codegen generates NodeBase pattern automatically

const std = @import("std");
const infra = @import("infra");
const node_base = @import("node_base.zig");
const attr_with_base = @import("attr_with_base.zig");
const Allocator = std.mem.Allocator;

pub const NodeBase = node_base.NodeBase;
pub const AttrWithBase = attr_with_base.AttrWithBase;

/// Element with NodeBase integration
/// This demonstrates the pattern that codegen should eventually generate
pub const ElementWithBase = struct {
    // ========================================================================
    // CRITICAL: NodeBase MUST be the first field for safe @ptrCast
    // ========================================================================
    base: NodeBase,

    // ========================================================================
    // Element-specific fields
    // ========================================================================
    tag_name: []const u8,
    namespace_uri: ?[]const u8,
    attributes: infra.List(*AttrWithBase),

    /// Initialize a new Element
    pub fn init(allocator: Allocator, tag_name: []const u8) ElementWithBase {
        return .{
            .base = NodeBase{
                .allocator = allocator,
                .node_type = NodeBase.ELEMENT_NODE,
                .node_name = tag_name,
                .parent_node = null,
                .child_nodes = infra.List(*NodeBase).init(allocator),
                .owner_document = null,
                .registered_observers = std.ArrayList(node_base.RegisteredObserverType){},
            },
            .tag_name = tag_name,
            .namespace_uri = null,
            .attributes = infra.List(*AttrWithBase).init(allocator),
        };
    }

    /// Clean up resources
    pub fn deinit(self: *ElementWithBase) void {
        self.base.child_nodes.deinit();
        self.base.registered_observers.deinit(self.base.allocator);

        // Clean up attributes (they're heap-allocated)
        for (0..self.attributes.size()) |i| {
            if (self.attributes.get(i)) |attr| {
                attr.deinit();
                self.base.allocator.destroy(attr);
            }
        }
        self.attributes.deinit();
    }

    /// Upcast Element to NodeBase
    pub fn asNode(self: *ElementWithBase) *NodeBase {
        return &self.base;
    }

    /// Upcast Element to const NodeBase
    pub fn asNodeConst(self: *const ElementWithBase) *const NodeBase {
        return &self.base;
    }

    /// Get element's ID attribute
    pub fn getId(self: *const ElementWithBase) ?[]const u8 {
        for (0..self.attributes.size()) |i| {
            if (self.attributes.get(i)) |attr| {
                if (std.mem.eql(u8, attr.local_name, "id")) {
                    return attr.value;
                }
            }
        }
        return null;
    }

    /// Set element's ID attribute
    pub fn setId(self: *ElementWithBase, value: []const u8) !void {
        // Find existing id attribute
        for (0..self.attributes.size()) |i| {
            if (self.attributes.get(i)) |attr| {
                if (std.mem.eql(u8, attr.local_name, "id")) {
                    try attr.setValue(value);
                    return;
                }
            }
        }

        // Add new id attribute
        const attr = try self.base.allocator.create(AttrWithBase);
        errdefer self.base.allocator.destroy(attr);

        attr.* = try AttrWithBase.init(
            self.base.allocator,
            "id", // local_name
            value, // value
            null, // namespace_uri
            null, // prefix
        );
        try self.attributes.append(attr);
    }

    /// Get attribute by name
    pub fn getAttribute(self: *const ElementWithBase, name: []const u8) ?[]const u8 {
        for (0..self.attributes.size()) |i| {
            if (self.attributes.get(i)) |attr| {
                if (std.mem.eql(u8, attr.local_name, name)) {
                    return attr.value;
                }
            }
        }
        return null;
    }

    /// Set attribute
    pub fn setAttribute(self: *ElementWithBase, name: []const u8, value: []const u8) !void {
        // Find existing attribute
        for (0..self.attributes.size()) |i| {
            if (self.attributes.get(i)) |attr| {
                if (std.mem.eql(u8, attr.local_name, name)) {
                    try attr.setValue(value);
                    return;
                }
            }
        }

        // Add new attribute
        const attr = try self.base.allocator.create(AttrWithBase);
        errdefer self.base.allocator.destroy(attr);

        attr.* = try AttrWithBase.init(
            self.base.allocator,
            name, // local_name
            value, // value
            null, // namespace_uri
            null, // prefix
        );
        try self.attributes.append(attr);
    }
};
