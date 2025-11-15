//! Tests for WebIDL metadata generation
//!
//! Verifies that the codegen correctly generates __webidl__ metadata structures.

const std = @import("std");
const testing = std.testing;

// Import codegen types
const codegen = @import("webidl").codegen;
const ExtendedAttributeValue = codegen.ExtendedAttributeValue;

// Import generated classes
const EventTarget = @import("dom").EventTarget;
const Event = @import("dom").Event;
const Node = @import("dom").Node;
const Element = @import("dom").Element;
const ReadableStream = @import("streams").ReadableStream;
const WritableStream = @import("streams").WritableStream;
const TransformStream = @import("streams").TransformStream;
test "EventTarget has __webidl__ metadata" {
    try testing.expect(@hasDecl(EventTarget, "__webidl__"));
    const metadata = EventTarget.__webidl__;
    // Metadata structure exists with kind field
    _ = metadata.kind;
}

test "EventTarget has no parent (base interface)" {
    const metadata = EventTarget.__webidl__;
    try testing.expectEqual(@as(?[]const u8, null), metadata.parent);
}

test "Node inherits from EventTarget" {
    const metadata = Node.__webidl__;
    // Metadata structure exists with kind field
    _ = metadata.kind;
    // Parent is a comptime-known string literal (not optional)
    try testing.expectEqualStrings("EventTarget", metadata.parent);
}

test "Element inherits from Node" {
    const metadata = Element.__webidl__;
    // Metadata structure exists with kind field
    _ = metadata.kind;
    // Parent is a comptime-known string literal (not optional)
    try testing.expectEqualStrings("Node", metadata.parent);
}

test "ReadableStream has extended_attrs array" {
    const metadata = ReadableStream.__webidl__;
    try testing.expect(metadata.extended_attrs.len > 0);
}

test "ReadableStream extended_attrs includes Exposed" {
    const metadata = ReadableStream.__webidl__;

    var found = false;
    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

test "ReadableStream extended_attrs includes Transferable" {
    const metadata = ReadableStream.__webidl__;

    var found = false;
    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Transferable")) {
            found = true;
            try testing.expectEqual(ExtendedAttributeValue.none, attr.value);
            break;
        }
    }
    try testing.expect(found);
}

test "WritableStream has Transferable attribute" {
    const metadata = WritableStream.__webidl__;

    var found = false;
    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Transferable")) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

test "TransformStream has Transferable attribute" {
    const metadata = TransformStream.__webidl__;

    var found = false;
    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Transferable")) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

test "Event has [Exposed=*] (wildcard)" {
    const metadata = Event.__webidl__;

    var found = false;
    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            found = true;
            try testing.expectEqual(ExtendedAttributeValue.wildcard, attr.value);
            break;
        }
    }
    try testing.expect(found);
}

test "Node has [Exposed=Window] (identifier)" {
    const metadata = Node.__webidl__;

    var found = false;
    inline for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            found = true;
            // Value is an anonymous struct at comptime
            if (@hasField(@TypeOf(attr.value), "identifier")) {
                try testing.expectEqualStrings("Window", attr.value.identifier);
            } else {
                try testing.expect(false);
            }
            break;
        }
    }
    try testing.expect(found);
}

test "metadata structure has correct fields" {
    const metadata = EventTarget.__webidl__;

    // Verify all required fields exist
    _ = metadata.kind;
    _ = metadata.parent;
    _ = metadata.extended_attrs;
}

test "generated metadata is comptime-known" {
    // All metadata should be comptime-known (no runtime allocation)
    comptime {
        const metadata = EventTarget.__webidl__;
        _ = metadata;
    }
}
