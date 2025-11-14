//! Tests migrated from webidl/src/dom/ParentNode.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");

const source = @import("../../webidl/src/dom/ParentNode.zig");

test "ParentNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(ParentNode);
    try std.testing.expect(T != void);
}