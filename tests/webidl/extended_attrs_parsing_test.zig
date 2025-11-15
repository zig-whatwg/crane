//! Tests for WebIDL extended attribute parsing
//!
//! Verifies that the parser correctly extracts extended attributes from source files.

const std = @import("std");
const testing = std.testing;

// Import codegen types
const codegen = @import("webidl").codegen;
const ExtendedAttributeValue = codegen.ExtendedAttributeValue;

// ============================================================================
// Integration Tests with Generated Code
// ============================================================================

// Import actual generated classes to verify parser worked correctly
const EventTarget = @import("dom").EventTarget;
const Event = @import("dom").Event;
const Node = @import("dom").Node;
const ReadableStream = @import("streams").ReadableStream;

test "generated EventTarget has [Exposed=*]" {
    const metadata = EventTarget.__webidl__;

    // Should have Exposed attribute
    var found_exposed = false;
    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            found_exposed = true;
            try testing.expectEqual(ExtendedAttributeValue.wildcard, attr.value);
        }
    }
    try testing.expect(found_exposed);
}

test "generated Node has [Exposed=Window]" {
    const metadata = Node.__webidl__;

    // Should have Exposed=Window
    var found_exposed = false;
    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            found_exposed = true;
            // Value is an anonymous struct at comptime, check for identifier field
            if (@hasField(@TypeOf(attr.value), "identifier")) {
                try testing.expectEqualStrings("Window", attr.value.identifier);
            } else {
                try testing.expect(false); // Should have identifier field
            }
        }
    }
    try testing.expect(found_exposed);
}

test "generated ReadableStream has [Exposed=*, Transferable]" {
    const metadata = ReadableStream.__webidl__;

    // Should have both Exposed and Transferable
    var found_exposed = false;
    var found_transferable = false;

    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            found_exposed = true;
            try testing.expectEqual(ExtendedAttributeValue.wildcard, attr.value);
        } else if (std.mem.eql(u8, attr.name, "Transferable")) {
            found_transferable = true;
            try testing.expectEqual(ExtendedAttributeValue.none, attr.value);
        }
    }

    try testing.expect(found_exposed);
    try testing.expect(found_transferable);
}

test "parser correctly handles .exposed = &.{.global} syntax" {
    // Verify that .global in source maps to .wildcard in metadata
    const metadata = Event.__webidl__;

    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            // .global should become .wildcard
            try testing.expectEqual(ExtendedAttributeValue.wildcard, attr.value);
            return;
        }
    }

    try testing.expect(false); // Should have found Exposed
}

test "parser correctly handles .exposed = &.{.Window} syntax" {
    // Verify that .Window in source maps to .identifier in metadata
    const metadata = Node.__webidl__;

    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            // .Window should become .{ .identifier = "Window" }
            if (@hasField(@TypeOf(attr.value), "identifier")) {
                try testing.expectEqualStrings("Window", attr.value.identifier);
                return;
            } else {
                try testing.expect(false);
            }
        }
    }

    try testing.expect(false); // Should have found Exposed
}
