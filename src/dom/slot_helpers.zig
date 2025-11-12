//! Slot Algorithm Helper Utilities
//!
//! This module provides type-safe utilities for slot algorithms to work with
//! polymorphic node types.

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import DOM types
const Node = @import("node").Node;
const Element = @import("element").Element;
const ShadowRoot = @import("shadow_root").ShadowRoot;
const HTMLSlotElement = @import("html_slot_element").HTMLSlotElement;

/// Check if a Node pointer is an Element
pub fn isElement(node: *const anyopaque) bool {
    const node_ptr: *const Node = @ptrCast(@alignCast(node));
    return node_ptr.node_type == Node.ELEMENT_NODE;
}

/// Check if a Node pointer is a ShadowRoot (DocumentFragment subtype)
pub fn isShadowRoot(node: *const anyopaque) bool {
    const node_ptr: *const Node = @ptrCast(@alignCast(node));
    // ShadowRoot is a DocumentFragment (node type 11)
    return node_ptr.node_type == Node.DOCUMENT_FRAGMENT_NODE;
}

/// Try to cast a Node to an Element
/// Returns null if the node is not an Element
pub fn asElement(node: *anyopaque) ?*Element {
    const node_ptr: *Node = @ptrCast(@alignCast(node));
    if (node_ptr.node_type == Node.ELEMENT_NODE) {
        return @ptrCast(@alignCast(node));
    }
    return null;
}

/// Try to cast a Node to a const Element
/// Returns null if the node is not an Element
pub fn asElementConst(node: *const anyopaque) ?*const Element {
    const node_ptr: *const Node = @ptrCast(@alignCast(node));
    if (node_ptr.node_type == Node.ELEMENT_NODE) {
        return @ptrCast(@alignCast(node));
    }
    return null;
}

/// Try to cast a Node to a ShadowRoot
/// Returns null if the node is not a ShadowRoot
pub fn asShadowRoot(node: *anyopaque) ?*ShadowRoot {
    const node_ptr: *Node = @ptrCast(@alignCast(node));
    if (node_ptr.node_type == Node.DOCUMENT_FRAGMENT_NODE) {
        // TODO: Additional check to distinguish ShadowRoot from plain DocumentFragment
        // For now, assume all DocumentFragments with this type are ShadowRoots
        return @ptrCast(@alignCast(node));
    }
    return null;
}

/// Try to cast a Node to a const ShadowRoot
/// Returns null if the node is not a ShadowRoot
pub fn asShadowRootConst(node: *const anyopaque) ?*const ShadowRoot {
    const node_ptr: *const Node = @ptrCast(@alignCast(node));
    if (node_ptr.node_type == Node.DOCUMENT_FRAGMENT_NODE) {
        return @ptrCast(@alignCast(node));
    }
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
        // Element has Slottable mixin with slottable_name field
        // Access through the generated interface
        return element.Slottable.getSlottableName();
    }
    // TODO: Handle Text nodes when they have Slottable mixin accessible
    return "";
}

/// Set the assigned slot for a slottable
pub fn setSlottableAssignedSlot(node: *anyopaque, slot: ?*anyopaque) void {
    if (asElement(node)) |element| {
        // Element has Slottable mixin with setAssignedSlot method
        element.Slottable.setAssignedSlot(slot);
    }
    // TODO: Handle Text nodes when they have Slottable mixin accessible
}

/// Get the name of a slot element
/// Returns empty string if not a slot or name not found
pub fn getSlotName(slot_element: *const anyopaque) []const u8 {
    if (asElementConst(slot_element)) |element| {
        // Slot name comes from the "name" attribute
        // For now, since HTMLSlotElement isn't integrated with Element,
        // we would need to access the "name" attribute
        // TODO: Access element's "name" attribute when attribute system is available
        // For now, return empty string (default slot)
        _ = element;
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

test "slot_helpers - isElement" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Element should be recognized
    try std.testing.expect(isElement(@ptrCast(&element)));
}

test "slot_helpers - asElement" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Should successfully cast to Element
    const maybe_elem = asElement(@ptrCast(&element));
    try std.testing.expect(maybe_elem != null);

    if (maybe_elem) |elem| {
        try std.testing.expectEqualStrings("div", elem.tag_name);
    }
}

test "slot_helpers - isSlottable" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Elements are slottables
    try std.testing.expect(isSlottable(@ptrCast(&element)));
}

test "slot_helpers - isSlot detects slot elements" {
    const allocator = std.testing.allocator;

    var slot_elem = try Element.init(allocator, "slot");
    defer slot_elem.deinit();

    var div_elem = try Element.init(allocator, "div");
    defer div_elem.deinit();

    // Slot element should be detected
    try std.testing.expect(isSlot(@ptrCast(&slot_elem)));

    // Non-slot element should not be detected
    try std.testing.expect(!isSlot(@ptrCast(&div_elem)));
}

test "slot_helpers - getSlottableName" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Default slottable name is empty
    const name = getSlottableName(@ptrCast(&element));
    try std.testing.expectEqualStrings("", name);

    // Set a name
    element.Slottable.setSlottableName("header");
    const name2 = getSlottableName(@ptrCast(&element));
    try std.testing.expectEqualStrings("header", name2);
}

test "slot_helpers - setSlottableAssignedSlot" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Initially no assigned slot
    try std.testing.expect(!element.Slottable.isAssigned());

    // Create a mock slot
    var mock_slot: u32 = 42;

    // Assign the slot
    setSlottableAssignedSlot(@ptrCast(&element), @ptrCast(&mock_slot));

    // Check it was assigned
    try std.testing.expect(element.Slottable.isAssigned());
}
