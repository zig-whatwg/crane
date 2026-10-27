//! Q32: scroll padding keeps unavailable geometric lengths typed.
const std = @import("std");
const metrics = @import("bx1_metric_helpers.zig");
const testing = std.testing;

test "scroll padding preserves unknown cap lengths on physical and logical sides" {
    inline for (.{ "scroll-padding-top", "scroll-padding-right", "scroll-padding-bottom", "scroll-padding-left", "scroll-padding-block-start", "scroll-padding-inline-end" }) |name| {
        try metrics.check(testing.allocator, name, "9px", "1cap", null);
        try metrics.check(testing.allocator, name, "9px", "calc(1cap + 2px)", null);
    }
}

test "scroll margin retains its existing geometric capability" {
    try metrics.check(testing.allocator, "scroll-margin-top", "9px", "1cap", null);
}

test "scroll padding cap values release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    try metrics.check(allocator, "scroll-padding-top", "9px", "calc(1cap + 2px)", null);
}
