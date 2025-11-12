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

// Tests

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
