//! Tests migrated from webidl/src/dom/ParentNode.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const ParentNode = @import("parent_node").ParentNode;

test "ParentNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(ParentNode);
    try std.testing.expect(T != void);
}
