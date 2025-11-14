//! Tests migrated from webidl/src/dom/dom_types.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
const dom_types = @import("dom_types");

test "NodeOrDOMString compiles" {
    const T = @TypeOf(dom_types.NodeOrDOMString);
    try std.testing.expect(T != void);
}
