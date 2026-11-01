//! Fonts 4 §6.11 and CSSOM §6.7.2: independent variant assignments survive system fonts.
const std = @import("std");
const h = @import("bx1_helpers.zig");

test "font variant readback preserves overridden system font constituents" {
    try sequence(std.testing.allocator);
}

test "font variant round trip releases every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, sequence, .{});
}

test "unoverridden system font variants keep Q200 empty readback" {
    try controls(std.testing.allocator);
}

test "system font variant controls release every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, controls, .{});
}

fn controls(allocator: h.Allocator) !void {
    inline for (.{
        "font-variant:normal;font:menu",
        "font:caption",
        "font:caption;font-weight:700",
        "font:caption;font-kerning:none",
    }) |declarations| {
        var block = try h.Block.parse(.{ .allocator = allocator }, declarations);
        defer block.deinit();
        try h.specified(&block, "font-variant", "", allocator);
        inline for (.{ "ligatures", "caps", "alternates", "numeric", "east-asian", "position", "emoji" }) |suffix|
            try h.specified(&block, "font-variant-" ++ suffix, "", allocator);
    }
}

fn sequence(allocator: h.Allocator) !void {
    var block = h.Block.init(allocator);
    defer block.deinit();
    inline for (.{ "12px serif", "menu" }) |font| {
        _ = try block.setProperty(.{ .allocator = allocator }, "font", font, "");
        _ = try block.setProperty(.{ .allocator = allocator }, "font-variant-numeric", "tabular-nums", "");
        try h.specified(&block, "font-variant", "tabular-nums", allocator);
        _ = try block.setProperty(.{ .allocator = allocator }, "font-variant", "tabular-nums", "");
        try h.specified(&block, "font-variant", "tabular-nums", allocator);
        _ = try block.setProperty(.{ .allocator = allocator }, "font-variant-caps", "small-caps", "");
        try h.specified(&block, "font-variant", "small-caps tabular-nums", allocator);
        _ = try block.setProperty(.{ .allocator = allocator }, "font-variant", "small-caps tabular-nums", "");
        try h.specified(&block, "font-variant", "small-caps tabular-nums", allocator);
    }
}
