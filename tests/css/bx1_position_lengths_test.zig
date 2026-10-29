//! Q75: Values4 §§6.1.1,8.3 / Values5 §4.2 admit bare extended lengths.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const metrics = @import("bx1_metric_helpers.zig");
const testing = std.testing;

test "perspective origin retains bare cap and rcap specified lengths" {
    try specified(testing.allocator, "perspective-origin");
}

test "object position retains bare cap and rcap specified lengths" {
    try specified(testing.allocator, "object-position");
}

fn specified(allocator: h.Allocator, name: []const u8) !void {
    inline for (.{ "1cap 2px", "1rcap 2px", "-1cap 2rcap", "right 1cap bottom 2rcap" }) |input|
        try h.check(allocator, name, input, input, false);
    try h.check(allocator, name, "1cap", "1cap center", false);
}

test "position math and background bare length controls remain accepted" {
    inline for (.{ "perspective-origin", "object-position" }) |name| {
        try h.check(testing.allocator, name, "calc(1cap + 2px) 3px", "calc(1cap + 2px) 3px", false);
        try h.check(testing.allocator, name, "0 0", "0px 0px", false);
    }
    try h.check(testing.allocator, "background-position", "1cap 2px", "1cap 2px", false);
}

test "generic positions still reject keywords scalars and nonlength dimensions" {
    inline for (.{ "perspective-origin", "object-position" }) |name|
        inline for (.{ "auto 2px", "1 2px", "1deg 2px", "1s 2px", "1fr 2px", "calc(1deg) 2px", "calc(1s) 2px", "calc(1) 2px" }) |input|
            try h.check(testing.allocator, name, input, "", false);
}

test "generic positions reject anchor functions before scalar filtering" {
    inline for (.{ "perspective-origin", "object-position" }) |name|
        inline for (.{ "anchor-size(width)", "anchor(top)", "anchor-size(width) 2px", "anchor(top) 2px" }) |input|
            try h.check(testing.allocator, name, input, "", false);
}

test "position cap lengths preserve the property owned availability policy" {
    inline for (.{ "1cap 2px", "1rcap 2px" }) |input| {
        try metrics.check(testing.allocator, "perspective-origin", "9px 9px", input, null);
        try metrics.check(testing.allocator, "object-position", "9px 9px", input, "9px 9px");
    }
}

test "bare extended position lengths release every failed allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, allocations, .{});
}

fn allocations(allocator: h.Allocator) !void {
    try specified(allocator, "perspective-origin");
    try specified(allocator, "object-position");
    try metrics.check(allocator, "perspective-origin", "9px 9px", "1cap 2rcap", null);
    try metrics.check(allocator, "object-position", "9px 9px", "1cap 2rcap", "9px 9px");
}
