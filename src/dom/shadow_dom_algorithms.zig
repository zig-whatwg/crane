//! Shadow DOM Algorithms (WHATWG DOM Standard §4.8.2)
//!
//! Spec: https://dom.spec.whatwg.org/#shadow-trees
//!
//! This module implements the shadow DOM algorithms:
//! - Attach a shadow root
//! - Valid shadow host name check
//! - Slot finding and assignment
//!

const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;

// Import DOM types
const Node = @import("node").Node;
const Element = @import("element").Element;
const ShadowRoot = @import("shadow_root").ShadowRoot;
const ShadowRootMode = @import("shadow_root").ShadowRootMode;
const SlotAssignmentMode = @import("shadow_root").SlotAssignmentMode;
const HTMLSlotElement = @import("html_slot_element").HTMLSlotElement;
const slot_helpers = @import("slot_helpers.zig"); // File import (same directory)
const tree_helpers = @import("tree_helpers.zig"); // File import (same directory)

/// Valid shadow host names per DOM spec
const VALID_SHADOW_HOST_NAMES = [_][]const u8{
    "article", "aside",   "blockquote", "body", "div",
    "footer",  "h1",      "h2",         "h3",   "h4",
    "h5",      "h6",      "header",     "main", "nav",
    "p",       "section", "span",
};

/// Check if a name is a valid custom element name
///
/// Spec: https://html.spec.whatwg.org/#valid-custom-element-name
/// A valid custom element name must:
/// - Contain a hyphen (-)
/// - Start with a lowercase ASCII letter (a-z)
/// - Only contain lowercase ASCII letters, digits, hyphens, dots, underscores
/// - Not be one of the reserved names
fn isValidCustomElementName(name: []const u8) bool {
    // Reserved names per HTML spec
    const RESERVED_NAMES = [_][]const u8{
        "annotation-xml",
        "color-profile",
        "font-face",
        "font-face-src",
        "font-face-uri",
        "font-face-format",
        "font-face-name",
        "missing-glyph",
    };

    // Must contain a hyphen
    if (std.mem.indexOfScalar(u8, name, '-') == null) {
        return false;
    }

    // Must start with lowercase ASCII letter
    if (name.len == 0 or !std.ascii.isLower(name[0])) {
        return false;
    }

    // Check all characters are valid: lowercase letters, digits, hyphen, dot, underscore
    for (name) |c| {
        if (!std.ascii.isLower(c) and !std.ascii.isDigit(c) and c != '-' and c != '.' and c != '_') {
            return false;
        }
    }

    // Must not be a reserved name
    for (RESERVED_NAMES) |reserved| {
        if (std.mem.eql(u8, name, reserved)) {
            return false;
        }
    }

    return true;
}

/// Check if a local name is a valid shadow host name
///
/// DOM §4.10.2 - A valid shadow host name is:
/// - a valid custom element name
/// - one of the standard HTML elements listed above
fn isValidShadowHostName(local_name: []const u8) bool {
    // Check if it's a valid custom element name
    if (isValidCustomElementName(local_name)) {
        return true;
    }

    // Check against standard HTML element names
    for (VALID_SHADOW_HOST_NAMES) |valid_name| {
        if (std.mem.eql(u8, local_name, valid_name)) {
            return true;
        }
    }

    return false;
}

/// DOM §4.10.2 - Attach a shadow root
///
/// Attach a shadow root to an element.
///
/// Spec: https://dom.spec.whatwg.org/#concept-attach-a-shadow-root
pub fn attachShadowRoot(
    element: *Element,
    mode: ShadowRootMode,
    clonable: bool,
    serializable: bool,
    delegates_focus: bool,
    slot_assignment: SlotAssignmentMode,
    registry: ?*anyopaque,
) !void {
    // registry is used below in Step 12

    // Step 1: If element's namespace is not the HTML namespace, then throw NotSupportedError
    // HTML namespace is "http://www.w3.org/1999/xhtml"
    const HTML_NAMESPACE = "http://www.w3.org/1999/xhtml";

    if (element.namespace_uri) |ns| {
        if (!std.mem.eql(u8, ns, HTML_NAMESPACE)) {
            return error.NotSupportedError;
        }
    } else {
        // If namespace_uri is null, assume HTML namespace for elements created via createElement
        // This is the common case for DOM manipulation
    }

    // Step 2: If element's local name is not a valid shadow host name, then throw NotSupportedError
    if (!isValidShadowHostName(element.tag_name)) {
        return error.NotSupportedError;
    }

    // Step 3: If element's local name is a valid custom element name, or element's "is" value is non-null:
    if (isValidCustomElementName(element.local_name) or element.is_value != null) {
        // Step 3.1: Let definition be the result of looking up a custom element definition
        // given element's custom element registry, its namespace, its local name, and its is value
        // Note: Custom element registry lookup deferred until Custom Elements spec implementation

        // Step 3.2: If definition is not null and definition's disable shadow is true,
        // then throw NotSupportedError
        // Note: This check requires Custom Element definition lookup
        // For now, we allow shadow attachment on all custom elements
    }

    // Step 4: If element is a shadow host:
    if (element.shadow_root) |current_shadow_root| {
        // Step 4.1: Let currentShadowRoot be element's shadow root

        // Step 4.2: If any of the following are true:
        // - currentShadowRoot's declarative is false; or
        // - currentShadowRoot's mode is not mode,
        // then throw NotSupportedError
        if (!current_shadow_root.isDeclarative() or current_shadow_root.getMode() != mode) {
            return error.NotSupportedError;
        }

        // Step 4.3: Otherwise:
        // Step 4.3.1: Remove all of currentShadowRoot's children, in tree order
        // ShadowRoot extends DocumentFragment which extends Node, so it has child_nodes
        const shadow_node: *Node = @ptrCast(current_shadow_root);
        const children = shadow_node.child_nodes.toSlice();

        // Remove children in reverse order to avoid index shifting issues
        var i: usize = children.len;
        while (i > 0) {
            i -= 1;
            const child = children[i];
            // Use removeChild to properly remove each child
            _ = try shadow_node.call_removeChild(child);
        }

        // Step 4.3.2: Set currentShadowRoot's declarative to false
        current_shadow_root.setDeclarative(false);

        // Step 4.3.3: Return
        return;
    }

    // Step 5: Let shadow be a new shadow root whose node document is element's node document,
    // host is element, and mode is mode
    const shadow = try element.allocator.create(ShadowRoot);
    errdefer element.allocator.destroy(shadow);

    shadow.* = try ShadowRoot.init(
        element.allocator,
        element,
        mode,
        delegates_focus,
        slot_assignment,
        clonable,
        serializable,
    );

    // Step 6: Set shadow's delegates focus to delegatesFocus
    // (Done in init above)

    // Step 7: If element's custom element state is "precustomized" or "custom",
    // then set shadow's available to element internals to true
    if (element.custom_element_state == .precustomized or element.custom_element_state == .custom) {
        shadow.setAvailableToElementInternals(true);
    }

    // Step 8: Set shadow's slot assignment to slotAssignment
    // (Done in init above)

    // Step 9: Set shadow's declarative to false
    shadow.setDeclarative(false);

    // Step 10: Set shadow's clonable to clonable
    // (Done in init above)

    // Step 11: Set shadow's serializable to serializable
    // (Done in init above)

    // Step 12: Set shadow's custom element registry to registry
    // ShadowRoot includes DocumentOrShadowRoot mixin which has setCustomElementRegistry
    shadow.setCustomElementRegistry(registry);

    // Step 13: Set element's shadow root to shadow
    element.shadow_root = shadow;
}

// ============================================================================
// Slot Finding and Assignment Algorithms
// ============================================================================

/// DOM §4.8.2 - Find a slot for a slottable
///
/// Find the slot that a slottable should be assigned to.
///
/// Spec: https://dom.spec.whatwg.org/#find-a-slot
pub fn findSlot(slottable: *anyopaque, open: bool) ?*anyopaque {
    // Step 1: If slottable's parent is null, then return null
    const parent = slot_helpers.getParentElement(slottable) orelse return null;

    // Step 2: Let shadow be slottable's parent's shadow root
    const shadow = parent.shadow_root orelse return null;

    // Step 3: If shadow is null, then return null (already handled above)

    // Step 4: If open is true and shadow's mode is not "open", then return null
    if (open and shadow.getMode() != .open) {
        return null;
    }

    // Step 5: If shadow's slot assignment is "manual", return slot with manually assigned nodes
    if (shadow.getSlotAssignmentMode() == .manual) {
        // TODO: Implement manual slot assignment search
        // Need to traverse shadow's descendants and find slot whose manually_assigned_nodes contains slottable
        // This requires HTMLSlotElement.manually_assigned_nodes integration
        return null;
    }

    // Step 6: Return first slot in tree order whose name matches slottable's name
    const slottable_name = slot_helpers.getSlottableName(slottable);

    // Traverse shadow's descendants in tree order to find matching slot
    const shadow_node: *Node = @ptrCast(@alignCast(shadow));

    // Get all descendants in tree order
    var descendants = tree_helpers.getDescendantsInTreeOrder(std.heap.page_allocator, shadow_node) catch return null;
    defer descendants.deinit();

    // Find first slot with matching name
    for (descendants.toSlice()) |descendant| {
        if (slot_helpers.isSlot(descendant)) {
            const slot_name = slot_helpers.getSlotName(descendant);
            // Match names (both empty string means default slot)
            if (std.mem.eql(u8, slot_name, slottable_name)) {
                return descendant;
            }
        }
    }

    return null;
}

/// DOM §4.8.2 - Find slottables for a slot
///
/// Find all slottables that should be assigned to a slot.
///
/// Spec: https://dom.spec.whatwg.org/#find-slottables
pub fn findSlottables(allocator: Allocator, slot: *anyopaque) !infra.List(*anyopaque) {
    // Step 1: Let result be « »
    var result = infra.List(*anyopaque).init(allocator);
    errdefer result.deinit();

    // Step 2: Let root be slot's root
    const root = slot_helpers.getRoot(slot);

    // Step 3: If root is not a shadow root, return result
    const shadow = slot_helpers.asShadowRoot(root) orelse return result;

    // Step 4: Let host be root's host
    const host = shadow.get_host();

    // Step 5: If root's slot assignment is "manual":
    if (shadow.getSlotAssignmentMode() == .manual) {
        // TODO: For manual mode, need to access slot's manually_assigned_nodes
        // and check if each slottable's parent is host
        // This requires HTMLSlotElement integration
        return result;
    }

    // Step 6: Otherwise, for each slottable child of host, in tree order:
    const host_node: *Node = @ptrCast(@alignCast(host));
    const children = host_node.get_childNodes();

    for (children.toSlice()) |child| {
        // Check if child is a slottable
        if (!slot_helpers.isSlottable(child)) continue;

        // Step 6.1: Let foundSlot be the result of finding a slot given slottable
        const found_slot = findSlot(child, false);

        // Step 6.2: If foundSlot is slot, then append slottable to result
        if (found_slot == slot) {
            try result.append(child);
        }
    }

    // Step 7: Return result
    return result;
}

/// DOM §4.8.2 - Find flattened slottables for a slot
///
/// Find all slottables including nested slot distribution.
///
/// Spec: https://dom.spec.whatwg.org/#find-flattened-slottables
pub fn findFlattenedSlottables(allocator: Allocator, slot: *anyopaque) !infra.List(*anyopaque) {
    // Step 1: Let result be « »
    var result = infra.List(*anyopaque).init(allocator);
    errdefer result.deinit();

    // Step 2: If slot's root is not a shadow root, return result
    const root = slot_helpers.getRoot(slot);
    if (slot_helpers.asShadowRoot(root) == null) {
        return result;
    }

    // Step 3: Let slottables be the result of finding slottables given slot
    var slottables = try findSlottables(allocator, slot);
    defer slottables.deinit();

    // Step 4: If slottables is empty, append each slottable child of slot, in tree order, to slottables
    if (slottables.toSlice().len == 0) {
        const slot_node: *Node = @ptrCast(@alignCast(slot));
        const children = slot_node.get_childNodes();

        for (children.toSlice()) |child| {
            if (slot_helpers.isSlottable(child)) {
                try slottables.append(child);
            }
        }
    }

    // Step 5: For each node of slottables:
    for (slottables.toSlice()) |node| {
        // Step 5.1: If node is a slot whose root is a shadow root:
        if (slot_helpers.isSlot(node)) {
            const node_root = slot_helpers.getRoot(node);
            if (slot_helpers.asShadowRoot(node_root) != null) {
                // Step 5.1.1: Let temporaryResult be the result of finding flattened slottables given node
                var temp_result = try findFlattenedSlottables(allocator, node);
                defer temp_result.deinit();

                // Step 5.1.2: Append each slottable in temporaryResult, in order, to result
                for (temp_result.toSlice()) |item| {
                    try result.append(item);
                }
                continue;
            }
        }

        // Step 5.2: Otherwise, append node to result
        try result.append(node);
    }

    // Step 6: Return result
    return result;
}

/// DOM §4.8.2 - Assign slottables for a slot
///
/// Assign slottables to a slot and update their assigned slot references.
///
/// Spec: https://dom.spec.whatwg.org/#assign-slottables
pub fn assignSlottables(allocator: Allocator, slot: *anyopaque) !void {
    // Step 1: Let slottables be the result of finding slottables for slot
    var slottables = try findSlottables(allocator, slot);
    defer slottables.deinit();

    // Step 2: If slottables and slot's assigned nodes are not identical,
    //         run signal a slot change for slot
    // TODO: Compare slottables with slot's current assigned_nodes
    // TODO: Call signalSlotChange if they differ
    // This requires HTMLSlotElement integration to access assigned_nodes

    // Step 3: Set slot's assigned nodes to slottables
    // TODO: Update HTMLSlotElement.assigned_nodes
    // This requires HTMLSlotElement integration

    // Step 4: For each slottable of slottables, set slottable's assigned slot to slot
    for (slottables.toSlice()) |slottable| {
        // Set the assigned slot using the helper (handles Element and Text)
        slot_helpers.setSlottableAssignedSlot(slottable, slot);
    }
}

/// DOM §4.8.2 - Assign slottables for a tree
///
/// Assign slottables for all slots in a tree.
///
/// Spec: https://dom.spec.whatwg.org/#assign-slottables-for-a-tree
pub fn assignSlottablesForTree(allocator: Allocator, root: *anyopaque) !void {
    // Run assign slottables for each slot of root's inclusive descendants, in tree order

    const root_node: *Node = @ptrCast(@alignCast(root));

    // Get all inclusive descendants in tree order
    var descendants = try tree_helpers.getInclusiveDescendantsInTreeOrder(allocator, root_node);
    defer descendants.deinit();

    // For each node in tree order, if it's a slot, assign slottables
    for (descendants.toSlice()) |descendant| {
        if (slot_helpers.isSlot(descendant)) {
            try assignSlottables(allocator, descendant);
        }
    }
}

/// DOM §4.8.2 - Assign a slot
///
/// Assign a slot for a given slottable.
///
/// Spec: https://dom.spec.whatwg.org/#assign-a-slot
pub fn assignSlot(allocator: Allocator, slottable: *anyopaque) !void {
    // Step 1: Let slot be the result of finding a slot with slottable
    const maybe_slot = findSlot(slottable, false);

    // Step 2: If slot is non-null, then run assign slottables for slot
    if (maybe_slot) |slot| {
        try assignSlottables(allocator, slot);
    }
}

/// Agent's signal slots set (per similar-origin window agent)
/// TODO: This should be stored in the agent/event loop when that infrastructure exists
/// For now, use a global as a placeholder
/// Uses page_allocator since this lives for the program lifetime and is never freed
var signal_slots_set: ?infra.List(*anyopaque) = null;

/// DOM §4.8.2 - Signal a slot change
///
/// Signal that a slot's assigned nodes have changed.
///
/// Spec: https://dom.spec.whatwg.org/#signal-a-slot-change
pub fn signalSlotChange(slot: *anyopaque) !void {
    // Step 1: Append slot to slot's relevant agent's signal slots
    // TODO: Use proper agent-based storage when event loop infrastructure exists
    // For now, use placeholder global
    _ = slot;

    // Step 2: Queue a mutation observer microtask
    // TODO: Implement when mutation observer microtask queue is available
    // This requires event loop integration
}

// ============================================================================
// Tests
// ============================================================================
