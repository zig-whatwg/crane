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
//! NOTE: Codegen now generates NodeBase, but this is still used by XPath and selectors.
//! Can be migrated to generated types once dependencies are updated to use webidl/generated/dom/Element.zig

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

    /// Bloom filter for fast class membership testing
    /// Optimizes selector matching by providing O(1) negative lookups
    /// Updated automatically when class attribute changes
    class_bloom_filter: infra.BloomFilter,

    /// Element's unique identifier (ID)
    /// Spec: https://dom.spec.whatwg.org/#concept-id
    /// Set/unset by attribute change steps when id attribute changes
    unique_id: ?[]const u8,

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
                .registered_observers = infra.List(node_base.RegisteredObserverType).init(allocator),
            },
            .tag_name = tag_name,
            .namespace_uri = null,
            .attributes = infra.List(*AttrWithBase).init(allocator),
            .class_bloom_filter = infra.BloomFilter.init(),
            .unique_id = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *ElementWithBase) void {
        self.base.child_nodes.deinit();
        self.base.registered_observers.deinit();

        // Clean up attributes (they're heap-allocated)
        for (0..self.attributes.size()) |i| {
            if (self.attributes.get(i)) |attr| {
                attr.deinit();
                self.base.allocator.destroy(attr);
            }
        }
        self.attributes.deinit();

        // Clean up unique ID if set
        if (self.unique_id) |id| {
            self.base.allocator.free(id);
        }
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
                    // Update bloom filter if class attribute changed
                    if (std.mem.eql(u8, name, "class")) {
                        self.rebuildClassBloomFilter();
                    }
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

        // Update bloom filter if class attribute was added
        if (std.mem.eql(u8, name, "class")) {
            self.rebuildClassBloomFilter();
        }
    }

    /// Rebuild the class bloom filter from the current class attribute
    /// Called automatically when class attribute changes
    fn rebuildClassBloomFilter(self: *ElementWithBase) void {
        self.class_bloom_filter.clear();

        const class_attr = self.getAttribute("class") orelse return;

        // Split class attribute on whitespace and add each class to bloom filter
        var iter = std.mem.tokenizeAny(u8, class_attr, " \t\n\r");
        while (iter.next()) |class_name| {
            self.class_bloom_filter.add(class_name);
        }
    }
};
