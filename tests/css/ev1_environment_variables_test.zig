//! CSS Env 1 section 3 step 1: names, dimensions and host value token text.
const std = @import("std");
const css = @import("css");
const env = css.environment_variables;
const testing = std.testing;

const scalar_lengths = .{
    .{ "safe-area-inset-top", .safe_area_inset_top },
    .{ "safe-area-inset-right", .safe_area_inset_right },
    .{ "safe-area-inset-bottom", .safe_area_inset_bottom },
    .{ "safe-area-inset-left", .safe_area_inset_left },
    .{ "safe-area-max-inset-top", .safe_area_max_inset_top },
    .{ "safe-area-max-inset-right", .safe_area_max_inset_right },
    .{ "safe-area-max-inset-bottom", .safe_area_max_inset_bottom },
    .{ "safe-area-max-inset-left", .safe_area_max_inset_left },
    .{ "keyboard-inset-top", .keyboard_inset_top },
    .{ "keyboard-inset-right", .keyboard_inset_right },
    .{ "keyboard-inset-bottom", .keyboard_inset_bottom },
    .{ "keyboard-inset-left", .keyboard_inset_left },
    .{ "keyboard-inset-width", .keyboard_inset_width },
    .{ "keyboard-inset-height", .keyboard_inset_height },
    .{ "titlebar-area-x", .titlebar_area_x },
    .{ "titlebar-area-y", .titlebar_area_y },
    .{ "titlebar-area-width", .titlebar_area_width },
    .{ "titlebar-area-height", .titlebar_area_height },
};

const indexed_lengths = .{
    .{ "viewport-segment-width", .viewport_segment_width },
    .{ "viewport-segment-height", .viewport_segment_height },
    .{ "viewport-segment-top", .viewport_segment_top },
    .{ "viewport-segment-right", .viewport_segment_right },
    .{ "viewport-segment-bottom", .viewport_segment_bottom },
    .{ "viewport-segment-left", .viewport_segment_left },
};

test "environment variables: every scalar length requires exactly zero indices" {
    inline for (scalar_lengths) |entry| {
        const query = env.query(entry[0], &.{}).?;
        try testing.expectEqual(@as(env.Variable, entry[1]), query.variable);
        try testing.expectEqual(@as(u32, 0), query.x);
        try testing.expectEqual(@as(u32, 0), query.y);
        try testing.expect(env.query(entry[0], &.{0}) == null);
        try testing.expect(env.query(entry[0], &.{ 0, 0 }) == null);
        try expectText(entry[1], 0, "0px");
        try expectText(entry[1], 12.5, "12.5px");
    }
}

test "environment variables: preferred text scale is a scalar number" {
    try testing.expectEqual(env.Variable.preferred_text_scale, env.query("preferred-text-scale", &.{}).?.variable);
    try testing.expect(env.query("preferred-text-scale", &.{0}) == null);
    try testing.expect(env.query("preferred-text-scale", &.{ 0, 0 }) == null);
    try expectText(.preferred_text_scale, 1, "1");
    try expectText(.preferred_text_scale, 1.25, "1.25");
}

test "environment variables: segment indices preserve order and full u32 range" {
    inline for (indexed_lengths) |entry| {
        const query = env.query(entry[0], &.{ 7, 2 }).?;
        try testing.expectEqual(@as(env.Variable, entry[1]), query.variable);
        try testing.expectEqual(@as(u32, 7), query.x);
        try testing.expectEqual(@as(u32, 2), query.y);
        const large = env.query(entry[0], &.{ std.math.maxInt(u32), 0 }).?;
        try testing.expectEqual(std.math.maxInt(u32), large.x);
        try testing.expectEqual(@as(u32, 0), large.y);
        try testing.expect(env.query(entry[0], &.{}) == null);
        try testing.expect(env.query(entry[0], &.{0}) == null);
        try testing.expect(env.query(entry[0], &.{ 0, 0, 0 }) == null);
        try expectText(entry[1], 320.5, "320.5px");
    }
}

test "environment variables: only exact standardized names are recognized" {
    for ([_][]const u8{
        "",                           "unknown",              "--author-name",                 "safe-area-inset",         "SAFE-AREA-INSET-TOP",
        " safe-area-inset-top",       "safe-area-inset-top ", "safe-area-inset-top\x00",       "safe\\2d area-inset-top", "env(safe-area-inset-top)",
        "viewport-segment-width 0 0", "fullscreen-inset-top", "fullscreen-auto-hide-duration", "fold-left",
    }) |name| {
        try testing.expect(env.query(name, &.{}) == null);
        try testing.expect(env.query(name, &.{ 0, 0 }) == null);
    }
}

test "environment variables: serialize zero, finite fractions and negative finite host values" {
    try expectText(.safe_area_inset_top, -0.0, "0px");
    try expectText(.preferred_text_scale, -0.0, "0");
    try expectText(.titlebar_area_x, -2.5, "-2.5px");
    try expectText(.preferred_text_scale, 0.125, "0.125");
    try expectText(.safe_area_inset_top, 0.123456789, "0.123456789px");
    try expectText(.safe_area_inset_top, 0.000000001, "0.000000001px");
}

test "environment variables: non-finite host values never create CSS tokens" {
    for ([_]f64{ std.math.nan(f64), std.math.inf(f64), -std.math.inf(f64) }) |number| {
        try testing.expect(try env.serialize(testing.allocator, .safe_area_inset_top, number) == null);
        try testing.expect(try env.serialize(testing.allocator, .preferred_text_scale, number) == null);
    }
}

test "environment variables: token allocation failure is propagated without leaking" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn expectText(variable: env.Variable, number: f64, expected: []const u8) !void {
    const text = (try env.serialize(testing.allocator, variable, number)).?;
    defer testing.allocator.free(text);
    try testing.expectEqualStrings(expected, text);
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    const text = (try env.serialize(allocator, .safe_area_inset_top, 12.5)).?;
    defer allocator.free(text);
    try testing.expectEqualStrings("12.5px", text);
}
