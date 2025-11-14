//! Tests migrated from webidl/src/dom/dom_types.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");

const source = @import("../../webidl/src/dom/dom_types.zig");

test "NodeOrDOMString compiles" {
    const T = @TypeOf(NodeOrDOMString);
    try std.testing.expect(T != void);
}