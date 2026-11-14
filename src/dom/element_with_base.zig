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
const refcount = @import("refcount.zig");
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
    pub fn init(allocator: *const Allocator, tag_name: []const u8) ElementWithBase {
        return .{
            .base = NodeBase{
                .owner = NodeBase.ownerless(allocator),
                .node_type = NodeBase.ELEMENT_NODE,
                .parent_node = null,
            },
            .tag_name = tag_name,
            .namespace_uri = null,
            .attributes = infra.List(*AttrWithBase).init(allocator.*),
            .class_bloom_filter = infra.BloomFilter.init(),
            .unique_id = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *ElementWithBase) void {
        self.base.deinitRareData();

        // Clean up attributes (they're heap-allocated)
        for (0..self.attributes.size()) |i| {
            if (self.attributes.get(i)) |attr| {
                attr.deinit();
                self.base.allocator().destroy(attr);
            }
        }
        self.attributes.deinit();

        // Clean up unique ID if set
        if (self.unique_id) |id| {
            self.base.allocator().free(id);
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
        const attr = try self.base.allocator().create(AttrWithBase);
        errdefer self.base.allocator().destroy(attr);

        attr.* = try AttrWithBase.init(
            self.base.ownerlessAllocator(),
            "id", // local_name
            value, // value
            null, // namespace_uri
            null, // prefix
        );
        try self.attributes.append(attr);
    }

    /// Get attribute by name (case-sensitive)
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

    /// Get attribute by name (case-insensitive for HTML elements)
    /// Per HTML spec, attribute names are ASCII case-insensitive
    pub fn getAttributeCaseInsensitive(self: *const ElementWithBase, name: []const u8) ?[]const u8 {
        for (0..self.attributes.size()) |i| {
            if (self.attributes.get(i)) |attr| {
                if (std.ascii.eqlIgnoreCase(attr.local_name, name)) {
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
        const attr = try self.base.allocator().create(AttrWithBase);
        errdefer self.base.allocator().destroy(attr);

        attr.* = try AttrWithBase.init(
            self.base.ownerlessAllocator(),
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

    // ========================================================================
    // Node interface methods (for test compatibility)
    // ========================================================================

    /// Append a child node
    /// Simplified version for testing - doesn't implement full DOM spec
    pub fn appendChild(self: *ElementWithBase, child: *NodeBase) !*NodeBase {
        // Set parent relationship (and the holds it moves: refcount). This
        // simplified helper never took a child out of an old parent's list;
        // its counts leave the old chain all the same.
        if (child.parent_node) |old_parent| {
            old_parent.unlinkChild(child);
            refcount.unlinkChild(child);
        }
        refcount.linkChild(child, &self.base);

        // Link it last (a node's children are its sibling links:
        // NodeBase.children)
        self.base.linkChildBefore(child, null);

        return child;
    }

    /// Remove a child node
    /// Simplified version for testing
    pub fn removeChild(self: *ElementWithBase, child: *NodeBase) !*NodeBase {
        if (child.parent_node != &self.base) return error.NotFoundError;
        // Unlink it (a node's children are its sibling links)
        self.base.unlinkChild(child);
        refcount.unlinkChild(child);
        return child;
    }

    /// Get first child
    pub fn getFirstChild(self: *const ElementWithBase) ?*NodeBase {
        return self.base.first_child;
    }

    /// Get last child
    pub fn getLastChild(self: *const ElementWithBase) ?*NodeBase {
        return self.base.lastChild();
    }

    /// Check if element has children
    pub fn hasChildNodes(self: *const ElementWithBase) bool {
        return self.base.first_child != null;
    }

    /// Get child nodes count
    pub fn getChildCount(self: *const ElementWithBase) usize {
        return self.base.childCount();
    }
};

comptime {
    // Several call sites still recover a *ElementWithBase from its `base` field. The
    // safe ones use @fieldParentPtr; any that cast assume offset 0, which auto
    // layout does NOT promise - it orders by descending alignment, so adding a
    // low-alignment field ahead of `base` would silently move it and corrupt
    // every such recovery. Make that a compile error instead.
    if (@offsetOf(ElementWithBase, "base") != 0) {
        @compileError("ElementWithBase.base must remain at offset 0; a caller recovers the parent by casting");
    }
}
