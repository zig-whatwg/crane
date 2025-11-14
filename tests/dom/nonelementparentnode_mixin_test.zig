//! Tests migrated from webidl/src/dom/NonElementParentNode.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");

const source = @import("../../webidl/src/dom/NonElementParentNode.zig");

test "NonElementParentNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(NonElementParentNode);
    try std.testing.expect(T != void);
}