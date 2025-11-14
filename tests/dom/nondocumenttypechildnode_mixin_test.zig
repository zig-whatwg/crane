//! Tests migrated from webidl/src/dom/NonDocumentTypeChildNode.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

test "NonDocumentTypeChildNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(NonDocumentTypeChildNode);
    try std.testing.expect(T != void);
}