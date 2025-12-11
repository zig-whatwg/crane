//! Slot Algorithm Helper Utilities
//!
//! KEEP: Uses *anyopaque for duck-typed polymorphism across node types.
//! These utilities enable slot algorithms to work with Element, Text, and
//! ShadowRoot without import cycles. The duck typing pattern uses @hasField
//! to access common fields across different node types.
//!
//! This module provides type-safe utilities for slot algorithms to work with
//! polymorphic node types. Uses duck typing to work with both interface and
//! implementation types.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

// Node type constants (from DOM spec)
pub const ELEMENT_NODE: u16 = 1;
pub const TEXT_NODE: u16 = 3;
pub const DOCUMENT_FRAGMENT_NODE: u16 = 11;

/// Check if a value has a node_type field (duck typing)
fn hasNodeType(comptime T: type) bool {
    return @hasField(T, "node_type");
}

/// Get node_type from any type that has it
fn getNodeType(node: anytype) u16 {
    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "node_type")) {
        return node.node_type;
    }
    // Fallback: assume it's something else
    return 0;
}

/// Check if a Node pointer is an Element (node_type == 1)
pub fn isElement(node: anytype) bool {
    return getNodeType(node) == ELEMENT_NODE;
}

/// Check if a Node pointer is a Text node (node_type == 3)
pub fn isText(node: anytype) bool {
    return getNodeType(node) == TEXT_NODE;
}

/// Check if a Node pointer is a DocumentFragment (node_type == 11)
pub fn isDocumentFragment(node: anytype) bool {
    return getNodeType(node) == DOCUMENT_FRAGMENT_NODE;
}

/// Check if a Node is a slottable (Element or Text)
/// DOM §4.3.7: Element and Text nodes are slottables
pub fn isSlottable(node: anytype) bool {
    const nt = getNodeType(node);
    return nt == ELEMENT_NODE or nt == TEXT_NODE;
}

/// Check if a Node is an HTMLSlotElement
/// For now, this checks if it's an element with local_name "slot"
pub fn isSlot(node: anytype) bool {
    if (!isElement(node)) return false;

    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;

    // Check if it has local_name field
    if (@hasField(ChildT, "local_name")) {
        return std.ascii.eqlIgnoreCase(node.local_name, "slot");
    }
    // Try tag_name
    if (@hasField(ChildT, "tag_name")) {
        return std.ascii.eqlIgnoreCase(node.tag_name, "slot");
    }
    return false;
}

/// Get the parent node if it has parent_node field
pub fn getParentNode(node: anytype) ?*@TypeOf(node.*) {
    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "parent_node")) {
        return node.parent_node;
    }
    return null;
}

/// Get the slottable name from a slottable
/// For Elements, this is the "slot" attribute value (via slottable_name field)
/// For Text nodes, this is always empty string
pub fn getSlottableName(node: anytype) []const u8 {
    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "slottable_name")) {
        return node.slottable_name;
    }
    return "";
}

/// Set the assigned slot for a slottable
pub fn setSlottableAssignedSlot(node: anytype, slot: ?*anyopaque) void {
    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "assigned_slot")) {
        node.assigned_slot = slot;
    }
}

/// Get the assigned slot for a slottable
pub fn getSlottableAssignedSlot(node: anytype) ?*anyopaque {
    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "assigned_slot")) {
        return node.assigned_slot;
    }
    return null;
}

/// Get the manual slot assignment for a slottable
pub fn getSlottableManualAssignment(node: anytype) ?*anyopaque {
    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "manual_slot_assignment")) {
        return node.manual_slot_assignment;
    }
    return null;
}

/// Set the manual slot assignment for a slottable
pub fn setSlottableManualAssignment(node: anytype, slot: ?*anyopaque) void {
    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "manual_slot_assignment")) {
        node.manual_slot_assignment = slot;
    }
}

/// Get the name of a slot element
/// Returns empty string if not a slot or name not found (which means default slot)
pub fn getSlotName(slot_node: anytype) []const u8 {
    if (!isSlot(slot_node)) return "";

    const T = @TypeOf(slot_node);
    const ChildT = @typeInfo(T).pointer.child;

    // Try to get "name" attribute via call_getAttribute if available
    if (@hasDecl(ChildT, "call_getAttribute")) {
        if (slot_node.call_getAttribute("name")) |name| {
            return name;
        }
    }
    return "";
}

/// Check if node is a shadow host (has a shadow root attached)
pub fn isShadowHost(node: anytype) bool {
    if (!isElement(node)) return false;

    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "shadow_root")) {
        return node.shadow_root != null;
    }
    return false;
}

/// Get the shadow root of an element (if it's a shadow host)
pub fn getShadowRoot(node: anytype) ?*anyopaque {
    if (!isElement(node)) return null;

    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "shadow_root")) {
        if (node.shadow_root) |sr| {
            return @ptrCast(sr);
        }
    }
    return null;
}

/// Get the children of a node as a slice
pub fn getChildNodes(node: anytype) []const *anyopaque {
    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "child_nodes")) {
        const slice = node.child_nodes.toSlice();
        // Cast the slice (this is safe because we're just reinterpreting the pointer type)
        return @as([*]const *anyopaque, @ptrCast(slice.ptr))[0..slice.len];
    }
    return &.{};
}

/// Get the root node of a node
pub fn getRoot(node: anytype) *anyopaque {
    var current = node;
    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;

    if (@hasField(ChildT, "parent_node")) {
        while (current.parent_node) |parent| {
            current = parent;
        }
    }
    return @ptrCast(current);
}

/// Check if a node is a ShadowRoot
/// ShadowRoot is a DocumentFragment with a host field
pub fn isShadowRoot(node: anytype) bool {
    if (!isDocumentFragment(node)) return false;

    const T = @TypeOf(node);
    const ChildT = @typeInfo(T).pointer.child;
    if (@hasField(ChildT, "host")) {
        return node.host != null;
    }
    return false;
}

/// Cast to ShadowRoot if it is one
pub fn asShadowRoot(node: anytype) ?*anyopaque {
    if (isShadowRoot(node)) {
        return @ptrCast(node);
    }
    return null;
}

/// Check if ancestor is an inclusive ancestor of descendant
pub fn isInclusiveAncestor(ancestor: anytype, descendant: anytype) bool {
    // Same node?
    if (@as(*anyopaque, @ptrCast(ancestor)) == @as(*anyopaque, @ptrCast(descendant))) {
        return true;
    }

    // Walk up from descendant
    const T = @TypeOf(descendant);
    const ChildT = @typeInfo(T).pointer.child;

    if (@hasField(ChildT, "parent_node")) {
        var current = descendant.parent_node;
        while (current) |node| {
            if (@as(*anyopaque, @ptrCast(node)) == @as(*anyopaque, @ptrCast(ancestor))) {
                return true;
            }
            current = node.parent_node;
        }
    }

    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "slot_helpers: basic type checks" {
    // Just verify the module compiles
    try std.testing.expect(ELEMENT_NODE == 1);
    try std.testing.expect(TEXT_NODE == 3);
}
