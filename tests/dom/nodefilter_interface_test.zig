//! Tests migrated from webidl/src/dom/dom.NodeFilter.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const NodeFilter = dom.NodeFilter;

test "dom.NodeFilter constants" {
    const testing = std.testing;

    // Filter return values - use getter functions
    try testing.expectEqual(@as(u16, 1), NodeFilter.get_FILTER_ACCEPT());
    try testing.expectEqual(@as(u16, 2), NodeFilter.get_FILTER_REJECT());
    try testing.expectEqual(@as(u16, 3), NodeFilter.get_FILTER_SKIP());

    // whatToShow bitmask constants - use getter functions
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), NodeFilter.get_SHOW_ALL());
    try testing.expectEqual(@as(u32, 0x1), NodeFilter.get_SHOW_ELEMENT());
    try testing.expectEqual(@as(u32, 0x4), NodeFilter.get_SHOW_TEXT());
    try testing.expectEqual(@as(u32, 0x80), NodeFilter.get_SHOW_COMMENT());
}
