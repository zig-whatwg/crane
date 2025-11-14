//! Tests migrated from webidl/src/dom/NonElementParentNode.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

test "NonElementParentNode mixin compiles" {
    // NonElementParentNode is a mixin included in Document and DocumentFragment
    // Test that Document (which includes the mixin) compiles
    const T = @TypeOf(dom.Document);
    try std.testing.expect(T != void);
}
