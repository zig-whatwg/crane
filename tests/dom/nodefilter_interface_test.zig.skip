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

    // Filter return values
    try testing.expectEqual(@as(u16, 1), dom.NodeFilter.FILTER_ACCEPT);
    try testing.expectEqual(@as(u16, 2), dom.NodeFilter.FILTER_REJECT);
    try testing.expectEqual(@as(u16, 3), dom.NodeFilter.FILTER_SKIP);

    // whatToShow bitmask constants
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), dom.NodeFilter.SHOW_ALL);
    try testing.expectEqual(@as(u32, 0x1), dom.NodeFilter.SHOW_ELEMENT);
    try testing.expectEqual(@as(u32, 0x4), dom.NodeFilter.SHOW_TEXT);
    try testing.expectEqual(@as(u32, 0x80), dom.NodeFilter.SHOW_COMMENT);
}