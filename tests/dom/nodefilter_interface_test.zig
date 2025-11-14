//! Tests migrated from webidl/src/dom/NodeFilter.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");

const source = @import("../../webidl/src/dom/NodeFilter.zig");

test "NodeFilter constants" {
    const testing = std.testing;

    // Filter return values
    try testing.expectEqual(@as(u16, 1), NodeFilter.FILTER_ACCEPT);
    try testing.expectEqual(@as(u16, 2), NodeFilter.FILTER_REJECT);
    try testing.expectEqual(@as(u16, 3), NodeFilter.FILTER_SKIP);

    // whatToShow bitmask constants
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), NodeFilter.SHOW_ALL);
    try testing.expectEqual(@as(u32, 0x1), NodeFilter.SHOW_ELEMENT);
    try testing.expectEqual(@as(u32, 0x4), NodeFilter.SHOW_TEXT);
    try testing.expectEqual(@as(u32, 0x80), NodeFilter.SHOW_COMMENT);
}