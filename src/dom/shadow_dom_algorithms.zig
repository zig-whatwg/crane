//! Shadow DOM Algorithms (WHATWG DOM Standard §4.8.2)
//!
//! Spec: https://dom.spec.whatwg.org/#shadow-trees
//!
//! This module implements the shadow DOM algorithms:
//! - Attach a shadow root
//! - Valid shadow host name check
//!

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import DOM types
const Element = @import("element").Element;
const ShadowRoot = @import("shadow_root").ShadowRoot;
const ShadowRootMode = @import("shadow_root").ShadowRootMode;
const SlotAssignmentMode = @import("shadow_root").SlotAssignmentMode;

/// Valid shadow host names per DOM spec
const VALID_SHADOW_HOST_NAMES = [_][]const u8{
    "article", "aside",   "blockquote", "body", "div",
    "footer",  "h1",      "h2",         "h3",   "h4",
    "h5",      "h6",      "header",     "main", "nav",
    "p",       "section", "span",
};

/// Check if a local name is a valid shadow host name
///
/// DOM §4.10.2 - A valid shadow host name is:
/// - a valid custom element name (TODO)
/// - one of the standard HTML elements listed above
fn isValidShadowHostName(local_name: []const u8) bool {
    // TODO: Check if it's a valid custom element name

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
    _ = registry; // TODO: Implement CustomElementRegistry support

    // Step 1: If element's namespace is not the HTML namespace, then throw NotSupportedError
    // TODO: Check namespace when Element has namespace field accessible
    // For now, assume HTML namespace

    // Step 2: If element's local name is not a valid shadow host name, then throw NotSupportedError
    if (!isValidShadowHostName(element.tag_name)) {
        return error.NotSupportedError;
    }

    // Step 3: If element's local name is a valid custom element name, or element's "is" value is non-null:
    // TODO: Implement custom element checks

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
        // TODO: Implement when ShadowRoot extends DocumentFragment with child removal

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
    // TODO: Implement when Element has custom_element_state field

    // Step 8: Set shadow's slot assignment to slotAssignment
    // (Done in init above)

    // Step 9: Set shadow's declarative to false
    shadow.setDeclarative(false);

    // Step 10: Set shadow's clonable to clonable
    // (Done in init above)

    // Step 11: Set shadow's serializable to serializable
    // (Done in init above)

    // Step 12: Set shadow's custom element registry to registry
    // TODO: Implement when ShadowRoot has custom_element_registry setter

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
    // TODO: Implement when we have:
    // - Node.parent field accessible
    // - Element.shadow_root accessible as Node
    // - HTMLSlotElement implementation
    // - Tree traversal algorithms

    // Step 1: If slottable's parent is null, then return null
    // Step 2: Let shadow be slottable's parent's shadow root
    // Step 3: If shadow is null, then return null
    // Step 4: If open is true and shadow's mode is not "open", then return null
    // Step 5: If shadow's slot assignment is "manual", return slot with manually assigned nodes
    // Step 6: Return first slot in tree order whose name matches slottable's name

    _ = slottable;
    _ = open;
    return null;
}

/// DOM §4.8.2 - Find slottables for a slot
///
/// Find all slottables that should be assigned to a slot.
///
/// Spec: https://dom.spec.whatwg.org/#find-slottables
pub fn findSlottables(allocator: Allocator, slot: *anyopaque) !std.ArrayList(*anyopaque) {
    // TODO: Implement when we have:
    // - HTMLSlotElement implementation
    // - ShadowRoot as root check
    // - Host element access
    // - Tree order traversal

    // Step 1: Let result be « »
    const result = std.ArrayList(*anyopaque).init(allocator);

    // Step 2: Let root be slot's root
    // Step 3: If root is not a shadow root, return result
    // Step 4: Let host be root's host
    // Step 5: If root's slot assignment is "manual", check manually assigned nodes
    // Step 6: Otherwise, iterate host's children and find matching slots
    // Step 7: Return result

    _ = slot;
    return result;
}

/// DOM §4.8.2 - Find flattened slottables for a slot
///
/// Find all slottables including nested slot distribution.
///
/// Spec: https://dom.spec.whatwg.org/#find-flattened-slottables
pub fn findFlattenedSlottables(allocator: Allocator, slot: *anyopaque) !std.ArrayList(*anyopaque) {
    // TODO: Implement when we have HTMLSlotElement

    // Step 1: Let result be « »
    const result = std.ArrayList(*anyopaque).init(allocator);

    // Step 2: If slot's root is not a shadow root, return result
    // Step 3: Let slottables be the result of finding slottables given slot
    // Step 4: If slottables is empty, append slot's slottable children
    // Step 5: For each node in slottables:
    //   - If node is a slot in a shadow root, recursively find flattened slottables
    //   - Otherwise, append node to result
    // Step 6: Return result

    _ = slot;
    return result;
}

/// DOM §4.8.2 - Assign slottables for a slot
///
/// Assign slottables to a slot and update their assigned slot references.
///
/// Spec: https://dom.spec.whatwg.org/#assign-slottables
pub fn assignSlottables(allocator: Allocator, slot: *anyopaque) !void {
    // TODO: Implement when we have:
    // - HTMLSlotElement with assigned_nodes list
    // - Slottable.setAssignedSlot() method
    // - signalSlotChange() function

    // Step 1: Let slottables be the result of finding slottables for slot
    const slottables = try findSlottables(allocator, slot);
    defer slottables.deinit(allocator);

    // Step 2: If slottables and slot's assigned nodes are not identical,
    //         run signal a slot change for slot
    // Step 3: Set slot's assigned nodes to slottables
    // Step 4: For each slottable of slottables, set slottable's assigned slot to slot
}

/// DOM §4.8.2 - Assign slottables for a tree
///
/// Assign slottables for all slots in a tree.
///
/// Spec: https://dom.spec.whatwg.org/#assign-slottables-for-a-tree
pub fn assignSlottablesForTree(allocator: Allocator, root: *anyopaque) !void {
    // TODO: Implement when we have:
    // - Tree traversal for inclusive descendants
    // - HTMLSlotElement type checking

    // Run assign slottables for each slot of root's inclusive descendants, in tree order

    _ = allocator;
    _ = root;
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

/// DOM §4.8.2 - Signal a slot change
///
/// Signal that a slot's assigned nodes have changed.
///
/// Spec: https://dom.spec.whatwg.org/#signal-a-slot-change
pub fn signalSlotChange(slot: *anyopaque) !void {
    // TODO: Implement when we have:
    // - Agent's signal slots set
    // - mutation observer microtask queue

    // Step 1: Append slot to slot's relevant agent's signal slots
    // Step 2: Queue a mutation observer microtask

    _ = slot;
}

// ============================================================================
// Tests
// ============================================================================

test "isValidShadowHostName - valid names" {
    try std.testing.expect(isValidShadowHostName("div"));
    try std.testing.expect(isValidShadowHostName("span"));
    try std.testing.expect(isValidShadowHostName("article"));
    try std.testing.expect(isValidShadowHostName("section"));
    try std.testing.expect(isValidShadowHostName("h1"));
    try std.testing.expect(isValidShadowHostName("p"));
}

test "isValidShadowHostName - invalid names" {
    try std.testing.expect(!isValidShadowHostName("invalid"));
    try std.testing.expect(!isValidShadowHostName("script"));
    try std.testing.expect(!isValidShadowHostName("style"));
    try std.testing.expect(!isValidShadowHostName("img"));
}

test "attachShadowRoot - invalid element name throws error" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "script");
    defer element.deinit();

    try std.testing.expectError(
        error.NotSupportedError,
        attachShadowRoot(&element, .open, false, false, false, .named, null),
    );
}

test "attachShadowRoot - basic attachment" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    try attachShadowRoot(&element, .open, false, false, false, .named, null);

    try std.testing.expect(element.shadow_root != null);
    if (element.shadow_root) |shadow| {
        try std.testing.expectEqual(ShadowRootMode.open, shadow.getMode());
        try std.testing.expectEqual(false, shadow.get_delegatesFocus());
        try std.testing.expectEqual(SlotAssignmentMode.named, shadow.getSlotAssignmentMode());

        // Clean up
        allocator.destroy(shadow);
    }
}

test "attachShadowRoot - double attachment with non-declarative throws error" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // First attachment
    try attachShadowRoot(&element, .open, false, false, false, .named, null);

    // Second attachment should fail (shadow root is not declarative)
    try std.testing.expectError(
        error.NotSupportedError,
        attachShadowRoot(&element, .open, false, false, false, .named, null),
    );

    // Clean up
    if (element.shadow_root) |shadow| {
        allocator.destroy(shadow);
    }
}
