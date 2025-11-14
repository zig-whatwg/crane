//! Tests migrated from webidl/src/dom/ChildNode.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");

const source = @import("../../webidl/src/dom/ChildNode.zig");

test "ChildNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(ChildNode);
    try std.testing.expect(T != void);
}