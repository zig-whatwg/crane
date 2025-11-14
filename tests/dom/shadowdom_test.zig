//! Comprehensive Shadow DOM Tests (WHATWG DOM Standard §4.8-4.10)
//!
//! Spec: https://dom.spec.whatwg.org/#shadow-trees
//!
//! Tests cover:
//! - ShadowRoot creation and configuration
//! - attachShadow() algorithm with various options
//! - Shadow root modes (open/closed)
//! - Slot assignment modes (named/manual)
//! - delegates focus, clonable, and serializable flags
//! - HTMLSlotElement basic functionality
//! - Error conditions and edge cases

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const Element = dom.Element;
const ShadowRoot = dom.ShadowRoot;
const ShadowRootMode = dom.ShadowRootMode;
const SlotAssignmentMode = dom.SlotAssignmentMode;
const HTMLSlotElement = dom.HTMLSlotElement;
const shadow_dom_algorithms = dom.shadow_dom_algorithms;

// ============================================================================
// ShadowRoot Interface Tests (DOM §4.8.1)
// ============================================================================

test "ShadowRoot - basic initialization with open mode" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        .open,
        false, // delegates_focus
        .named, // slot_assignment
        false, // clonable
        false, // serializable
    );
    defer shadow.deinit();

    // Verify mode
    try std.testing.expectEqual(ShadowRootMode.open, shadow.getMode());

    // Verify host
    try std.testing.expectEqual(&host, shadow.getHost());

    // Verify delegates focus (default false)
    try std.testing.expectEqual(false, shadow.get_delegatesFocus());

    // Verify slot assignment mode
    try std.testing.expectEqual(SlotAssignmentMode.named, shadow.getSlotAssignmentMode());

    // Verify clonable
    try std.testing.expectEqual(false, shadow.getClonable());

    // Verify serializable
    try std.testing.expectEqual(false, shadow.getSerializable());

    // Verify declarative (default false)
    try std.testing.expectEqual(false, shadow.isDeclarative());
}

test "ShadowRoot - closed mode" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        .closed,
        false,
        .named,
        false,
        false,
    );
    defer shadow.deinit();

    try std.testing.expectEqual(ShadowRootMode.closed, shadow.getMode());
}

test "ShadowRoot - delegates focus enabled" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        .open,
        true, // delegates_focus = true
        .named,
        false,
        false,
    );
    defer shadow.deinit();

    try std.testing.expectEqual(true, shadow.get_delegatesFocus());
}

test "ShadowRoot - manual slot assignment mode" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        .open,
        false,
        .manual, // manual slot assignment
        false,
        false,
    );
    defer shadow.deinit();

    try std.testing.expectEqual(SlotAssignmentMode.manual, shadow.getSlotAssignmentMode());
}

test "ShadowRoot - clonable and serializable flags" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        .open,
        false,
        .named,
        true, // clonable = true
        true, // serializable = true
    );
    defer shadow.deinit();

    try std.testing.expectEqual(true, shadow.getClonable());
    try std.testing.expectEqual(true, shadow.getSerializable());
}

test "ShadowRoot - declarative flag mutation" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        .open,
        false,
        .named,
        false,
        false,
    );
    defer shadow.deinit();

    // Default is false
    try std.testing.expectEqual(false, shadow.isDeclarative());

    // Set to true
    shadow.setDeclarative(true);
    try std.testing.expectEqual(true, shadow.isDeclarative());

    // Set back to false
    shadow.setDeclarative(false);
    try std.testing.expectEqual(false, shadow.isDeclarative());
}

// ============================================================================
// attachShadow() Algorithm Tests (DOM §4.10.2)
// ============================================================================

test "attachShadow - valid shadow host names" {
    const allocator = std.testing.allocator;

    // Test all valid HTML element names
    const valid_names = [_][]const u8{
        "article", "aside",   "blockquote", "body", "div",
        "footer",  "h1",      "h2",         "h3",   "h4",
        "h5",      "h6",      "header",     "main", "nav",
        "p",       "section", "span",
    };

    for (valid_names) |name| {
        var element = try Element.init(allocator, name);
        defer element.deinit();

        // Should succeed
        try shadow_dom_algorithms.attachShadowRoot(
            &element,
            .open,
            false,
            false,
            false,
            .named,
            null,
        );

        // Verify shadow root was attached
        try std.testing.expect(element.shadow_root != null);

        // Clean up
        if (element.shadow_root) |shadow| {
            allocator.destroy(shadow);
        }
    }
}

test "attachShadow - invalid shadow host names throw error" {
    const allocator = std.testing.allocator;

    const invalid_names = [_][]const u8{
        "script", "style",  "img", "input",   "textarea",
        "select", "button", "a",   "invalid",
    };

    for (invalid_names) |name| {
        var element = try Element.init(allocator, name);
        defer element.deinit();

        // Should throw NotSupportedError
        try std.testing.expectError(
            error.NotSupportedError,
            shadow_dom_algorithms.attachShadowRoot(
                &element,
                .open,
                false,
                false,
                false,
                .named,
                null,
            ),
        );

        // Verify no shadow root was attached
        try std.testing.expect(element.shadow_root == null);
    }
}

test "attachShadow - double attachment with non-declarative shadow throws error" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // First attachment
    try shadow_dom_algorithms.attachShadowRoot(
        &element,
        .open,
        false,
        false,
        false,
        .named,
        null,
    );

    // Verify first shadow root is attached and not declarative
    try std.testing.expect(element.shadow_root != null);
    if (element.shadow_root) |shadow| {
        try std.testing.expectEqual(false, shadow.isDeclarative());
    }

    // Second attachment should fail
    try std.testing.expectError(
        error.NotSupportedError,
        shadow_dom_algorithms.attachShadowRoot(
            &element,
            .open,
            false,
            false,
            false,
            .named,
            null,
        ),
    );

    // Clean up
    if (element.shadow_root) |shadow| {
        allocator.destroy(shadow);
    }
}

test "attachShadow - double attachment with different modes throws error" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // First attachment with open mode
    try shadow_dom_algorithms.attachShadowRoot(
        &element,
        .open,
        false,
        false,
        false,
        .named,
        null,
    );

    // Mark as declarative to allow potential reattachment
    if (element.shadow_root) |shadow| {
        shadow.setDeclarative(true);
    }

    // Try to attach with closed mode - should fail due to mode mismatch
    try std.testing.expectError(
        error.NotSupportedError,
        shadow_dom_algorithms.attachShadowRoot(
            &element,
            .closed, // Different mode
            false,
            false,
            false,
            .named,
            null,
        ),
    );

    // Clean up
    if (element.shadow_root) |shadow| {
        allocator.destroy(shadow);
    }
}

test "attachShadow - configuration options propagate correctly" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Attach with all options enabled
    try shadow_dom_algorithms.attachShadowRoot(
        &element,
        .closed,
        true, // clonable
        true, // serializable
        true, // delegates_focus
        .manual, // slot_assignment
        null,
    );

    // Verify all options were set correctly
    try std.testing.expect(element.shadow_root != null);
    if (element.shadow_root) |shadow| {
        try std.testing.expectEqual(ShadowRootMode.closed, shadow.getMode());
        try std.testing.expectEqual(true, shadow.getClonable());
        try std.testing.expectEqual(true, shadow.getSerializable());
        try std.testing.expectEqual(true, shadow.get_delegatesFocus());
        try std.testing.expectEqual(SlotAssignmentMode.manual, shadow.getSlotAssignmentMode());
        try std.testing.expectEqual(false, shadow.isDeclarative()); // Always false for new attachments

        // Clean up
        allocator.destroy(shadow);
    }
}

test "attachShadow - host element maintains reference to shadow root" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Initially no shadow root
    try std.testing.expect(element.shadow_root == null);

    // Attach shadow root
    try shadow_dom_algorithms.attachShadowRoot(
        &element,
        .open,
        false,
        false,
        false,
        .named,
        null,
    );

    // Now has shadow root
    try std.testing.expect(element.shadow_root != null);

    // Shadow root knows its host
    if (element.shadow_root) |shadow| {
        try std.testing.expectEqual(&element, shadow.getHost());

        // Clean up
        allocator.destroy(shadow);
    }
}

// ============================================================================
// HTMLSlotElement Tests
// ============================================================================

test "HTMLSlotElement - initialization with default values" {
    const allocator = std.testing.allocator;

    var slot = try HTMLSlotElement.init(allocator);
    defer slot.deinit();

    // Default name is empty string
    try std.testing.expectEqualStrings("", slot.getName());

    // Assigned nodes list is initially empty
    try std.testing.expectEqual(@as(usize, 0), slot.assigned_nodes.size());
    try std.testing.expect(!slot.hasAssignedNodes());

    // Manually assigned nodes list is initially empty
    try std.testing.expectEqual(@as(usize, 0), slot.manually_assigned_nodes.items.len);
}

test "HTMLSlotElement - set and get slot name" {
    const allocator = std.testing.allocator;

    var slot = try HTMLSlotElement.init(allocator);
    defer slot.deinit();

    // Set name
    try slot.setName("header");
    try std.testing.expectEqualStrings("header", slot.getName());

    // Change name
    try slot.setName("footer");
    try std.testing.expectEqualStrings("footer", slot.getName());

    // Set to empty string
    try slot.setName("");
    try std.testing.expectEqualStrings("", slot.getName());
}

test "HTMLSlotElement - assigned nodes tracking" {
    const allocator = std.testing.allocator;

    var slot = try HTMLSlotElement.init(allocator);
    defer slot.deinit();

    // Initially empty
    try std.testing.expect(!slot.hasAssignedNodes());

    // Add mock nodes (using dummy pointers for testing)
    var dummy1: u32 = 1;
    var dummy2: u32 = 2;
    var dummy3: u32 = 3;

    try slot.assigned_nodes.append(@ptrCast(&dummy1));
    try std.testing.expectEqual(@as(usize, 1), slot.assigned_nodes.size());
    try std.testing.expect(slot.hasAssignedNodes());

    try slot.assigned_nodes.append(@ptrCast(&dummy2));
    try slot.assigned_nodes.append(@ptrCast(&dummy3));
    try std.testing.expectEqual(@as(usize, 3), slot.assigned_nodes.size());

    // Clear assigned nodes
    slot.assigned_nodes.clearRetainingCapacity();
    try std.testing.expectEqual(@as(usize, 0), slot.assigned_nodes.size());
    try std.testing.expect(!slot.hasAssignedNodes());
}

test "HTMLSlotElement - manually assigned nodes tracking" {
    const allocator = std.testing.allocator;

    var slot = try HTMLSlotElement.init(allocator);
    defer slot.deinit();

    // Add manually assigned nodes
    var dummy1: u32 = 1;
    var dummy2: u32 = 2;

    try slot.manually_assigned_nodes.append(@ptrCast(&dummy1));
    try slot.manually_assigned_nodes.append(@ptrCast(&dummy2));

    try std.testing.expectEqual(@as(usize, 2), slot.manually_assigned_nodes.items.len);
}

test "HTMLSlotElement - multiple slots with different names" {
    const allocator = std.testing.allocator;

    var header_slot = try HTMLSlotElement.init(allocator);
    defer header_slot.deinit();
    try header_slot.setName("header");

    var footer_slot = try HTMLSlotElement.init(allocator);
    defer footer_slot.deinit();
    try footer_slot.setName("footer");

    var default_slot = try HTMLSlotElement.init(allocator);
    defer default_slot.deinit();
    // Leave default_slot with empty name

    // Verify each has correct name
    try std.testing.expectEqualStrings("header", header_slot.getName());
    try std.testing.expectEqualStrings("footer", footer_slot.getName());
    try std.testing.expectEqualStrings("", default_slot.getName());

    // Each should have independent assigned nodes
    var dummy1: u32 = 1;
    var dummy2: u32 = 2;
    var dummy3: u32 = 3;

    try header_slot.assigned_nodes.append(@ptrCast(&dummy1));
    try footer_slot.assigned_nodes.append(@ptrCast(&dummy2));
    try default_slot.assigned_nodes.append(@ptrCast(&dummy3));

    try std.testing.expectEqual(@as(usize, 1), header_slot.assigned_nodes.size());
    try std.testing.expectEqual(@as(usize, 1), footer_slot.assigned_nodes.size());
    try std.testing.expectEqual(@as(usize, 1), default_slot.assigned_nodes.size());
}

// ============================================================================
// Shadow DOM Edge Cases and Error Handling
// ============================================================================

test "ShadowRoot - multiple configurations on same allocator" {
    const allocator = std.testing.allocator;

    var host1 = try Element.init(allocator, "div");
    defer host1.deinit();

    var host2 = try Element.init(allocator, "span");
    defer host2.deinit();

    // Create shadow roots with different configurations
    var shadow1 = try ShadowRoot.init(allocator, &host1, .open, true, .named, true, true);
    defer shadow1.deinit();

    var shadow2 = try ShadowRoot.init(allocator, &host2, .closed, false, .manual, false, false);
    defer shadow2.deinit();

    // Verify they're independent
    try std.testing.expectEqual(ShadowRootMode.open, shadow1.getMode());
    try std.testing.expectEqual(ShadowRootMode.closed, shadow2.getMode());

    try std.testing.expectEqual(true, shadow1.get_delegatesFocus());
    try std.testing.expectEqual(false, shadow2.get_delegatesFocus());

    try std.testing.expectEqual(SlotAssignmentMode.named, shadow1.getSlotAssignmentMode());
    try std.testing.expectEqual(SlotAssignmentMode.manual, shadow2.getSlotAssignmentMode());
}

test "attachShadow - element lifecycle with shadow root" {
    const allocator = std.testing.allocator;

    var element = try Element.init(allocator, "div");
    defer element.deinit();

    // Attach shadow root
    try shadow_dom_algorithms.attachShadowRoot(
        &element,
        .open,
        false,
        false,
        false,
        .named,
        null,
    );

    // Element should have shadow root
    try std.testing.expect(element.shadow_root != null);

    // Store pointer before cleanup
    const shadow_ptr = element.shadow_root;

    // Clean up shadow root
    if (shadow_ptr) |shadow| {
        allocator.destroy(shadow);
    }

    // Note: In real usage, element.deinit() would handle cleanup
    // but here we're manually managing to test the relationship
}
