//! Tests for WebIDL metadata generation
//!
//! Verifies that the codegen correctly generates __webidl__ metadata structures.

const std = @import("std");
const testing = std.testing;
const ir = @import("webidl").codegen.ir;

// Import generated classes
const EventTarget = @import("dom").EventTarget;
const Event = @import("dom").Event;
const Node = @import("dom").Node;
const Element = @import("dom").Element;
const ReadableStream = @import("streams").ReadableStream;
const WritableStream = @import("streams").WritableStream;
const TransformStream = @import("streams").TransformStream;
const console = @import("console").console;

test "EventTarget has __webidl__ metadata" {
    try testing.expect(@hasDecl(EventTarget, "__webidl__"));
    const metadata = EventTarget.__webidl__;
    try testing.expectEqual(ir.ClassKind.interface, metadata.kind);
}

test "EventTarget has no parent (base interface)" {
    const metadata = EventTarget.__webidl__;
    try testing.expectEqual(@as(?[]const u8, null), metadata.parent);
}

test "Node inherits from EventTarget" {
    const metadata = Node.__webidl__;
    try testing.expectEqual(ir.ClassKind.interface, metadata.kind);
    try testing.expect(metadata.parent != null);
    try testing.expectEqualStrings("EventTarget", metadata.parent.?);
}

test "Element inherits from Node" {
    const metadata = Element.__webidl__;
    try testing.expectEqual(ir.ClassKind.interface, metadata.kind);
    try testing.expect(metadata.parent != null);
    try testing.expectEqualStrings("Node", metadata.parent.?);
}

test "console is a namespace" {
    try testing.expect(@hasDecl(console, "__webidl__"));
    const metadata = console.__webidl__;
    try testing.expectEqual(ir.ClassKind.namespace, metadata.kind);
}

test "console namespace has no parent" {
    const metadata = console.__webidl__;
    try testing.expectEqual(@as(?[]const u8, null), metadata.parent);
}

test "ReadableStream has extended_attrs array" {
    const metadata = ReadableStream.__webidl__;
    try testing.expect(metadata.extended_attrs.len > 0);
}

test "ReadableStream extended_attrs includes Exposed" {
    const metadata = ReadableStream.__webidl__;

    var found = false;
    for (metadata.extended_attrs) |attr| {
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
    for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Transferable")) {
            found = true;
            try testing.expectEqual(ir.ExtendedAttributeValue.none, attr.value);
            break;
        }
    }
    try testing.expect(found);
}

test "WritableStream has Transferable attribute" {
    const metadata = WritableStream.__webidl__;

    var found = false;
    for (metadata.extended_attrs) |attr| {
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
    for (metadata.extended_attrs) |attr| {
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
    for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            found = true;
            try testing.expectEqual(ir.ExtendedAttributeValue.wildcard, attr.value);
            break;
        }
    }
    try testing.expect(found);
}

test "Node has [Exposed=Window] (identifier)" {
    const metadata = Node.__webidl__;

    var found = false;
    for (metadata.extended_attrs) |attr| {
        if (std.mem.eql(u8, attr.name, "Exposed")) {
            found = true;
            switch (attr.value) {
                .identifier => |id| {
                    try testing.expectEqualStrings("Window", id);
                },
                else => try testing.expect(false),
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
