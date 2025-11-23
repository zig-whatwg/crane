//! Slot Algorithm Helper Utilities
//!
//! This module provides type-safe utilities for slot algorithms to work with
//! polymorphic node types.
//!
//! TODO: These functions need to be updated to work with WebIDL-generated Node interface
//! which doesn't have direct node_type field access. For now, stubbed to compile.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import DOM types from root
const dom = @import("root.zig");
const Node = dom.Node;
const Element = dom.Element;
const ShadowRoot = dom.ShadowRoot;
const HTMLSlotElement = dom.HTMLSlotElement;
const tree_helpers = @import("tree_helpers.zig");

/// Check if a Node pointer is an Element
/// TODO: Implement runtime type checking for WebIDL-generated types
pub fn isElement(node: *const anyopaque) bool {
    _ = node;
    // TODO: Need runtime type information from WebIDL instances
    return false;
}

/// Check if a Node pointer is a ShadowRoot (DocumentFragment subtype)
/// TODO: Implement runtime type checking for WebIDL-generated types
pub fn isShadowRoot(node: *const anyopaque) bool {
    _ = node;
    // TODO: Need runtime type information from WebIDL instances
    return false;
}

/// Try to cast a Node to an Element
/// Returns null if the node is not an Element
/// TODO: Implement runtime type checking for WebIDL-generated types
pub fn asElement(node: *anyopaque) ?*Element {
    _ = node;
    // TODO: Need runtime type information from WebIDL instances
    return null;
}

/// Try to cast a Node to a const Element
/// Returns null if the node is not an Element
/// TODO: Implement runtime type checking for WebIDL-generated types
pub fn asElementConst(node: *const anyopaque) ?*const Element {
    _ = node;
    // TODO: Need runtime type information from WebIDL instances
    return null;
}

/// Try to cast a Node to a ShadowRoot
/// Returns null if the node is not a ShadowRoot
/// TODO: Implement runtime type checking for WebIDL-generated types
pub fn asShadowRoot(node: *anyopaque) ?*ShadowRoot {
    _ = node;
    // TODO: Need runtime type information from WebIDL instances
    return null;
}

/// Try to cast a Node to a const ShadowRoot
/// Returns null if the node is not a ShadowRoot
/// TODO: Implement runtime type checking for WebIDL-generated types
pub fn asShadowRootConst(node: *const anyopaque) ?*const ShadowRoot {
    _ = node;
    // TODO: Need runtime type information from WebIDL instances
    return null;
}

/// Check if a Node is a slottable (Element or Text)
pub fn isSlottable(node: *const anyopaque) bool {
    const node_ptr: *const Node = @ptrCast(@alignCast(node));
    // Elements and Text nodes are slottables
    return node_ptr.node_type == Node.ELEMENT_NODE or
        node_ptr.node_type == Node.TEXT_NODE;
}

/// Check if a Node is an HTMLSlotElement
/// For now, this checks if it's an element with tag name "slot"
pub fn isSlot(node: *const anyopaque) bool {
    if (asElementConst(node)) |element| {
        // TODO: When HTMLSlotElement is fully integrated, use proper type check
        // For now, check tag name
        return std.mem.eql(u8, element.tag_name, "slot");
    }
    return false;
}

/// Try to cast an Element to an HTMLSlotElement
/// Returns null if the element is not a slot
pub fn asSlot(node: *anyopaque) ?*HTMLSlotElement {
    if (isSlot(node)) {
        // Since HTMLSlotElement is currently a standalone struct (not extending Element),
        // this is a placeholder that will need proper integration
        // TODO: Implement proper HTMLSlotElement → Element relationship
        return null;
    }
    return null;
}

/// Get the parent Element of a Node (if parent exists and is an Element)
pub fn getParentElement(node: *anyopaque) ?*Element {
    const node_ptr: *Node = @ptrCast(@alignCast(node));
    if (node_ptr.get_parentNode()) |parent| {
        return asElement(@ptrCast(@constCast(parent)));
    }
    return null;
}

/// Get the root node of a node
pub fn getRoot(node: *anyopaque) *anyopaque {
    const node_ptr: *Node = @ptrCast(@alignCast(node));
    const root = node_ptr.call_getRootNode(null);
    return @ptrCast(root);
}

/// Get the slottable name from a slottable (Element or Text)
/// Returns empty string if not accessible
pub fn getSlottableName(node: *const anyopaque) []const u8 {
    if (asElementConst(node)) |element| {
        // Element has Slottable mixin fields flattened into Element struct
        // Call the generated getter method
        return element.getSlottableName();
    }
    // TODO: Handle Text nodes when they have Slottable mixin accessible
    return "";
}

/// Set the assigned slot for a slottable
pub fn setSlottableAssignedSlot(node: *anyopaque, slot: ?*anyopaque) void {
    if (asElement(node)) |element| {
        // Element has Slottable mixin fields flattened into Element struct
        // Call the generated setter method
        element.setAssignedSlot(slot);
    }
    // TODO: Handle Text nodes when they have Slottable mixin accessible
}

/// Get the name of a slot element
/// Returns empty string if not a slot or name not found
pub fn getSlotName(slot_element: *const anyopaque) []const u8 {
    if (asElementConst(slot_element)) |element| {
        // Slot name comes from the "name" attribute
        // Per DOM spec: If name attribute is absent, returns empty string (default slot)
        if (element.call_getAttribute("name")) |name| {
            return name;
        }
        return "";
    }
    return "";
}

/// Get the children of a node
pub fn getChildren(node: *const anyopaque) *const @import("infra").List(*Node) {
    const node_ptr: *const Node = @ptrCast(@alignCast(node));
    return node_ptr.get_childNodes();
}

// ============================================================================
// Tests
// ============================================================================
