//! Tests migrated from src/dom/shadow_dom_algorithms.zig
//! Per WHATWG specifications

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Element = dom.Element;

test "attachShadowRoot - invalid element name throws error" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "script");
    defer element.deinit();

    try std.testing.expectError(
        error.NotSupportedError,
        dom.attachShadowRoot(&element, .open, false, false, false, .named, null),
    );
}
test "attachShadowRoot - basic attachment" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    try dom.attachShadowRoot(&element, .open, false, false, false, .named, null);

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
    try dom.attachShadowRoot(&element, .open, false, false, false, .named, null);

    // Second attachment should fail (shadow root is not declarative)
    try std.testing.expectError(
        error.NotSupportedError,
        dom.attachShadowRoot(&element, .open, false, false, false, .named, null),
    );

    // Clean up
    if (element.shadow_root) |shadow| {
        allocator.destroy(shadow);
    }
}