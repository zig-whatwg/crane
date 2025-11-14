//! Tests migrated from webidl/src/dom/ChildNode.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

test "ChildNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(ChildNode);
    try std.testing.expect(T != void);
}