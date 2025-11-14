//! Tests migrated from webidl/src/dom/NonElementParentNode.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const NonElementParentNode = @import("non_element_parent_node").NonElementParentNode;

test "NonElementParentNode mixin compiles" {
    // Just verify the mixin structure compiles
    const T = @TypeOf(NonElementParentNode);
    try std.testing.expect(T != void);
}
