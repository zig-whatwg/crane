//! Tests migrated from webidl/src/dom/ShadowRoot.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");

const source = @import("../../webidl/src/dom/ShadowRoot.zig");

test "ShadowRoot - creation with basic properties" {
    const allocator = std.testing.allocator;

    // Create a mock Element to use as host
    var mock_element: Element = undefined;

    var shadow_root = try ShadowRoot.init(
        allocator,
        &mock_element,
        .open,
        false, // delegates_focus
        .named, // slot_assignment
        false, // clonable
        false, // serializable
    );
    defer shadow_root.deinit();

    try std.testing.expectEqual(ShadowRootMode.open, shadow_root.getMode());
    try std.testing.expectEqualStrings("open", shadow_root.get_mode());
    try std.testing.expectEqual(false, shadow_root.get_delegatesFocus());
    try std.testing.expectEqual(SlotAssignmentMode.named, shadow_root.getSlotAssignmentMode());
    try std.testing.expectEqualStrings("named", shadow_root.get_slotAssignment());
    try std.testing.expectEqual(false, shadow_root.get_clonable());
    try std.testing.expectEqual(false, shadow_root.get_serializable());
    try std.testing.expectEqual(&mock_element, shadow_root.get_host());
}
test "ShadowRoot - closed mode" {
    const allocator = std.testing.allocator;

    var mock_element: Element = undefined;

    var shadow_root = try ShadowRoot.init(
        allocator,
        &mock_element,
        .closed,
        true, // delegates_focus
        .manual, // slot_assignment
        true, // clonable
        true, // serializable
    );
    defer shadow_root.deinit();

    try std.testing.expectEqual(ShadowRootMode.closed, shadow_root.getMode());
    try std.testing.expectEqualStrings("closed", shadow_root.get_mode());
    try std.testing.expectEqual(true, shadow_root.get_delegatesFocus());
    try std.testing.expectEqual(SlotAssignmentMode.manual, shadow_root.getSlotAssignmentMode());
    try std.testing.expectEqualStrings("manual", shadow_root.get_slotAssignment());
    try std.testing.expectEqual(true, shadow_root.get_clonable());
    try std.testing.expectEqual(true, shadow_root.get_serializable());
}
test "ShadowRoot - internal flags" {
    const allocator = std.testing.allocator;

    var mock_element: Element = undefined;

    var shadow_root = try ShadowRoot.init(
        allocator,
        &mock_element,
        .open,
        false,
        .named,
        false,
        false,
    );
    defer shadow_root.deinit();

    // Test initial values
    try std.testing.expectEqual(false, shadow_root.isAvailableToElementInternals());
    try std.testing.expectEqual(false, shadow_root.isDeclarative());

    // Test setters
    shadow_root.setAvailableToElementInternals(true);
    try std.testing.expectEqual(true, shadow_root.isAvailableToElementInternals());

    shadow_root.setDeclarative(true);
    try std.testing.expectEqual(true, shadow_root.isDeclarative());
}
test "ShadowRootMode - toString" {
    try std.testing.expectEqualStrings("open", ShadowRootMode.open.toString());
    try std.testing.expectEqualStrings("closed", ShadowRootMode.closed.toString());
}
test "SlotAssignmentMode - toString" {
    try std.testing.expectEqualStrings("manual", SlotAssignmentMode.manual.toString());
    try std.testing.expectEqualStrings("named", SlotAssignmentMode.named.toString());
}